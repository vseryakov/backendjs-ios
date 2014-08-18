//
//  Created by Vlad Seryakov on 7/15/14.
//  Copyright (c) 2014 Backendjs. All rights reserved.
//

@implementation SettingsViewController {
    UIImageView *_avatar;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableUnselected = YES;
    self.view.backgroundColor = BKui.style[@"menubar"][@"backgroundColor"];
    
    int h = self.view.width*0.3;
    _avatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, h, h)];
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.image = [UIImage imageNamed:@"avatar"];
    [BKui setRoundCorner:_avatar corner:UIRectCornerAllCorners radius:h/2];
    _avatar.centerX = (self.view.width - 40)/2;
    _avatar.centerY = 90;
    [self.view addSubview:_avatar];
    
    [self addTable];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.frame = CGRectMake(0, 180, self.view.width, self.view.height - 180);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 45;

    self.items = [@[@{ @"name": @"Avatar",
                       @"icon": @"settings",
                       @"badge": @{ @"count": @(BKapp.messageCount) },
                       @"selector": @"onAvatar" },
                    @{ @"name": @"Logout",
                       @"icon": @"logo",
                       @"view": @"Login" }] mutableCopy];
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    NSDictionary *item = [self getItem:indexPath];
    if (item[@"view"]) {
        [BKui showViewController:self name:item[@"view"] params:nil];
    } else
    if (item[@"selector"]) {
        [BKjs invoke:self name:item[@"selector"] arg:nil];
    }
}

- (void)onTableCell:(UITableViewCell*)cell indexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:item[@"icon"]]];
    image.center = CGPointMake(cell.height/2, cell.height/2);
    image.contentMode = UIViewContentModeCenter;
    [cell addSubview:image];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(self.tableView.rowHeight, 0, cell.width - 100, cell.height)];
    label.text = item[@"name"];
    [cell addSubview:label];

    if (item[@"badge"]) {
        UILabel *badge = [BKui makeBadge:cell style:item[@"badge"]];
        badge.center = CGPointMake(cell.width - 70, self.tableView.rowHeight/2+1);
    }
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, cell.height-1, cell.width, 1)];
    line.x = self.tableView.rowHeight;
    line.backgroundColor = [UIColor lightGrayColor];
    [cell addSubview:line];
}

- (void)onAvatar
{
    UIActionSheet *action = [BKui makeAction:@"Choose profile picture" actions:@[@"Social Network Albums",@"Photo Library",@"Camera",@"Delete picture"] finish:^(UIActionSheet *view, NSString *button) {
        if ([button isEqual:@"Social Network Albums"]) {
            [self showImagePickerFromAlbums:@{ @"accounts": [BKSocialAccount.accounts allValues], @"_imageView": _avatar }];
        }
        if ([button isEqual:@"Photo Library"]) {
            [self showImagePickerFromLibrary:self params:@{ @"_imageView": _avatar }];
        }
        if ([button isEqual:@"Camera"]) {
            [self showImagePickerFromCamera:self params:@{ @"_imageView": _avatar }];
        }
    }];
    [action showInView:self.view];
}

- (void)onImagePicker:(UIImage*)image params:(NSDictionary*)params
{
    if (!image) return;
    UIImageView *imgView = params[@"_imageView"];
    imgView.image = image;
}

@end
