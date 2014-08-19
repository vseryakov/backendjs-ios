//
//  Created by Vlad Seryakov on 7/15/14.
//  Copyright (c) 2014 Backendjs, Inc. All rights reserved.
//

#import "AppDelegate.h"

@implementation LoginViewController {
    BKPopupView *_login;
}

- (instancetype)init
{
    self = [super init];
    self.transition = [@{ @"type": @"slideDown", @"damping" :@(0.8) } mutableCopy];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.items = [@[ @{ @"type": @"", @"icon": @"logo", @"name": @"Proceed without login" },
                     @{ @"type": @"bkjs", @"icon": @"logo", @"name": @"Login to BKjs server" },
                     @{ @"type": @"Facebook", @"icon": @"facebook", @"name": @"Sign in with Facebook" },
                      ] mutableCopy];

    self.tableUnselected = YES;
    [self addTable];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.scrollEnabled = NO;
    self.tableView.frame = CGRectMake(20, self.view.height*0.5, self.view.width-40, self.view.height * 0.5);
    [self reloadTable];
    
    BKapp.messageCount = 1;
}

- (void)showLogin:(GenericBlock)finish
{
    _login = [[BKPopupView alloc] initWithFrame:CGRectMake(20, 20, self.view.width - 40, 260)];
    _login.backgroundColor = [BKui makeColor:@"#EEEEEE"];
    [_login.closeButton removeFromSuperview];
    
    UILabel *lbl = [BKui makeLabel:CGRectMake(0, 0, _login.width, 20) text:@"Login" color:[UIColor blueColor] font:nil];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.centerY = 22;
    [_login addSubview:lbl];

    lbl = [BKui makeLabel:CGRectMake(20, lbl.bottom + 20, _login.width - 40, 20) text:@"Username" color:nil font:[UIFont systemFontOfSize:15]];
    [_login addSubview:lbl];

    UITextField *nm = [[UITextField alloc] initWithFrame:CGRectMake(20, lbl.bottom + 5, _login.width - 40, 30)];
    nm.backgroundColor = _login.backgroundColor;
    nm.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, nm.height)];
    nm.leftViewMode = UITextFieldViewModeAlways;
    nm.tag = 100;
    [BKui setViewBorder:nm color:nil width:1 radius:2];
    [_login addSubview:nm];

    lbl = [BKui makeLabel:CGRectMake(20, nm.bottom + 10, _login.width - 40, 20) text:@"Password" color:nil font:[UIFont systemFontOfSize:15]];
    [_login addSubview:lbl];

    UITextField *pw = [[UITextField alloc] initWithFrame:CGRectMake(20, lbl.bottom + 5, _login.width - 40, 30)];
    pw.backgroundColor = _login.backgroundColor;
    pw.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, pw.height)];
    pw.leftViewMode = UITextFieldViewModeAlways;
    pw.secureTextEntry = YES;
    pw.tag = 101;
    [BKui setViewBorder:pw color:nil width:1 radius:2];
    [_login addSubview:pw];
    
    UIButton *btn = [BKui makeCustomButton:@"Login" image:nil];
    [btn sizeToFit];
    btn.centerY = pw.bottom + 30;
    btn.centerX = _login.width*0.25;
    [btn addTarget:self action:@selector(onLogin:) forControlEvents:UIControlEventTouchUpInside];
    [_login addSubview:btn];

    btn = [BKui makeCustomButton:@"Cancel" image:nil];
    [btn sizeToFit];
    btn.centerY = pw.bottom + 30;
    btn.centerX = _login.width*0.75;
    [btn addTarget:_login action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    [_login addSubview:btn];

    [_login show:nil];
}

- (void)onLogin:(id)sender
{
    UITextField *nm = (UITextField*)[_login viewWithTag:100];
    UITextField *pw = (UITextField*)[_login viewWithTag:100];
    [BKjs setCredentials:nm.text secret:pw.text];
    [_login hide:nil];
    
    [BKjs getAccount:nil success:^(NSDictionary *obj) {
        [BKui showViewController:self name:@"Inbox" params:nil];
    } failure:^(NSInteger code, NSString *reason) {
        [BKui showAlert:@"Error" text:reason finish:nil];
    }];
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    NSMutableDictionary* item = [self getItem:indexPath];
    
    if ([item[@"type"] isEqual:@""]) {
        [BKui showViewController:self name:@"Inbox" params:nil];
        return;
    }
    
    if ([item[@"type"] isEqual:@"bkjs"]) {
        [self showLogin:nil];
        return;
    }
    
    BKSocialAccount *account = BKSocialAccount.accounts[item[@"type"]];
    if (!account) return;
    [account getAccount:nil success:^(id user) {
        [BKui showViewController:self name:@"Inbox" params:nil];
    } failure:^(NSInteger code, NSString *reason) {
        [account logout];
        [BKui showAlert:[NSString stringWithFormat:@"Error: Cannot connect to %@", account.name]
                   text:[NSString stringWithFormat:@"Unable to login to your account on %@, try again later", account.name]
         finish:nil];
    }];
}

- (void)onTableCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath
{
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    NSMutableDictionary* item = [self getItem:indexPath];
    
    cell.imageView.image = [UIImage imageNamed:item[@"icon"]];
    cell.textLabel.text = item[@"name"];
}

@end
