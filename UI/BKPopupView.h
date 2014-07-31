//
//  BKPopupView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKPopupView: UIView
@property (strong, nonatomic) NSDictionary *item;
@property (strong, nonatomic) UIButton *close;
@property (strong, nonatomic) UIScrollView *scroll;
@property (strong, nonatomic) UIImageView *avatar;
@property (strong, nonatomic) UILabel *alias;
@property (strong, nonatomic) UITextView *msg;
@property (strong, nonatomic) UIImageView *icon;
@property (strong, nonatomic) UILabel *title;
@property (strong, nonatomic) UITextView *text;

- (instancetype)init:(CGRect)frame params:(NSDictionary*)params completionHandler:(SuccessBlock)completionHandler;
- (void)show;
- (void)hide;
- (void)show:(SuccessBlock)finish;
- (void)hide:(SuccessBlock)finish;

@end

