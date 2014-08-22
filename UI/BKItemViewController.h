//
//  BKItemViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKPopupView.h"

@interface BKItemView: UIView
@property (strong, nonatomic) UIScrollView *scroll;
@property (strong, nonatomic) UIImageView *avatar;
@property (strong, nonatomic) UIImageView *source;
@property (strong, nonatomic) UILabel *header;
@property (strong, nonatomic) UITextView *msg;
@property (strong, nonatomic) UIImageView *icon;
@property (strong, nonatomic) UILabel *title;
@property (strong, nonatomic) UITextView *text;
@property (strong, nonatomic) UIView *line1;
@property (strong, nonatomic) UIView *line2;

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params;
- (void)update:(NSDictionary*)params;
- (void)clean;
@end;

@interface BKItemPopupView: BKPopupView
@property (strong, nonatomic) BKItemView *itemView;

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params;
@end

@interface BKItemViewController : BKViewController
@property (strong, nonatomic) BKItemView *itemView;

@end