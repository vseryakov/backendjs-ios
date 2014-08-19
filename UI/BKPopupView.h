//
//  BKPopupView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKPopupView: UIView
@property (strong, nonatomic) UIButton *closeButton;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)hide:(SuccessBlock)completion;
- (void)show:(SuccessBlock)completion;
- (void)onClose:(id)sender;
@end
