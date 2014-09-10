//
//  BKSettingsViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKSettingsViewController : BKViewController

- (void)updateAccount:(NSString*)name value:(id)value;
- (void)doAction:(NSDictionary*)item;
- (BOOL)isRequired:(id)sender;
- (void)onRange:(BKRangeSlider*)sender;
- (void)onTextView:(UITextView*)sender;
- (void)onText:(UITextField*)sender;
- (void)onSlider:(UISlider*)sender;
- (void)onSwitch:(UISwitch*)sender;
- (void)onButton:(UIButton*)sender;
- (void)onView:(UIGestureRecognizer*)sender;
- (void)onPhoto:(UIImageView*)imgView;

@end
