#import <UIKit/UIKit.h>

@interface UIHostingController : UIViewController
@end

// Hook UIViewController for standard UIKit / Storyboard apps
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *className = NSStringFromClass([self class]);
    
    // Check for LoginView based on the string dump
    if ([className containsString:@"LoginView"]) {
        NSLog(@"[Bypass] Detected LoginView (%@). Bypassing...", className);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Attempt to dismiss it
            [self dismissViewControllerAnimated:YES completion:nil];
            
            // Attempt to transition to MainMenuView directly if possible
            Class mainMenuClass = NSClassFromString(@"MainMenuView");
            if (mainMenuClass && self.navigationController) {
                UIViewController *mainMenu = [[mainMenuClass alloc] init];
                [self.navigationController pushViewController:mainMenu animated:YES];
            } else if (mainMenuClass) {
                UIViewController *mainMenu = [[mainMenuClass alloc] init];
                mainMenu.modalPresentationStyle = UIModalPresentationFullScreen;
                [self presentViewController:mainMenu animated:YES completion:nil];
            }
        });
    }
}

%end

// Hook UIHostingController for SwiftUI apps
%hook UIHostingController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *desc = [self description];
    
    if ([desc containsString:@"LoginView"]) {
        NSLog(@"[Bypass] Detected SwiftUI LoginView. Bypassing...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
            
            Class mainMenuClass = NSClassFromString(@"MainMenuView");
            if (mainMenuClass) {
                UIViewController *mainMenu = [[mainMenuClass alloc] init];
                mainMenu.modalPresentationStyle = UIModalPresentationFullScreen;
                [self presentViewController:mainMenu animated:YES completion:nil];
            }
        });
    }
}

%end
