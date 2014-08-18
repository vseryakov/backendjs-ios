//
//  AppDelegate.m
//
//  Created by Vlad Seryakov on 7/4/14.
//

@implementation AppDelegate
    
- (void)configure
{
    [[BKjs get] configure];
    [[BKui get] configure];

    BKui.style[@"menubar"] = @{ @"backgroundColor": [UIColor lightGrayColor],
                                @"shadow": @{ @"width": @(0), @"height": @(0.5), @"opacity": @(0.5) } };
    
    BKui.style[@"toolbar"] = @{ @"backgroundColor": [UIColor lightGrayColor],
                                @"shadow": @{ @"width": @(0), @"height": @(0.5), @"opacity": @(0.5) } };

    BKui.style[@"toolbar-title"] = @{ @"textColor": [UIColor yellowColor] };

    BKui.controllers[@"Inbox"] = [[InboxViewController alloc] init];
    BKui.controllers[@"Login"] = [[LoginViewController alloc] init];
    BKui.controllers[@"Settings"] = [[SettingsViewController alloc] init];
    
    BKSocialAccount *sa = [[BKFacebook alloc] init:@"Facebook"];
    sa.clientId = @"FBAppID";
}

- (NSArray*)menubar
{
    return @[
       @{ @"title": @"Settings",
          @"icon": @"settings",
          @"icon-tint": @(1),
          @"icon-highlighted-tint": @(1),
          @"font": [UIFont systemFontOfSize:8],
          @"vertical": @(1),
          @"view": @"Settings@drawerLeftAnchor",
          @"badge": @{ @"count": @(self.messageCount),
                       @"x": @(65),
                       @"backgroundColor": [UIColor redColor],
                       @"borderColor": [UIColor whiteColor],
                       @"font": [UIFont systemFontOfSize:8] } },
       @{ @"id": @"title",
          @"title": @"Example",
          @"color": [UIColor yellowColor],
          @"font": [UIFont systemFontOfSize:15] },
       @{ @"title": @"Login",
          @"font": [UIFont systemFontOfSize:10],
          @"view": @"Login" } ];
}

#pragma mark AppDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self configure];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:BKui.controllers[@"Login"]];
    [self.window makeKeyAndVisible];
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];

    return YES;
}

@end
