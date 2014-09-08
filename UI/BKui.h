//
//  BKui
//  Backendjs UI support class
//
//  Created by Vlad Seryakov on 7/1/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKjs.h"

@interface BKui: NSObject

// Return a ViewController by name, this method is supposed to be overriden for custom controllers
- (UIViewController*)getViewController:(NSString*)name;

// This needs to be called before using the BKui globally
- (void)configure;

// Retirj or set the global UI object
+ (BKui*)get;
+ (void)set:(BKui*)obj;

// Styles for UI components
+ (NSMutableDictionary*)style;

// Map of View Controllers to be uses by ShowViewController method
+ (NSMutableDictionary*)controllers;

#pragma mark UIkit utilities

// Current top view controller
+ (UIViewController*)rootController;
+ (UIViewController*)rootController:(UIViewController*)controller;

// Show a view controller by name, look into the controllers dictionay by name or check if a storyboard exists and has
// the view controller with the given name.
//  - name is a controller name in the contreollers dictionary or in a storyboard, name can be in the format: name@mode
//  - mode is the controller view mode, one of the push, modal, drawerLeft, drawerRight, draweLeftAnchor, drawerRightAnchor
//  - controller is supposed to be inherited of BKViewController but can be regular view controller as well
//  - owner is the currently active controller that initiates transition to the destination controller
+ (UIViewController*)showViewController:(UIViewController*)owner name:(NSString*)name params:(NSDictionary*)params;
+ (UIViewController*)showViewController:(UIViewController*)owner controller:(UIViewController*)controller name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params;

// Popup modal dialogs
+ (void)showAlert:(NSString *)title text:(NSString *)text delegate:(id)delegate cancelButtonText:(NSString*)cancel otherButtonTitles:(NSArray*)otherButtonTitles tag:(int)tag;
+ (void)showAlert:(NSString*)title text:(NSString*)text finish:(AlertBlock)finish;
+ (void)showConfirm:(NSString*)title text:(NSString*)text ok:(NSString*)ok cancel:(NSString*)cancel finish:(AlertBlock)finish;
+ (void)showConfirm:(NSString*)title text:(NSString*)text buttons:(NSArray*)buttons finish:(AlertBlock)finish;

// Activity indicator
+ (void)showActivity;
+ (void)showActivityInView:(UIView*)view;
+ (void)hideActivity;

// Create components, helper methods
+ (UIColor*)makeColor:(NSString *)color;
+ (UIColor *)makeColor:(UIColor*)color h:(double)h s:(double)s b:(double)b a:(double)a;
+ (UILabel*)makeLabel:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font;
+ (UITextView*)makeTextView:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font;
+ (UIActionSheet*)makeAction:(NSString *)title actions:(NSArray*)actions finish:(ActionBlock)finish;
+ (UIImageView*)makeImageAvatar:(UIView*)view frame:(CGRect)frame eclipse:(UIImage*)eclipse;
+ (UIImage*)makeImageWithTint:(UIImage*)image color:(UIColor*)color;
+ (UILabel*)makeBadge:(int)value font:(UIFont*)font color:(UIColor*)color bgColor:(UIColor*)bgColor borderColor:(UIColor*)borderColor;
+ (UILabel*)makeBadge:(UIView*)view style:(NSDictionary*)style;
+ (void)makeGloss:(UIView*)view;
+ (UIButton*)makeCustomButton:(NSString*)title image:(UIImage*)image;
+ (UIButton*)makeCustomButton:(NSString *)title image:(UIImage*)image action:(SuccessBlock)action;

// Modify components view and/or look
+ (void)setTextLinks:(UITextView*)label text:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler;
+ (void)setLabelLink:(UILabel*)label text:(NSString*)text link:(NSString*)link handler:(SuccessBlock)handler;
+ (void)setLabelAttributes:(UILabel*)label color:(UIColor*)color font:(UIFont*)font range:(NSRange)range;
+ (void)setViewBorder:(UIView*)view color:(UIColor*)color width:(float)width radius:(float)radius;
+ (void)setImageBorder:(UIView*)view color:(UIColor*)color radius:(float)radius border:(int)border;
+ (void)addImageWithBorderAndShadow:(UIView*)view image:(UIImageView*)image color:(UIColor*)color radius:(float)radius;
+ (void)setRoundCorner:(UIView*)view corner:(UIRectCorner)corner radius:(float)radius;
+ (void)setViewShadow:(UIView*)view color:(UIColor*)color offset:(CGSize)offset opacity:(float)opacity radius:(float)radius;
+ (void)addImageAtCorner:(UIView*)view image:(UIImageView*)image corner:(UIRectCorner)corner;

// Create placeholder text for the text view
+ (void)setPlaceholder:(UITextView*)view text:(NSString*)text;

// Make placeholder text visible depending if the text view contains any text
+ (void)checkPlaceholder:(UITextView*)view;

+ (void)shakeView:(UIView*)view;
+ (void)jiggleView:(UIView*)view;

// Apply a style from the dictionary to the view
+ (void)setStyle:(UIView*)view style:(NSDictionary*)style;

// Collect local contacts and return them in the mutable array, every item is mutable dictionary
+ (void)getContacts:(SuccessBlock)finish;

#pragma mark UIImage utilities

+ (UIImage*)scaleToSize:(UIImage*)image size:(CGSize)size;
+ (UIImage*)scaleToFit:(UIImage*)image size:(CGSize)size;
+ (UIImage*)scaleToFill:(UIImage*)image size:(CGSize)size;
+ (UIImage*)cropImage:(UIImage*)image frame:(CGRect)frame;
+ (UIImage*)orientImage:(UIImage*)image;
+ (UIImage*)captureImage:(UIView *)view;

@end
