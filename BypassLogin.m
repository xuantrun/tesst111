#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ─────────────────────────────────────────────────────────────────────────────
// STRATEGY: No Substrate/Logos hooks at all.
// Pure ObjC method swizzling via runtime – zero external dependencies.
// Works when injected into any IPA without CydiaSubstrate.
// ─────────────────────────────────────────────────────────────────────────────

static void postAuthRefreshed(void) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"FFXCAuthorizationRefreshed"
                      object:nil
                    userInfo:nil];
    NSLog(@"[BypassLogin] FFXCAuthorizationRefreshed fired");
}

// ── Swizzle UIViewController -viewDidAppear: ──────────────────────────────────
static void (*orig_viewDidAppear)(id, SEL, BOOL);

static void swizzled_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewDidAppear(self, _cmd, animated);

    NSString *cls = NSStringFromClass(object_getClass(self));

    if ([cls containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] LoginView appeared – bypassing");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            UIViewController *vc = (UIViewController *)self;
            UIViewController *presenter = vc.presentingViewController;
            if (presenter) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    postAuthRefreshed();
                }];
            }
        });
    }

    if ([cls containsString:@"RootView"]) {
        NSLog(@"[BypassLogin] RootView appeared");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            UIViewController *vc = (UIViewController *)self;
            if (vc.presentedViewController) {
                [vc dismissViewControllerAnimated:NO completion:^{
                    postAuthRefreshed();
                }];
            }
        });
    }
}

// ── Swizzle -viewWillAppear: for early fire ───────────────────────────────────
static void (*orig_viewWillAppear)(id, SEL, BOOL);

static void swizzled_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    orig_viewWillAppear(self, _cmd, animated);
    NSString *cls = NSStringFromClass(object_getClass(self));
    if ([cls containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] LoginView willAppear – pre-fire");
        postAuthRefreshed();
    }
}

// ── Constructor: runs when dylib is loaded ────────────────────────────────────
__attribute__((constructor))
static void BypassLoginInit(void) {
    NSLog(@"[BypassLogin] dylib loaded – installing swizzles");

    // Post immediately in case app is already past launch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        postAuthRefreshed();
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        postAuthRefreshed();
    });

    // Swizzle UIViewController
    Class cls = objc_getClass("UIViewController");
    if (!cls) return;

    SEL selDidAppear  = @selector(viewDidAppear:);
    SEL selWillAppear = @selector(viewWillAppear:);

    Method mDidAppear  = class_getInstanceMethod(cls, selDidAppear);
    Method mWillAppear = class_getInstanceMethod(cls, selWillAppear);

    if (mDidAppear) {
        orig_viewDidAppear = (void(*)(id,SEL,BOOL))method_getImplementation(mDidAppear);
        method_setImplementation(mDidAppear, (IMP)swizzled_viewDidAppear);
    }
    if (mWillAppear) {
        orig_viewWillAppear = (void(*)(id,SEL,BOOL))method_getImplementation(mWillAppear);
        method_setImplementation(mWillAppear, (IMP)swizzled_viewWillAppear);
    }

    NSLog(@"[BypassLogin] swizzles installed");
}
