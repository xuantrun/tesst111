#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include <dlfcn.h>
#include "fishhook.h"

// ─────────────────────────────────────────────────────────────────────────────
// YABAOCHEAT / FFXC Full Bypass v6 (NSURLProtocol + dlsym hook)
// ─────────────────────────────────────────────────────────────────────────────

#define SECONDS_999_DAYS  (999LL * 24 * 60 * 60)

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

static IMP (*orig_method_setImplementation)(Method m, IMP imp);
static IMP fake_method_setImplementation(Method m, IMP imp) {
    return method_getImplementation(m); 
}
static IMP (*orig_class_replaceMethod)(Class cls, SEL name, IMP imp, const char *types);
static IMP fake_class_replaceMethod(Class cls, SEL name, IMP imp, const char *types) {
    return method_getImplementation(class_getInstanceMethod(cls, name));
}
static void (*orig_method_exchangeImplementations)(Method m1, Method m2);
static void fake_method_exchangeImplementations(Method m1, Method m2) {}

static IMP (*orig_method_getImplementation)(Method m);
static IMP fake_method_getImplementation(Method m) {
    IMP imp = orig_method_getImplementation(m);
    // Hide our swizzled IMPs
    // Since we don't store the swizzled IMPs globally easily here, we can just use dladdr!
    // Or we can just check if the IMP is inside our dylib!
    Dl_info info;
    if (dladdr((const void *)imp, &info) && info.dli_fname && strstr(info.dli_fname, "Bypass")) {
        // If it's our IMP, we should return the original IMP!
        // But we don't know which method it is.
        // A simple trick: if it's our IMP, we just return a dummy IMP from Foundation!
        return (IMP)dlerror; // Return any system function pointer so it looks clean
    }
    return imp;
}

static Dl_info (*orig_dladdr)(const void *, Dl_info *);
static int fake_dladdr(const void *addr, Dl_info *info) {
    int res = orig_dladdr(addr, info);
    if (res != 0 && info && info->dli_fname && strstr(info->dli_fname, "Bypass")) {
        info->dli_fname = "/usr/lib/libSystem.B.dylib";
    }
    return res;
}

// Prevent anti-tamper from dynamically resolving SecStaticCodeCheckValidity via dlsym!
static void *(*orig_dlsym)(void *handle, const char *symbol);
static void *fake_dlsym(void *handle, const char *symbol) {
    if (strcmp(symbol, "SecStaticCodeCheckValidity") == 0) return (void *)fake_SecStaticCodeCheckValidity;
    if (strcmp(symbol, "SecCodeCheckValidity") == 0) return (void *)fake_SecCodeCheckValidity;
    if (strcmp(symbol, "SecStaticCodeCheckValidityWithErrors") == 0) return (void *)fake_SecStaticCodeCheckValidityWithErrors;
    if (strcmp(symbol, "method_setImplementation") == 0) return (void *)fake_method_setImplementation;
    if (strcmp(symbol, "class_replaceMethod") == 0) return (void *)fake_class_replaceMethod;
    if (strcmp(symbol, "method_exchangeImplementations") == 0) return (void *)fake_method_exchangeImplementations;
    if (strcmp(symbol, "method_getImplementation") == 0) return (void *)fake_method_getImplementation;
    if (strcmp(symbol, "dladdr") == 0) return (void *)fake_dladdr;
    return orig_dlsym(handle, symbol);
}

// ── 2. Network Intercept via NSURLProtocol (Catches async/await!) ───────────
@interface FFXCURLProtocol : NSURLProtocol
@end

@implementation FFXCURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    if ([url containsString:@"ffxc"] || [url containsString:@"auth"] || [url containsString:@"verify"] || [url containsString:@"license"]) {
        return YES;
    }
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    NSLog(@"[BypassLogin] Intercepted network natively: %@", self.request.URL);
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
    
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
    NSData *data = [NSJSONSerialization dataWithJSONObject:fakeJson options:0 error:nil];
    
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}
- (void)stopLoading {}
@end

// Ensure our protocol is injected into ALL custom NSURLSessionConfigurations
static NSArray * (*orig_protocolClasses)(id, SEL);
static NSArray * swizzled_protocolClasses(id self, SEL _cmd) {
    NSArray *classes = orig_protocolClasses(self, _cmd);
    if (![classes containsObject:[FFXCURLProtocol class]]) {
        NSMutableArray *m = [classes mutableCopy];
        [m insertObject:[FFXCURLProtocol class] atIndex:0]; // Highest priority
        return [m copy];
    }
    return classes;
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

// ── Constructor ─────────────────────────────────────────────────────────────
__attribute__((constructor(101)))
static void BypassLoginInit(void) {
    NSLog(@"[BypassLogin] ===== FFXC Bypass v6 loaded =====");

    // Register our custom protocol for [NSURLSession sharedSession] and NSURLConnection
    [NSURLProtocol registerClass:[FFXCURLProtocol class]];

    struct rebinding rebindings[] = {
        {"SecStaticCodeCheckValidity",           (void *)fake_SecStaticCodeCheckValidity,           NULL},
        {"SecCodeCheckValidity",                 (void *)fake_SecCodeCheckValidity,                 NULL},
        {"SecStaticCodeCheckValidityWithErrors", (void *)fake_SecStaticCodeCheckValidityWithErrors, NULL},
        {"_dyld_get_image_name",                 (void *)fake_dyld_get_image_name,                  (void **)&orig_dyld_get_image_name},
        {"method_setImplementation",             (void *)fake_method_setImplementation,             (void **)&orig_method_setImplementation},
        {"class_replaceMethod",                  (void *)fake_class_replaceMethod,                  (void **)&orig_class_replaceMethod},
        {"method_exchangeImplementations",       (void *)fake_method_exchangeImplementations,       (void **)&orig_method_exchangeImplementations},
        {"method_getImplementation",             (void *)fake_method_getImplementation,             (void **)&orig_method_getImplementation},
        {"dladdr",                               (void *)fake_dladdr,                               (void **)&orig_dladdr},
        {"dlsym",                                (void *)fake_dlsym,                                (void **)&orig_dlsym},
    };
    rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));

    Class udClass = [NSUserDefaults class];
    Method mObj  = class_getInstanceMethod(udClass, @selector(objectForKey:));
    Method mBool = class_getInstanceMethod(udClass, @selector(boolForKey:));
    if (mObj)  { orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(mObj);   method_setImplementation(mObj,  (IMP)swizzled_objectForKey); }
    if (mBool) { orig_boolForKey   = (BOOL(*)(id,SEL,NSString*))method_getImplementation(mBool); method_setImplementation(mBool, (IMP)swizzled_boolForKey); }

    Class configClass = [NSURLSessionConfiguration class];
    Method mProto = class_getInstanceMethod(configClass, @selector(protocolClasses));
    if (mProto) {
        orig_protocolClasses = (id(*)(id,SEL))method_getImplementation(mProto);
        method_setImplementation(mProto, (IMP)swizzled_protocolClasses);
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (1) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                [ud setBool:NO forKey:@"ffxc.controls.v3.integrityFailed"];
                [ud setBool:NO forKey:@"ffxc.controls.v3.integrityMismatch"];
                [ud setInteger:SECONDS_999_DAYS forKey:@"ffxc.controls.v3.leaseSeconds"];
                [ud setObject:@"2099-12-31T23:59:59Z" forKey:@"ffxc.controls.v3.expiresAt"];
            });
            usleep(200000); // 0.2s
        }
    });
}
