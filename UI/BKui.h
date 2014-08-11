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

+ (BKui*)get;
+ (void)set:(BKui*)obj;

// Styles for UI components
+ (NSMutableDictionary*)style;

// Map of View Controllers to be uses by ShowViewController method
+ (NSMutableDictionary*)controllers;

#pragma mark UIkit utilities

+ (UIViewController*)rootController;
+ (UIViewController*)rootController:(UIViewController*)controller;

+ (void)showAlert:(NSString *)title text:(NSString *)text delegate:(id)delegate cancelButtonText:(NSString*)cancel otherButtonTitles:(NSArray*)otherButtonTitles tag:(int)tag;
+ (void)showAlert:(NSString*)title text:(NSString*)text confirmHandler:(AlertBlock)confirmHandler;
+ (void)showConfirm:(NSString*)title text:(NSString*)text ok:(NSString*)ok cancel:(NSString*)cancel confirmHandler:(AlertBlock)confirmHandler;
+ (void)showConfirm:(NSString*)title text:(NSString*)text buttons:(NSArray*)buttons confirmHandler:(AlertBlock)confirmHandler;
+ (void)showViewController:(UIViewController*)owner name:(NSString*)name params:(NSDictionary*)params;
+ (void)showViewController:(UIViewController*)owner controller:(UIViewController*)controller name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params;

+ (void)showActivity;
+ (void)showActivityInView:(UIView*)view;
+ (void)hideActivity;

+ (UIColor*)makeColor:(NSString *)color;
+ (UIColor *)makeColor:(UIColor*)color h:(double)h s:(double)s b:(double)b a:(double)a;
+ (UILabel*)makeLabel:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font;
+ (UITextView*)makeTextView:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font;
+ (UIActionSheet*)makeAction:(NSString *)title actions:(NSArray*)actions confirmHandler:(ActionBlock)confirmHandler;
+ (UIImageView*)makeImageAvatar:(UIView*)view frame:(CGRect)frame eclipse:(UIImage*)eclipse;
+ (UIImageView*)makeImageWithBadge:(CGRect)frame icon:(NSString*)icon color:(UIColor*)color value:(int)value insets:(CGPoint)insets;
+ (UIImage*)makeImageWithTint:(UIImage*)image color:(UIColor*)color;

+ (UIButton*)makeCustomButton:(NSString*)title image:(UIImage*)image;

+ (void)setTextLinks:(UITextView*)label text:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler;
+ (void)setLabelLink:(UILabel*)label text:(NSString*)text link:(NSString*)link handler:(SuccessBlock)handler;
+ (void)setLabelAttributes:(UILabel*)label color:(UIColor*)color font:(UIFont*)font range:(NSRange)range;
+ (void)setViewBorder:(UIView*)view color:(UIColor*)color width:(float)width radius:(float)radius;
+ (void)setImageBorder:(UIView*)view color:(UIColor*)color radius:(float)radius border:(int)border;
+ (void)addImageWithBorderAndShadow:(UIView*)view image:(UIImageView*)image color:(UIColor*)color radius:(float)radius;
+ (void)setRoundCorner:(UIView*)view corner:(UIRectCorner)corner radius:(float)radius;
+ (void)setViewShadow:(UIView*)view color:(UIColor*)color offset:(CGSize)offset opacity:(float)opacity radius:(float)radius;

+ (void)setPlaceholder:(UITextView*)view text:(NSString*)text;
+ (void)checkPlaceholder:(UITextView*)view;

+ (void)addImageAtCorner:(UIView*)view image:(UIImageView*)image corner:(UIRectCorner)corner;

+ (void)shakeView:(UIView*)view;
+ (void)jiggleView:(UIView*)view;

+ (void)setStyle:(UIView*)view style:(NSDictionary*)style;

+ (void)getContacts:(SuccessBlock)finish;

#pragma mark UIImage utilities

+ (UIImage*)scaleToSize:(UIImage*)image size:(CGSize)size;
+ (UIImage*)scaleToFit:(UIImage*)image size:(CGSize)size;
+ (UIImage*)scaleToFill:(UIImage*)image size:(CGSize)size;
+ (UIImage *)cropImage:(UIImage*)image frame:(CGRect)frame;
+ (UIImage *)orientImage:(UIImage*)image;
+ (UIImage *)captureImage:(UIView *)view;

@end
