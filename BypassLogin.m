#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include "fishhook.h"

// ─────────────────────────────────────────────────────────────────────────────
// YABAOCHEAT / FFXC Full Bypass v5 (Anti-Neutralization + Network Intercept)
// ─────────────────────────────────────────────────────────────────────────────

#define SECONDS_999_DAYS  (999LL * 24 * 60 * 60)
#define FFXC_AUTH_OK      @"FFXCAuthorizationRefreshed"
#define FFXC_INTEGRITY_BAD @"FFXCIntegrityFailed"

// ── 1. Fishhook: Block Patch Neutralization & Security Checks ────────────────
typedef void * SecStaticCodeRef_t;
typedef void * SecCodeRef_t;
typedef uint32_t SecCSFlags_t;
typedef void * SecRequirementRef_t;

static OSStatus fake_SecStaticCodeCheckValidity(SecStaticCodeRef_t code, SecCSFlags_t flags, SecRequirementRef_t req) { return 0; }
static OSStatus fake_SecCodeCheckValidity(SecCodeRef_t code, SecCSFlags_t flags, SecRequirementRef_t req) { return 0; }
static OSStatus fake_SecStaticCodeCheckValidityWithErrors(SecStaticCodeRef_t code, SecCSFlags_t flags, SecRequirementRef_t req, CFErrorRef *errors) { if (errors) *errors = NULL; return 0; }

static const char * (*orig_dyld_get_image_name)(uint32_t image_index);
static const char * fake_dyld_get_image_name(uint32_t image_index) {
    const char *name = orig_dyld_get_image_name(image_index);
    if (name && (strstr(name, "Bypass") || strstr(name, "Cydia"))) return "/usr/lib/libSystem.B.dylib";
    return name;
}

// Block the app from un-swizzling our methods!
static IMP (*orig_method_setImplementation)(Method m, IMP imp);
static IMP fake_method_setImplementation(Method m, IMP imp) {
    return method_getImplementation(m); // Return current IMP, ignore the new one
}
static IMP (*orig_class_replaceMethod)(Class cls, SEL name, IMP imp, const char *types);
static IMP fake_class_replaceMethod(Class cls, SEL name, IMP imp, const char *types) {
    return method_getImplementation(class_getInstanceMethod(cls, name));
}
static void (*orig_method_exchangeImplementations)(Method m1, Method m2);
static void fake_method_exchangeImplementations(Method m1, Method m2) {
    // Block
}

// ── 2. Network Intercept: FFXC License Server ───────────────────────────────
static NSURLSessionDataTask * (*orig_dataTaskWithRequest_completion)(id, SEL, NSURLRequest *, id);
static NSURLSessionDataTask * swizzled_dataTaskWithRequest_completion(id self, SEL _cmd, NSURLRequest *req, void (^completion)(NSData *, NSURLResponse *, NSError *)) {
    NSString *url = req.URL.absoluteString;
    if ([url containsString:@"ffxc"] || [url containsString:@"auth"] || [url containsString:@"verify"] || [url containsString:@"license"]) {
        NSLog(@"[BypassLogin] Intercepted network: %@", url);
        if (completion) {
            void (^fakeCompletion)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *res, NSError *err) {
                if (data) {
                    NSDictionary *fakeJson = @{
                        @"integrityFailed": @NO,
                        @"integrityMismatch": @NO,
                        @"isValidating": @NO,
                        @"expired": @NO,
                        @"expiresAt": @"2099-12-31T23:59:59Z",
                        @"keyExpiresAt": @"2099-12-31T23:59:59Z",
                        @"leaseSeconds": @(SECONDS_999_DAYS),
                        @"lease_seconds": @(SECONDS_999_DAYS),
                        @"status": @"success",
                        @"message": @"OK",
                        @"code": @0
                    };
                    NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeJson options:0 error:nil];
                    completion(fakeData, res, err);
                } else {
                    completion(data, res, err);
                }
            };
            return orig_dataTaskWithRequest_completion(self, _cmd, req, fakeCompletion);
        }
    }
    return orig_dataTaskWithRequest_completion(self, _cmd, req, completion);
}

// ── 3. NSUserDefaults ───────────────────────────────────────────────────────
static id (*orig_objectForKey)(id, SEL, NSString *);
static id swizzled_objectForKey(id self, SEL _cmd, NSString *key) {
    if ([key containsString:@"expir"] || [key containsString:@"Expir"] || [key containsString:@"lease"] || [key containsString:@"Lease"]) {
        NSDate *future = [NSDate dateWithTimeIntervalSinceNow:SECONDS_999_DAYS];
        NSISO8601DateFormatter *fmt = [NSISO8601DateFormatter new];
        return [fmt stringFromDate:future];
    }
    if ([key containsString:@"integrity"] || [key containsString:@"Integrity"] || [key containsString:@"mismatch"]) {
        return @NO;
    }
    return orig_objectForKey(self, _cmd, key);
}

static BOOL (*orig_boolForKey)(id, SEL, NSString *);
static BOOL swizzled_boolForKey(id self, SEL _cmd, NSString *key) {
    if ([key containsString:@"integrity"] || [key containsString:@"Integrity"] || [key containsString:@"mismatch"] || [key containsString:@"Failed"]) {
        return NO;
    }
    return orig_boolForKey(self, _cmd, key);
}

// ── 4. NSNotificationCenter ─────────────────────────────────────────────────
static void (*orig_postNotif)(id, SEL, NSNotificationName, id, NSDictionary *);
static void swizzled_postNotif(id self, SEL _cmd, NSNotificationName name, id obj, NSDictionary *info) {
    if ([name isEqualToString:FFXC_INTEGRITY_BAD] || [name isEqualToString:@"FFXCAuthorizationRevoked"] || [name containsString:@"integrity"]) {
        orig_postNotif(self, _cmd, FFXC_AUTH_OK, nil, nil);
        return;
    }
    orig_postNotif(self, _cmd, name, obj, info);
}

// ── Constructor ─────────────────────────────────────────────────────────────
__attribute__((constructor(101))) // Run early!
static void BypassLoginInit(void) {
    NSLog(@"[BypassLogin] ===== FFXC Bypass v5 loaded =====");

    struct rebinding rebindings[] = {
        {"SecStaticCodeCheckValidity",           (void *)fake_SecStaticCodeCheckValidity,           NULL},
        {"SecCodeCheckValidity",                 (void *)fake_SecCodeCheckValidity,                 NULL},
        {"SecStaticCodeCheckValidityWithErrors", (void *)fake_SecStaticCodeCheckValidityWithErrors, NULL},
        {"_dyld_get_image_name",                 (void *)fake_dyld_get_image_name,                  (void **)&orig_dyld_get_image_name},
        {"method_setImplementation",             (void *)fake_method_setImplementation,             (void **)&orig_method_setImplementation},
        {"class_replaceMethod",                  (void *)fake_class_replaceMethod,                  (void **)&orig_class_replaceMethod},
        {"method_exchangeImplementations",       (void *)fake_method_exchangeImplementations,       (void **)&orig_method_exchangeImplementations},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));

    Class udClass = [NSUserDefaults class];
    Method mObj  = class_getInstanceMethod(udClass, @selector(objectForKey:));
    Method mBool = class_getInstanceMethod(udClass, @selector(boolForKey:));
    if (mObj)  { orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(mObj);   method_setImplementation(mObj,  (IMP)swizzled_objectForKey); }
    if (mBool) { orig_boolForKey   = (BOOL(*)(id,SEL,NSString*))method_getImplementation(mBool); method_setImplementation(mBool, (IMP)swizzled_boolForKey); }

    Class ncClass = [NSNotificationCenter class];
    Method mPost = class_getInstanceMethod(ncClass, @selector(postNotificationName:object:userInfo:));
    if (mPost) {
        orig_postNotif = (void(*)(id,SEL,NSNotificationName,id,NSDictionary*))method_getImplementation(mPost);
        method_setImplementation(mPost, (IMP)swizzled_postNotif);
    }

    Class sessClass = [NSURLSession class];
    Method mTask = class_getInstanceMethod(sessClass, @selector(dataTaskWithRequest:completionHandler:));
    if (mTask) {
        orig_dataTaskWithRequest_completion = (void*)method_getImplementation(mTask);
        method_setImplementation(mTask, (IMP)swizzled_dataTaskWithRequest_completion);
    }

    // Force background thread to continuously apply patches just in case
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (1) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setBool:NO forKey:@"ffxc.controls.v3.integrityFailed"];
                [ud setBool:NO forKey:@"ffxc.controls.v3.integrityMismatch"];
                [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.leaseSeconds"];
                [ud setObject:@"2099-12-31T23:59:59Z" forKey:@"ffxc.controls.v3.expiresAt"];
                [[NSNotificationCenter defaultCenter] postNotificationName:FFXC_AUTH_OK object:nil userInfo:nil];
            });
            usleep(200000); // 0.2s
        }
    });
}
