//
//  BKItemViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKItemView: UIView
@property (strong, nonatomic) UIScrollView *scroll;
@property (strong, nonatomic) UIImageView *avatar;
@property (strong, nonatomic) UIImageView *source;
@property (strong, nonatomic) UILabel *header;
@property (strong, nonatomic) UITextView *msg;
@property (strong, nonatomic) UIImageView *icon;
@property (strong, nonatomic) UILabel *title;
@property (strong, nonatomic) UITextView *text;

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params;
- (void)update:(NSDictionary*)params;
@end;

@interface BKItemPopupView: BKItemView
@property (strong, nonatomic) UIButton *closeButton;

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params;
- (void)hide:(SuccessBlock)completion;
- (void)show:(SuccessBlock)completion;
@end

@interface BKItemViewController : BKViewController
@property (strong, nonatomic) BKItemView *itemView;

@end