//
//  BKSettingsViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2014 All rights reserved.
//

#import "BKSettingsViewController.h"

@interface BKSettingsViewController () <UITextFieldDelegate,UITextViewDelegate>
@end

@implementation BKSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableUnselected = YES;
    [self addTable];
    [self addToolbar:@"Settings" params:nil];
}

- (void)updateAccount:(NSString*)name value:(id)value
{
    if (!name || !value) return;
    [BKjs updateAccount:@{ name: value, @"cid": [BKapp.campaign str:@"id"] } success:nil failure:^(NSInteger code, NSString *reason) {
        [BKui showAlert:@"Error" text:reason finish:nil];
    }];
}

- (void)doAction:(NSDictionary*)item
{
    if (item[@"view"]) {
        [BKui showViewController:self name:item[@"view"] params:item[@"params"]];
    } else
    if (item[@"block"]) {
        SuccessBlock block = item[@"block"];
        block(item[@"params"]);
    } else
    if (item[@"selector"]) {
        [BKjs invoke:item[@"delegate"] ? item[@"delegate"] : self name:item[@"selector"] arg:item[@"params"]];
    }
}

- (BOOL)isRequired:(id)sender
{
    if (!self.view.superview || !self.view.window || !self.parentViewController) return NO;
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    if (item[@"required"] && [BKjs isEmpty:[sender text]]) {
        [BKui showAlert:@"Required" text:[NSString stringWithFormat:@"%@ cannot be empty, please enter some value", item[@"title"]] finish:nil];
        return YES;
    }
    return NO;
}

- (void)onView:(UIGestureRecognizer*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender.view, @"item");
    [self doAction:item];
}

- (IBAction)onButton:(UIButton*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self doAction:item];
}

- (IBAction)onSwitch:(UISwitch*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self updateAccount:item[@"config"] value:[NSNumber numberWithBool:sender.on]];
}

- (IBAction)onSlider:(UISlider*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self updateAccount:item[@"config"] value:[NSNumber numberWithFloat:sender.value]];
}

- (IBAction)onText:(UITextField*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self updateAccount:item[@"config"] value:sender.text];
}

- (IBAction)onTextView:(UITextView*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self updateAccount:item[@"config"] value:sender.text];
}

- (IBAction)onRange:(BKRangeSlider*)sender
{
    NSDictionary *item = objc_getAssociatedObject(sender, @"item");
    [self updateAccount:item[@"config0"] value:[NSNumber numberWithDouble:sender.value0]];
    [self updateAccount:item[@"config1"] value:[NSNumber numberWithDouble:sender.value1]];
    UILabel *label = objc_getAssociatedObject(sender, @"minLabel");
    label.text = [NSString stringWithFormat:@"%0.f", sender.value0];
    label = objc_getAssociatedObject(sender, @"maxLabel");
    label.text = [NSString stringWithFormat:@"%0.f", sender.value1];
}

- (void)onImagePicker:(id)picker image:(UIImage*)image params:(NSDictionary*)params
{
    if (!image) return;
    UIImageView *imgView = params[@"_imageView"];
    NSDictionary *item = objc_getAssociatedObject(imgView, @"item");
    
    [self showActivity];
    [BKjs putAccountIcon:image params:item[@"params"] success:^{
        [self hideActivity];
        imgView.image = image;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"profileUpdated" object:nil];
    } failure:^(NSInteger code, NSString *reason) {
        [self hideActivity];
        [BKui showAlert:@"Error" text:reason finish:nil];
    }];
}

- (void)onPhoto:(UIImageView*)imgView
{
    UIActionSheet *action = [BKui makeAction:@"Choose profile picture" actions:@[@"Social Network Albums",@"Photo Library",@"Camera",@"Delete picture"] finish:^(UIActionSheet *view, NSString *button) {
        if ([button isEqual:@"Delete picture"]) {
            NSDictionary *item = objc_getAssociatedObject(imgView, @"item");
            [BKjs delAccountIcon:item[@"params"] success:^{
                imgView.image = [BKapp profileAvatar];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"profileUpdated" object:nil];
            } failure:nil];
        }
        if ([button isEqual:@"Social Network Albums"]) {
            [self showImagePickerFromAlbums:@{ @"accounts": [BKapp connectedAccounts:NO], @"_imageView": imgView }];
        }
        if ([button isEqual:@"Photo Library"]) {
            [self showImagePickerFromLibrary:self params:@{ @"_imageView": imgView }];
        }
        if ([button isEqual:@"Camera"]) {
            [self showImagePickerFromCamera:self params:@{ @"_imageView": imgView }];
        }
    }];
    [action showInView:self.view];
}

#pragma mark UITextFieldDelegate

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self hideKeyboard];
    return YES;
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    [self onText:textField];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return ![self isRequired:textField];
}

#pragma mark UITextViewDelegate

-(void)textViewDidEndEditing:(UITextView *)textView
{
    [self onTextView:textView];
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    return ![self isRequired:textView];
}

#pragma mark - Table view data source

- (UITableViewCellStyle)getTableCellStyle:(NSIndexPath*)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if (item[@"subtitle"] || item[@"detailTextLabel"]) return UITableViewCellStyleSubtitle;
    return UITableViewCellStyleDefault;
}

- (void)onTableCell:(UITableViewCell*)cell indexPath:(NSIndexPath*)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if (!item) return;
    
    [BKui setStyle:cell style:item];
    
    if ([item[@"type"] isEqual:@"view"]) {
        objc_setAssociatedObject(cell, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onView:)]];
    }
    if ([item[@"type"] isEqual:@"switch"]) {
        UISwitch *button = [[UISwitch alloc] init];
        objc_setAssociatedObject(button, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        button.on = [BKjs.account num:item[@"config"]] > 0;
        [button addTarget:self action:@selector(onSwitch:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = button;
    }
    if ([item[@"type"] isEqual:@"slider"]) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cell.width, self.tableView.rowHeight/2)];
        label.text = item[@"name"];
        label.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:label];
        
        UILabel *min = [[UILabel alloc] initWithFrame:CGRectMake(0, self.tableView.rowHeight/2, 50, self.tableView.rowHeight)];
        min.text = item[@"min"];
        min.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:min];
        
        UILabel *max = [[UILabel alloc] initWithFrame:CGRectMake(cell.width - 50, self.tableView.rowHeight/2, 50, self.tableView.rowHeight)];
        max.text = item[@"max"];
        max.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:max];
        
        UISlider *button = [[UISlider alloc] initWithFrame:CGRectMake(50, self.tableView.rowHeight/2, cell.width - 100, self.tableView.rowHeight)];
        objc_setAssociatedObject(button, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        button.value = [BKjs.account num:item[@"config"]];
        button.minimumValue = [item[@"min"] integerValue];
        button.maximumValue = [item[@"max"] integerValue];
        [button addTarget:self action:@selector(onSlider:) forControlEvents:UIControlEventValueChanged];
        [cell addSubview:button];
    }
    if ([item[@"type"] isEqual:@"range"]) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cell.width, self.tableView.rowHeight/2)];
        label.text = item[@"name"];
        label.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:label];
        
        UILabel *min = [[UILabel alloc] initWithFrame:CGRectMake(0, self.tableView.rowHeight/2, 50, self.tableView.rowHeight)];
        min.text = item[@"min"];
        min.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:min];
        
        UILabel *max = [[UILabel alloc] initWithFrame:CGRectMake(cell.width - 50, self.tableView.rowHeight/2, 50, self.tableView.rowHeight)];
        max.text = item[@"max"];
        max.textAlignment = NSTextAlignmentCenter;
        [cell addSubview:max];
        
        BKRangeSlider *button = [[BKRangeSlider alloc] initWithFrame:CGRectMake(50, self.tableView.rowHeight/2, cell.width - 100, self.tableView.rowHeight)];
        objc_setAssociatedObject(button, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        double val0 = [BKjs.account num:item[@"config0"]];
        double val1 = [BKjs.account num:item[@"config1"]];
        button.minValue = [item[@"min"] intValue];
        button.maxValue = [item[@"max"] intValue];
        button.minRange = 1;
        button.value0 = val0 >= button.minValue ? val0 : button.minValue;
        button.value1 = val1 <= button.maxValue ? val1 : button.maxValue;
        [button addTarget:self action:@selector(onRange:) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(button, @"minLabel", min, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, @"maxLabel", max, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell addSubview:button];
    }
    if ([item[@"type"] isEqual:@"button"]) {
        UIButton *button = [BKui makeCustomButton:nil image:nil];
        button.frame = CGRectInset(cell.frame, 5, 5);
        objc_setAssociatedObject(button, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:self action:@selector(onButton:) forControlEvents:UIControlEventTouchUpInside];
        [BKui setStyle:button style:item[@"button"]];
        [cell addSubview:button];
    }
    if ([item[@"type"] isEqual:@"textfield"]) {
        UITextField *text = [[UITextField alloc] initWithFrame:CGRectMake(cell.width/2, 10, cell.width/2 - 5, cell.height - 20)];
        objc_setAssociatedObject(text, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [BKui setViewBorder:text color:nil width:1 radius:3];
        text.text = [BKjs.account str:item[@"config"]];
        text.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, text.height)];
        text.leftViewMode = UITextFieldViewModeAlways;
        text.tag = 999;
        text.delegate = self;
        [BKui setStyle:text style:item[@"textfield"]];
        [cell addSubview:text];
    }
    if ([item[@"type"] isEqual:@"textarea"]) {
        UITextView *text = [[UITextView alloc] initWithFrame:CGRectMake(cell.width/2, 10, cell.width/2 - 5, cell.height - 20)];
        objc_setAssociatedObject(text, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [BKui setViewBorder:text color:nil width:1 radius:3];
        text.text = [BKjs.account str:item[@"config"]];
        text.contentInset = UIEdgeInsetsMake(0, 5, 0, 0);
        text.tag = 999;
        text.delegate = self;
        [BKui setStyle:text style:item[@"textarea"]];
        [cell addSubview:text];
    }
    if ([item[@"type"] isEqual:@"photo"]) {
        UIImageView *img = [BKui makeImageAvatar:cell frame:CGRectMake(cell.width - cell.height, 10, cell.height - 10, cell.height - 10) color:nil border:1 eclipse:nil];
        img.image = item[@"placeholder"] ? [UIImage imageNamed:item[@"placeholder"]] : [(AppDelegate*)BKjs.appDelegate profileAvatar];
        img.userInteractionEnabled = YES;
        img.tag = 999;
        objc_setAssociatedObject(img, @"item", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell addSubview:img];
        [BKjs getAccountIcon:item[@"params"] options:BKCacheModeCache success:^(UIImage *image, NSString *url) { img.image = image; } failure:nil];
    }
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    [self hideKeyboard];
    
    NSDictionary *item = [self getItem:indexPath];
    if (!item) return;
    
    if ([item[@"type"] isEqual:@"photo"]) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [self onPhoto:(UIImageView*)[cell viewWithTag:999]];
    }
    if (item[@"url"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:item[@"url"]]];
    }
    if (item[@"config-url"]) {
        NSString *url = BKjs.account[item[@"config-url"]];
        if (url) [BKWebViewController showURL:url completionHandler:nil];
    }
    if (item[@"block"]) {
        SuccessBlock block = item[@"block"];
        block(item[@"params"]);
    }
    if (item[@"selector"]) {
        [BKjs invoke:item[@"delegate"] ? item[@"delegate"] : self name:item[@"selector"] arg:item];
    }
    if (item[@"view"]) {
        [BKui showViewController:self name:item[@"view"] params:item[@"params"]];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if (!item) return tableView.rowHeight;
    if (item[@"rowHeight"]) return [item num:@"rowHeight"];
    if ([item[@"type"] isEqual:@"slider"]) return tableView.rowHeight*1.5;
    if ([item[@"type"] isEqual:@"range"]) return tableView.rowHeight*1.5;
    if ([item[@"type"] isEqual:@"photo"]) return tableView.rowHeight*2;
    if ([item[@"type"] isEqual:@"textarea"]) return tableView.rowHeight*2;
    return tableView.rowHeight;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return section == 0 ? 0 : tableView.rowHeight/2;
}

@end
