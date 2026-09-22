#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Security/Security.h>

// ─────────────────────────────────────────────────────────────────────────────
// YABAOCHEAT / FFXC Bypass Dylib
// Pure ObjC runtime – zero CydiaSubstrate dependency
// Targets:
//   1. FFXCIntegrityFailed    → suppress integrity check failure
//   2. FFXCAuthorizationRevoked → suppress auth revocation
//   3. LoginView              → dismiss + fire FFXCAuthorizationRefreshed
//   4. leaseSeconds           → fake 999 days (86,313,600 seconds)
//   5. NSUserDefaults ffxc.*  → patch expiry keys
//   6. Keychain expiresAt     → fake date
// ─────────────────────────────────────────────────────────────────────────────

#define SECONDS_999_DAYS  (999LL * 24 * 60 * 60)
#define FFXC_INTEGRITY_OK @"FFXCAuthorizationRefreshed"
#define FFXC_INTEGRITY_BAD @"FFXCIntegrityFailed"

// ── Patch NSUserDefaults to fake expiry keys ──────────────────────────────────
static id (*orig_objectForKey)(id, SEL, NSString *);
static id swizzled_objectForKey(id self, SEL _cmd, NSString *key) {
    if ([key hasPrefix:@"ffxc."] || [key containsString:@"ffxc"]) {
        // Fake expiry / lease as 999 days from now
        if ([key containsString:@"expir"] ||
            [key containsString:@"Expir"] ||
            [key containsString:@"lease"] ||
            [key containsString:@"Lease"]) {
            NSLog(@"[BypassLogin] NSUserDefaults[%@] → fake 999d", key);
            NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
            // Return ISO8601 string (app uses NSISO8601DateFormatter)
            NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
            return [fmt stringFromDate:future];
        }
        // Suppress integrity failed flags
        if ([key containsString:@"integrity"] ||
            [key containsString:@"Integrity"] ||
            [key containsString:@"mismatch"]) {
            NSLog(@"[BypassLogin] NSUserDefaults[%@] → NO", key);
            return @NO;
        }
    }
    return orig_objectForKey(self, _cmd, key);
}

static BOOL (*orig_boolForKey)(id, SEL, NSString *);
static BOOL swizzled_boolForKey(id self, SEL _cmd, NSString *key) {
    if ([key containsString:@"integrity"] ||
        [key containsString:@"Integrity"] ||
        [key containsString:@"integrityFailed"] ||
        [key containsString:@"integrityMismatch"]) {
        NSLog(@"[BypassLogin] boolForKey[%@] → NO", key);
        return NO;
    }
    return orig_boolForKey(self, _cmd, key);
}

// ── NSNotificationCenter: swallow FFXCIntegrityFailed, block revoke ──────────
static void (*orig_postNotifName)(id, SEL, NSNotificationName, id, NSDictionary *);
static void swizzled_postNotifName(id self, SEL _cmd,
                                   NSNotificationName name,
                                   id obj,
                                   NSDictionary *info) {
    if ([name isEqualToString:FFXC_INTEGRITY_BAD] ||
        [name isEqualToString:@"FFXCAuthorizationRevoked"] ||
        [name isEqualToString:@"integrityFailed"] ||
        [name isEqualToString:@"integrityMismatch"]) {
        NSLog(@"[BypassLogin] BLOCKED notification: %@", name);
        return; // drop it
    }
    orig_postNotifName(self, _cmd, name, obj, info);
}

// ── UIViewController swizzle: dismiss LoginView, post auth ───────────────────
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void swizzled_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);
    NSString *cls = NSStringFromClass(object_getClass(self));

    if ([cls containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] LoginView appeared → bypass");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            // Post success notification
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFXC_INTEGRITY_OK object:nil userInfo:nil];
            // Dismiss
            UIViewController *vc = (UIViewController *)self;
            if (vc.presentingViewController) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:FFXC_INTEGRITY_OK object:nil userInfo:nil];
                }];
            }
        });
    }

    if ([cls containsString:@"RootView"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFXC_INTEGRITY_OK object:nil userInfo:nil];
            UIViewController *vc = (UIViewController *)self;
            if (vc.presentedViewController) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:FFXC_INTEGRITY_OK object:nil userInfo:nil];
                }];
            }
        });
    }
}

// ── Keychain: intercept SecItemCopyMatching for expiry data ──────────────────
// We inject fake lease_seconds into Keychain reads for ffxc keys
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
OSStatus hooked_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_SecItemCopyMatching(query, result);
    if (status == errSecSuccess && result && *result) {
        // Check if this is an ffxc keychain item by looking at query service
        CFStringRef service = CFDictionaryGetValue(query, kSecAttrService);
        if (service) {
            NSString *svc = (__bridge NSString *)service;
            if ([svc containsString:@"ffxc"] || [svc containsString:@"FFXC"]) {
                NSLog(@"[BypassLogin] Keychain ffxc read: %@", svc);
                // If data is returned, try to patch expiry
                if (CFGetTypeID(*result) == CFDataGetTypeID()) {
                    // Build fake JSON with 999-day lease
                    NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
                    NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
                    NSString *futureStr = [fmt stringFromDate:future];
                    NSDictionary *fakeData = @{
                        @"expiresAt":    futureStr,
                        @"expiryDate":   futureStr,
                        @"keyExpiresAt": futureStr,
                        @"keyExpiryRaw": futureStr,
                        @"leaseSeconds": @(SECONDS_999_DAYS),
                        @"lease_seconds":@(SECONDS_999_DAYS),
                        @"integrityFailed":   @NO,
                        @"integrityMismatch": @NO,
                    };
                    NSData *fakeJson = [NSJSONSerialization dataWithJSONObject:fakeData
                                                                       options:0
                                                                         error:nil];
                    if (fakeJson) {
                        CFRelease(*result);
                        *result = (__bridge_retained CFTypeRef)fakeJson;
                        NSLog(@"[BypassLogin] Keychain → patched 999d lease");
                    }
                }
            }
        }
    }
    return status;
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void BypassLoginInit(void) {
    NSLog(@"[BypassLogin] ===== FFXC Bypass dylib loaded =====");

    // 1. Patch NSUserDefaults
    Class udClass = [NSUserDefaults class];
    Method mObj = class_getInstanceMethod(udClass, @selector(objectForKey:));
    Method mBool = class_getInstanceMethod(udClass, @selector(boolForKey:));
    if (mObj) {
        orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(mObj);
        method_setImplementation(mObj, (IMP)swizzled_objectForKey);
    }
    if (mBool) {
        orig_boolForKey = (BOOL(*)(id,SEL,NSString*))method_getImplementation(mBool);
        method_setImplementation(mBool, (IMP)swizzled_boolForKey);
    }

    // 2. Block bad notifications
    Class ncClass = [NSNotificationCenter class];
    SEL postSEL = @selector(postNotificationName:object:userInfo:);
    Method mPost = class_getInstanceMethod(ncClass, postSEL);
    if (mPost) {
        orig_postNotifName = (void(*)(id,SEL,NSNotificationName,id,NSDictionary*))
                              method_getImplementation(mPost);
        method_setImplementation(mPost, (IMP)swizzled_postNotifName);
    }

    // 3. Swizzle UIViewController viewDidAppear
    Class vcClass = objc_getClass("UIViewController");
    if (vcClass) {
        Method mDid = class_getInstanceMethod(vcClass, @selector(viewDidAppear:));
        if (mDid) {
            orig_viewDidAppear = (void(*)(id,SEL,BOOL))method_getImplementation(mDid);
            method_setImplementation(mDid, (IMP)swizzled_viewDidAppear);
        }
    }

    // 4. Hook SecItemCopyMatching for Keychain
    // Use indirect function pointer via dlsym
    void *secLib = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW);
    if (secLib) {
        orig_SecItemCopyMatching = dlsym(secLib, "SecItemCopyMatching");
        // Note: cannot easily hook C functions without fishhook on non-jailbreak
        // So we rely on NSUserDefaults + notification blocking as primary vectors
    }

    // 5. Fire auth immediately + at intervals
    void (^fireAuth)(void) = ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:FFXC_INTEGRITY_OK object:nil userInfo:nil];
    };

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), fireAuth);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), fireAuth);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), fireAuth);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), fireAuth);

    // 6. Patch NSUserDefaults standard values immediately
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
        NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
        NSString *futureStr = [fmt stringFromDate:future];
        NSArray *expiryKeys = @[
            @"ffxc.controls.v3.expiresAt",
            @"ffxc.controls.v3.expiryDate",
            @"ffxc.controls.v3.keyExpiresAt",
            @"ffxc.controls.v3.keyExpiryRaw",
            @"ffxc.controls.v3.leaseSeconds",
            @"ffxc.controls.v3.lease_seconds",
            @"keyExpiresAt", @"keyExpiryRaw",
            @"expiresAt", @"expiryDate",
        ];
        for (NSString *k in expiryKeys) {
            [ud setObject:futureStr forKey:k];
        }
        // Fake leaseSeconds as number
        [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.leaseSeconds"];
        [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.lease_seconds"];
        // Clear integrity flags
        [ud setBool:NO forKey:@"ffxc.controls.v3.integrityFailed"];
        [ud setBool:NO forKey:@"ffxc.controls.v3.integrityMismatch"];
        [ud synchronize];
        NSLog(@"[BypassLogin] NSUserDefaults patched – 999d expiry set");
    });

    NSLog(@"[BypassLogin] ===== All hooks installed =====");
}
