//
//  BKItemViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKItemViewController.h"

@interface BKItemView () <UITextViewDelegate>
@end

@implementation BKItemView

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params
{
    self = [super initWithFrame:frame];
    
    self.scroll = [[UIScrollView alloc] initWithFrame:self.bounds];
    [self addSubview:self.scroll];
    
    self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.avatar.hidden = YES;
    [self.scroll addSubview:self.avatar];
    
    self.source = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.source.contentMode = UIViewContentModeScaleAspectFit;
    self.source.centerX = self.avatar.centerX;
    self.source.hidden = YES;
    [self.scroll addSubview:self.source];
    
    self.header = [BKui makeLabel:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor blackColor] font:[UIFont boldSystemFontOfSize:12]];
    self.header.numberOfLines = 0;
    [self.scroll addSubview:self.header];
    
    SuccessBlock urlBlock = ^(id url) { [BKWebViewController showURL:url completionHandler:nil]; };
    
    self.msg = [BKui makeTextView:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor blackColor] font:[UIFont systemFontOfSize:15]];
    self.msg.hidden = YES;
    self.msg.dataDetectorTypes = UIDataDetectorTypeLink;
    self.msg.delegate = self;
    self.msg.scrollEnabled = NO;
    self.msg.textContainer.lineFragmentPadding = 0;
    self.msg.contentInset = UIEdgeInsetsZero;
    objc_setAssociatedObject(self.msg, @"urlBlock", urlBlock, OBJC_ASSOCIATION_RETAIN);
    [self.scroll addSubview:self.msg];
    
    self.icon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.icon.hidden = YES;
    self.icon.contentMode = UIViewContentModeScaleAspectFit;
    [BKui setImageBorder:self.icon color:nil radius:8 border:0];
    [self.scroll addSubview:self.icon];
    
    self.title = [BKui makeLabel:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor blackColor] font:[UIFont boldSystemFontOfSize:17]];
    self.title.hidden = YES;
    self.title.numberOfLines = 0;
    self.title.lineBreakMode = NSLineBreakByWordWrapping;
    [self.scroll addSubview:self.title];
    
    self.text = [BKui makeTextView:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor blackColor] font:[UIFont systemFontOfSize:15]];
    self.text.hidden = YES;
    self.text.dataDetectorTypes = UIDataDetectorTypeLink;
    self.text.delegate = self;
    self.text.scrollEnabled = NO;
    self.text.textContainer.lineFragmentPadding = 0;
    self.text.contentInset = UIEdgeInsetsZero;
    objc_setAssociatedObject(self.text, @"urlBlock", urlBlock, OBJC_ASSOCIATION_RETAIN);
    [self.scroll addSubview:self.text];
    if (params) [self update:params];
    return self;
}

- (void)update:(NSDictionary*)params
{
    int y = 5, x = 5;
    
    if (params[@"avatar"] || params[@"avatar_id"]) {
        self.avatar.hidden = NO;
        self.avatar.frame = CGRectMake(x, y, 32, 32);
        self.avatar.image = [UIImage imageNamed:@"avatar_male"];
        [BKui setImageBorder:self.avatar color:nil radius:0 border:1];
        if (params[@"avatar"]) {
            [BKjs getIcon:params[@"avatar"] success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
        } else {
            [BKjs getAccountIcon:@{ @"id": params[@"avatar_id"], @"type": [params str:@"avatar_type"] } success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
        }
        x = self.avatar.right + 5;
    } else {
        self.avatar.hidden = YES;
    }
    
    if (params[@"source"]) {
        self.source.hidden = NO;
        self.source.frame = CGRectMake(0, 0, 12, 12);
        self.source.center = CGPointMake(21, self.avatar.bottom + 12);
        if ([params[@"source"] rangeOfString:@"/"].location == NSNotFound) {
            self.source.image = [UIImage imageNamed:params[@"source"]];
        } else {
            [BKjs getIcon:params[@"source"] success:^(UIImage *image, NSString *url) { self.source.image = image; } failure:nil];
        }
    } else {
        self.source.hidden = YES;
    }

    NSString *str = params[@"header"];
    if (!str && params[@"alias"]) str = [NSString stringWithFormat:@"%@  %@", params[@"alias"], params[@"mtime"] ? [BKjs strftime:[params num:@"mtime"]/1000 format:nil] : @""];
    if (str) {
        self.header.hidden = NO;
        self.header.text = str;
        self.header.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.header sizeToFit];
        y = self.header.bottom + 5;
    } else {
        self.header.hidden = YES;
    }
    
    if (params[@"msg"]) {
        self.msg.hidden = NO;
        self.msg.text = params[@"msg"];
        self.msg.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.msg sizeToFit];
        y = self.msg.bottom + 5;
    } else {
        self.msg.hidden = YES;
    }
    
    if (params[@"icon"]) {
        self.icon.hidden = NO;
        self.icon.frame = CGRectMake(x, y, self.width - x - 5, self.width/2);
        [BKjs getIcon:params[@"icon"] success:^(UIImage *image, NSString *url) { self.icon.image = image; } failure:nil];
        y = self.icon.bottom + 5;
    } else {
        self.icon.hidden = YES;
    }
    
    if (params[@"title"]) {
        self.title.hidden = NO;
        self.title.text = params[@"title"];
        self.title.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.title sizeToFit];
        y = self.title.bottom + 5;
    } else {
        self.title.hidden = YES;
    }

    if (params[@"text"]) {
        self.text.hidden = NO;
        self.text.text = params[@"text"];
        self.text.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.text sizeToFit];
        y = self.text.bottom + 5;
    } else {
        self.text.hidden = YES;
    }

    self.scroll.contentSize = CGSizeMake(self.width, y);
}

@end

@implementation BKItemPopupView {
    UIView *_bg;
}

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params
{
    self = [super initWithFrame:frame params:params];
    self.scroll.frame = CGRectMake(0, 44, self.width, self.height - 44);
    self.exclusiveTouch = YES;
    
    [BKui setViewBorder:self color:[UIColor darkGrayColor] radius:8];
    [BKui setViewShadow:self color:nil offset:CGSizeMake(-5, 5) opacity:0.5];
    
    self.closeButton = [BKui makeCustomButton:@"Close"];
    [self.closeButton addTarget:self action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.centerY = 22;
    self.closeButton.centerX = self.width - 10 - self.closeButton.width/2;
    [self addSubview:self.closeButton];
    
    _bg = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _bg.backgroundColor = [UIColor blackColor];

    return self;
}

- (void)onClose:(id)sender
{
    [self hide:nil];
}

- (void)show:(SuccessBlock)completion
{
    UIWindow *win = [[[UIApplication sharedApplication] delegate] window];

    _bg.alpha = 0.0;
    
    self.layer.opacity = 0.1;
    self.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0);

    [win addSubview:_bg];
    [win addSubview:self];

    [UIView animateWithDuration:0.5
                          delay:0.1
                        options:0
					 animations:^{
                         _bg.alpha = 0.5;
					 }
					 completion:nil];
    
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseInOut
					 animations:^{
                         self.layer.opacity = 1.0;
                         self.layer.transform = CATransform3DMakeScale(1, 1, 1);
					 }
					 completion:^(BOOL finished) {
                         if (completion) completion(self);
                     }];
}

- (void)hide:(SuccessBlock)completion
{
    _bg.alpha = 0.5f;
    
    self.layer.opacity = 0.5f;
    self.layer.transform = CATransform3DMakeScale(1, 1, 1.0);
    
    [UIView animateWithDuration:0.5
                          delay:0
                        options:0
					 animations:^{
                         _bg.alpha = 0;
					 }
					 completion:^(BOOL finished) {
                         [_bg removeFromSuperview];
                     }];
    
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.7
                        options:UIViewAnimationOptionCurveEaseInOut
					 animations:^{
                         self.layer.opacity = 0;
                         self.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1);
					 }
					 completion:^(BOOL finished) {
                         [_bg removeFromSuperview];
                         [self removeFromSuperview];
                         if (completion) completion(self);
                     }];
}

@end

@implementation BKItemViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.itemView = [[BKItemView alloc] initWithFrame:CGRectOffset(self.view.bounds, 0, 64) params:nil];
    [self.view addSubview:self.itemView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.itemView update:self.params];
}

@end
