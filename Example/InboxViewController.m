//
//  Created by Vlad Seryakov on 7/15/14.
//  Copyright (c) 2014 Backendjs, Inc. All rights reserved.
//

@interface InboxViewController () <UIWebViewDelegate,UITextViewDelegate>
@end

@implementation InboxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableRefreshable = YES;
    [self addTable];
    
    if ([self.navigationMode isEqual:@"push"]) {
        [self addToolbar:@"Inbox" params:nil];
    } else {
        [self addMenubar:BKapp.menubar params:nil];
    }
    [self addInfoView:@"No messages for you at this time"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self getItems];
}

- (void)getItems
{
    [self showActivity];
    [BKjs getMessages:@{ @"_archive": @(1) } success:^(NSArray *list, NSString *next) {
        [self hideActivity];
        BKapp.messageCount = 0;
        self.items = [list mutableCopy];
        [self reloadTable];
    } failure:^(NSInteger code, NSString *reason) {
        [self hideActivity];
        self.items = [@[ @{ @"msg": @"Test message if not active account present",
                            @"alias": @"Test",
                            @"image": [UIImage imageNamed:@"avatar"],
                            @"mtime": @(BKjs.now), }] mutableCopy];
        [self reloadTable];
    }];
}

#pragma mark UITableDelegate

- (UITableViewCellStyle)getTableCellStyle:(NSIndexPath*)indexPath
{
    return UITableViewCellStyleSubtitle;
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    
    NSDictionary* item = [self getItem:indexPath];
    if (!item) return;
    BKItemPopupView *details = [[BKItemPopupView alloc] initWithFrame:CGRectInset(self.tableView.frame, 10, 10) params:item];
    details.backgroundColor = [UIColor whiteColor];
    [details show:nil];
}

- (void)onTableCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath
{
    NSDictionary* item = [self getItem:indexPath];
    
    cell.textLabel.text = [item str:@"msg"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  %@", [item str:@"alias"], [BKjs strftime:[item num:@"mtime"]/1000 format:nil]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    
    NSDictionary *item = [self getItem:indexPath];
    if (!item) return;
    
    [self.items removeObjectAtIndex:indexPath.row];
    [tableView beginUpdates];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [tableView endUpdates];

    [BKjs delArchivedMessage:item success:nil failure:nil];
}

@end
