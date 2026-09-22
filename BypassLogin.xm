#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ── Strategy 1: Post the app's own auth-success notification ──────────────────
// Binary contains "FFXCAuthorizationRefreshed" – this is what the app
// posts internally when login succeeds. We fire it ourselves on launch.

static void postAuthRefreshed() {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"FFXCAuthorizationRefreshed"
                      object:nil
                    userInfo:nil];
    NSLog(@"[BypassLogin] Posted FFXCAuthorizationRefreshed");
}

// ── Strategy 2: Dismiss LoginView UIHostingController as soon as it appears ───
// SwiftUI Views are hosted inside UIHostingController<LoginView>.
// We detect via -description which contains the SwiftUI type name.

%hook UIHostingController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *desc = NSStringFromClass([self class]);
    // UIHostingController<LoginView> -> description contains "LoginView"
    if ([desc containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] UIHostingController<LoginView> appeared – bypassing");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            // Also try to dismiss the hosting controller
            UIViewController *presenting = [self presentingViewController];
            if (presenting) {
                [presenting dismissViewControllerAnimated:NO completion:nil];
            }
        });
    }
}

// Also intercept -viewWillAppear to post notification even earlier
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    NSString *desc = NSStringFromClass([self class]);
    if ([desc containsString:@"LoginView"]) {
        NSLog(@"[BypassLogin] UIHostingController<LoginView> will appear – pre-posting auth");
        postAuthRefreshed();
    }
}

%end

// ── Strategy 3: Hook RootView hosting controller to swap state ────────────────
// RootView likely holds a @State var showLogin: Bool.
// We hook its UIHostingController and force-dismiss any modal after load.

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Look for the RootView host – it presents LoginView as a modal
    NSString *cls = NSStringFromClass([self class]);
    if ([cls containsString:@"RootView"]) {
        NSLog(@"[BypassLogin] RootView appeared – posting auth + dismissing modals");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            postAuthRefreshed();
            // Dismiss any presented VC (LoginView sheet/fullscreen)
            if ([self presentedViewController]) {
                [self dismissViewControllerAnimated:NO completion:^{
                    postAuthRefreshed(); // fire again after dismiss
                }];
            }
        });
    }
}

%end

// ── Strategy 4: UIApplication launch hook – earliest possible fire ────────────

%hook UIApplication

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    // Delay slightly so notification observers are registered first
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        postAuthRefreshed();
    });
    return result;
}

%end
