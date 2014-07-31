//
//  BKViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKPopupView.h"

@interface BKPopupView () <UITextViewDelegate>
@end

@implementation BKPopupView

- (instancetype)init:(CGRect)frame params:(NSDictionary*)params completionHandler:(SuccessBlock)completionHandler
{
    self = [super init];
    self.frame = frame;
    self.exclusiveTouch = YES;
    [BKui setViewBorder:self color:[UIColor darkGrayColor] radius:8];
    [BKui setViewShadow:self color:nil offset:CGSizeMake(-5, 5) opacity:0.5];
    
    self.close = [BKui makeCustomButton];
    [self.close setTitle:@"Close" forState:UIControlStateNormal];
    [self.close addTarget:self action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    [self.close sizeToFit];
    self.close.centerY = 22;
    self.close.centerX = self.width - 10 - self.close.width/2;
    if (completionHandler) objc_setAssociatedObject(self.close, @"completionHandler", completionHandler, OBJC_ASSOCIATION_RETAIN);
    [self addSubview:self.close];
    
    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, self.width, self.height - 50)];
    [self addSubview:self.scroll];
    if (!params) return self;
    
    int y = 5, x = 10;
    
    if (params[@"avatar"] || params[@"avatar_id"]) {
        self.avatar = [BKui makeImageAvatar:self.scroll frame:CGRectMake(5, y, 32, 32) eclipse:[UIImage imageNamed:@"avatar_eclipse"]];
        self.avatar.image = [UIImage imageNamed:@"avatar_male"];
        // In case of a path or url use it directly otherwise treat as an account id
        if (params[@"avatar"]) {
            [BKjs getIcon:params[@"avatar"] success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
        } else {
            [BKjs getAccountIcon:@{ @"id": params[@"avatar_id"], @"type": [params str:@"avatar_type"] } success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
        }
        x = self.avatar.right + 5;
    }
    
    self.alias = [BKui makeLabel:CGRectMake(x, y, self.width - x - 5, 12) text:[params str:@"alias"] color:[UIColor blackColor] font:[UIFont boldSystemFontOfSize:13]];
    self.alias.numberOfLines = 0;
    [self.alias sizeToFit];
    [self.scroll addSubview:self.alias];
    y = self.alias.bottom + 5;
    
    SuccessBlock urlBlock = ^(id url) {
        BKWebViewController *web = [BKWebViewController initWithDelegate:nil completionHandler:nil];
        [web start:[NSURLRequest requestWithURL:[NSURL URLWithString:url]] completionHandler:nil];
        [web show];
    };
    
    self.msg = [BKui makeTextView:CGRectMake(x, y, self.width - x - 5, 45) text:[params str:@"msg"] color:[UIColor blackColor] font:[UIFont systemFontOfSize:15]];
    self.msg.dataDetectorTypes = UIDataDetectorTypeLink;
    self.msg.delegate = self;
    objc_setAssociatedObject(self.msg, @"urlBlock", urlBlock, OBJC_ASSOCIATION_RETAIN);
    [self.msg sizeToFit];
    [self.scroll addSubview:self.msg];
    y = self.msg.bottom + 5;
    
    if (params[@"icon"]) {
        self.icon = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, self.width - x*2, self.width - x*2)];
        self.icon.contentMode = UIViewContentModeScaleAspectFit;
        self.icon.image = [UIImage imageNamed:@"loading"];
        [BKui setImageBorder:self.icon color:nil radius:8 border:0];
        [self.scroll addSubview:self.icon];
        y = self.icon.bottom + 5;
        
        [BKjs getIcon:params[@"icon"] success:^(UIImage *image, NSString *url) {
            self.icon.image = image;
        } failure:^(NSInteger code, NSString *reason) {
            self.icon.hidden = YES;
        }];
    }
    
    if (params[@"title"]) {
        self.title = [BKui makeLabel:CGRectMake(x, y, self.width - x - 5, 50) text:params[@"title"] color:[UIColor blackColor] font:[UIFont boldSystemFontOfSize:16]];
        self.title.numberOfLines = 0;
        self.title.preferredMaxLayoutWidth = self.title.width;
        self.title.lineBreakMode = NSLineBreakByWordWrapping;
        [self.title sizeToFit];
        [self.scroll addSubview:self.title];
        y = self.title.bottom + 5;
    }
    
    if (params[@"text"]) {
        self.text = [BKui makeTextView:CGRectMake(x, y, self.width - x - 5, 50) text:params[@"text"] color:[UIColor blackColor] font:[UIFont systemFontOfSize:15]];
        self.text.dataDetectorTypes = UIDataDetectorTypeLink;
        self.text.delegate = self;
        objc_setAssociatedObject(self.text, @"urlBlock", urlBlock, OBJC_ASSOCIATION_RETAIN);
        [self.text sizeToFit];
        [self.scroll addSubview:self.text];
        y = self.text.bottom + 5;
    }
    self.scroll.contentSize = CGSizeMake(self.width, y);
    return self;
}

- (void)onClose:(id)sender
{
    [self hide];
}

- (void)hide
{
    [self hide:nil];
}

- (void)hide:(SuccessBlock)finish
{
    self.layer.opacity = 0.5f;
    self.layer.transform = CATransform3DMakeScale(1, 1, 1.0);
    
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
                         if (finish) finish(self);
                         SuccessBlock block = objc_getAssociatedObject(self.close, @"completionHandler");
                         if (block) {
                             objc_setAssociatedObject(self.close, @"completionHandler", nil, 0);
                             block(self);
                         }
                     }];
}

- (void)show
{
    [self show:nil];
}

- (void)show:(SuccessBlock)finish
{
    self.layer.opacity = 0.1;
    self.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0);
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
                         if (finish) finish(self);
                     }];
}

@end

