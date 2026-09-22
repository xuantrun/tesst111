#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// UIHostingController is a subclass of UIViewController – declare it properly
// so Logos/clang sees the full interface, not just a forward decl.
@interface UIHostingController : UIViewController
@end

// ── helper: post the app's own auth-success notification ──────────────────────
static void postAuthRefreshed(void) {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"FFXCAuthorizationRefreshed"
                      object:nil
                    userInfo:nil];
    NSLog(@"[BypassLogin] Posted FFXCAuthorizationRefreshed");
}

// ── Hook UIHostingController (SwiftUI host) ────────────────────────────────────
%hook UIHostingController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    // UIHostingController<LoginView> – class name contains "LoginView"
    NSString *clsName = NSStringFromClass(self.class);
    if ([clsName containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] UIHostingController<LoginView> willAppear – firing auth");
        postAuthRefreshed();
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass(self.class);
    if ([clsName containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] UIHostingController<LoginView> didAppear – dismissing");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            UIViewController *presenter = self.presentingViewController;
            if (presenter) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }
        });
    }
}

%end

// ── Hook UIViewController for RootView dismiss ────────────────────────────────
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *clsName = NSStringFromClass(self.class);
    // RootView host presents LoginView as a modal – dismiss it
    if ([clsName containsString:@"RootView"]) {
        NSLog(@"[BypassLogin] RootView appeared – posting auth + dismissing modals");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            UIViewController *presented = self.presentedViewController;
            if (presented) {
                [self dismissViewControllerAnimated:NO completion:^{
                    postAuthRefreshed();
                }];
            }
        });
    }
}

%end

// ── Hook UIApplication – earliest possible fire ───────────────────────────────
%hook UIApplication

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        postAuthRefreshed();
    });
    return result;
}

%end
