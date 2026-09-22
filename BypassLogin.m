#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

// ─────────────────────────────────────────────────────────────────────────────
// YABAOCHEAT / FFXC Full Bypass
// 1. fishhook SecStaticCodeCheckValidity + SecCodeCheckValidity → always pass
// 2. NSUserDefaults expiry keys → 999 days
// 3. NSNotificationCenter: block FFXCIntegrityFailed / FFXCAuthorizationRevoked
// 4. UIViewController swizzle: dismiss LoginView, fire FFXCAuthorizationRefreshed
// ─────────────────────────────────────────────────────────────────────────────

#define SECONDS_999_DAYS  (999LL * 24 * 60 * 60)
#define FFXC_AUTH_OK      @"FFXCAuthorizationRefreshed"
#define FFXC_INTEGRITY_BAD @"FFXCIntegrityFailed"

// ── 1. Hook Security C functions via fishhook ─────────────────────────────────
static OSStatus (*orig_SecStaticCodeCheckValidity)(SecStaticCodeRef, SecCSFlags, SecRequirementRef);
static OSStatus (*orig_SecCodeCheckValidity)(SecCodeRef, SecCSFlags, SecRequirementRef);
static OSStatus (*orig_SecStaticCodeCheckValidityWithErrors)(SecStaticCodeRef, SecCSFlags, SecRequirementRef, CFErrorRef *);

static OSStatus fake_SecStaticCodeCheckValidity(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef req) {
    NSLog(@"[BypassLogin] SecStaticCodeCheckValidity hooked → errSecSuccess");
    return errSecSuccess;
}

static OSStatus fake_SecCodeCheckValidity(SecCodeRef code, SecCSFlags flags, SecRequirementRef req) {
    NSLog(@"[BypassLogin] SecCodeCheckValidity hooked → errSecSuccess");
    return errSecSuccess;
}

static OSStatus fake_SecStaticCodeCheckValidityWithErrors(SecStaticCodeRef code, SecCSFlags flags, SecRequirementRef req, CFErrorRef *errors) {
    NSLog(@"[BypassLogin] SecStaticCodeCheckValidityWithErrors hooked → errSecSuccess");
    if (errors) *errors = NULL;
    return errSecSuccess;
}

// ── 2. NSUserDefaults: fake expiry/integrity keys ─────────────────────────────
static id (*orig_objectForKey)(id, SEL, NSString *);
static id swizzled_objectForKey(id self, SEL _cmd, NSString *key) {
    if ([key containsString:@"expir"] || [key containsString:@"Expir"] ||
        [key containsString:@"lease"] || [key containsString:@"Lease"]) {
        NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
        NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
        NSLog(@"[BypassLogin] NSUD[%@] → fake 999d", key);
        return [fmt stringFromDate:future];
    }
    if ([key containsString:@"integrity"] || [key containsString:@"Integrity"] ||
        [key containsString:@"mismatch"] || [key containsString:@"Mismatch"]) {
        NSLog(@"[BypassLogin] NSUD[%@] → NO", key);
        return @NO;
    }
    return orig_objectForKey(self, _cmd, key);
}

static BOOL (*orig_boolForKey)(id, SEL, NSString *);
static BOOL swizzled_boolForKey(id self, SEL _cmd, NSString *key) {
    if ([key containsString:@"integrity"] || [key containsString:@"Integrity"] ||
        [key containsString:@"mismatch"] || [key containsString:@"Failed"]) {
        return NO;
    }
    return orig_boolForKey(self, _cmd, key);
}

// ── 3. NSNotificationCenter: block bad notifications ─────────────────────────
static void (*orig_postNotif)(id, SEL, NSNotificationName, id, NSDictionary *);
static void swizzled_postNotif(id self, SEL _cmd, NSNotificationName name, id obj, NSDictionary *info) {
    if ([name isEqualToString:FFXC_INTEGRITY_BAD] ||
        [name isEqualToString:@"FFXCAuthorizationRevoked"] ||
        [name containsString:@"integrityFailed"] ||
        [name containsString:@"integrityMismatch"]) {
        NSLog(@"[BypassLogin] BLOCKED: %@", name);
        // Instead of broadcasting failure, broadcast success
        orig_postNotif(self, _cmd, FFXC_AUTH_OK, nil, nil);
        return;
    }
    orig_postNotif(self, _cmd, name, obj, info);
}

// ── 4. UIViewController: dismiss LoginView, fire auth ────────────────────────
static void (*orig_viewDidAppear)(id, SEL, BOOL);
static void swizzled_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);
    NSString *cls = NSStringFromClass(object_getClass(self));
    if ([cls containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] LoginView → bypass");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
            UIViewController *vc = (UIViewController *)self;
            if (vc.presentingViewController) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
                }];
            }
        });
    }
    if ([cls containsString:@"RootView"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
            UIViewController *vc = (UIViewController *)self;
            if (vc.presentedViewController) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
                }];
            }
        });
    }
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void BypassLoginInit(void) {
    NSLog(@"[BypassLogin] ===== FFXC Bypass v3 loaded =====");

    // 1. Hook Security C functions via fishhook
    struct rebinding rebindings[] = {
        {"SecStaticCodeCheckValidity",           (void *)fake_SecStaticCodeCheckValidity,           (void **)&orig_SecStaticCodeCheckValidity},
        {"SecCodeCheckValidity",                 (void *)fake_SecCodeCheckValidity,                 (void **)&orig_SecCodeCheckValidity},
        {"SecStaticCodeCheckValidityWithErrors", (void *)fake_SecStaticCodeCheckValidityWithErrors, (void **)&orig_SecStaticCodeCheckValidityWithErrors},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
    NSLog(@"[BypassLogin] fishhook: Security C functions patched");

    // 2. Swizzle NSUserDefaults
    Class udClass = [NSUserDefaults class];
    Method mObj  = class_getInstanceMethod(udClass, @selector(objectForKey:));
    Method mBool = class_getInstanceMethod(udClass, @selector(boolForKey:));
    if (mObj)  { orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(mObj);   method_setImplementation(mObj,  (IMP)swizzled_objectForKey); }
    if (mBool) { orig_boolForKey   = (BOOL(*)(id,SEL,NSString*))method_getImplementation(mBool); method_setImplementation(mBool, (IMP)swizzled_boolForKey); }

    // 3. Swizzle NSNotificationCenter
    Class ncClass = [NSNotificationCenter class];
    Method mPost = class_getInstanceMethod(ncClass, @selector(postNotificationName:object:userInfo:));
    if (mPost) {
        orig_postNotif = (void(*)(id,SEL,NSNotificationName,id,NSDictionary*))method_getImplementation(mPost);
        method_setImplementation(mPost, (IMP)swizzled_postNotif);
    }

    // 4. Swizzle UIViewController
    Class vcClass = objc_getClass("UIViewController");
    if (vcClass) {
        Method mDid = class_getInstanceMethod(vcClass, @selector(viewDidAppear:));
        if (mDid) {
            orig_viewDidAppear = (void(*)(id,SEL,BOOL))method_getImplementation(mDid);
            method_setImplementation(mDid, (IMP)swizzled_viewDidAppear);
        }
    }

    // 5. Pre-patch NSUserDefaults
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
        NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
        NSString *futureStr = [fmt stringFromDate:future];
        for (NSString *k in @[
            @"ffxc.controls.v3.expiresAt", @"ffxc.controls.v3.expiryDate",
            @"ffxc.controls.v3.keyExpiresAt", @"ffxc.controls.v3.keyExpiryRaw",
            @"keyExpiresAt", @"keyExpiryRaw", @"expiresAt", @"expiryDate"
        ]) { [ud setObject:futureStr forKey:k]; }
        [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.leaseSeconds"];
        [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.lease_seconds"];
        [ud setBool:NO forKey:@"ffxc.controls.v3.integrityFailed"];
        [ud setBool:NO forKey:@"ffxc.controls.v3.integrityMismatch"];
        [ud synchronize];
        NSLog(@"[BypassLogin] NSUserDefaults: 999d patched");
    });

    // 6. Fire auth at multiple intervals
    for (NSNumber *delay in @[@0.5, @1.0, @2.0, @3.5, @5.0]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
        });
    }

    NSLog(@"[BypassLogin] ===== All hooks installed =====");
}
