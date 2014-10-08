//
//  BKPopupView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKPopupView.h"

@implementation BKPopupView {
    UIView *_bg;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.exclusiveTouch = YES;
    
    [BKui setViewBorder:self color:[UIColor darkGrayColor] width:1 radius:8];
    [BKui setViewShadow:self color:nil offset:CGSizeMake(-5, 5) opacity:0.5 radius:-1];
    
    self.closeButton = [BKui makeCustomButton:@"Close" image:nil];
    [self.closeButton sizeToFit];
    [self.closeButton addTarget:self action:@selector(onClose:) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.centerY = 22;
    self.closeButton.x = 10;
    [self addSubview:self.closeButton];
    
    _bg = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _bg.backgroundColor = [UIColor blackColor];

    return self;
}

- (void)onClose:(id)sender
{
    [self hide:nil];
}

- (void)showInView:(UIView*)view completion:(SuccessBlock)completion
{
    _bg.alpha = 0.0;
    
    self.layer.opacity = 0.1;
    self.layer.transform = CATransform3DMakeScale(0.3, 0.3, 1.0);

    [view addSubview:_bg];
    [view addSubview:self];

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
