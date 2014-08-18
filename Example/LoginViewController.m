//
//  Created by Vlad Seryakov on 7/15/14.
//  Copyright (c) 2014 Backendjs, Inc. All rights reserved.
//

#import "AppDelegate.h"

@implementation LoginViewController

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

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    NSMutableDictionary* item = [self getItem:indexPath];
    
    if ([item[@"type"] isEqual:@""]) {
        [BKui showViewController:self name:@"Inbox" params:nil];
        return;
    }
    
    if ([item[@"type"] isEqual:@"bkjs"]) {
        [BKjs getAccount:nil success:^(NSDictionary *obj) {
            [BKui showViewController:self name:@"Inbox" params:nil];
        } failure:^(NSInteger code, NSString *reason) {
            [BKui showAlert:@"Error" text:reason finish:nil];
        }];
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
