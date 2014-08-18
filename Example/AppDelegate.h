//
//  AppDelegate.h
//
//  Created by Vlad Seryakov on 7/4/14.
//

#import "BKjs.h"
#import "BKui.h"
#import "BKViewController.h"
#import "BKItemViewController.h"
#import "BKMenubarView.h"
#import "BKFacebook.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic) int messageCount;

- (NSArray*)menubar;
@end

// View controllers
@interface LoginViewController : BKViewController
@end

@interface SettingsViewController : BKViewController
@end

@interface InboxViewController : BKViewController
@end

@interface MessageViewController : BKItemViewController
@end


