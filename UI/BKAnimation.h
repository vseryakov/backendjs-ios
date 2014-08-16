//
//  Animation.h
//
//  Created by Darren Ferguson and Vlad Seryakov on 12/16/13.
//  Copyright (c) 2013. All rights reserved.
//
//  Bounce animation is based on https://github.com/khanlou/SKBounceAnimation
//

@interface BKTransitionAnimation: NSObject<UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL presenting;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) float duration;
@property (nonatomic, assign) float damping;
@property (nonatomic, assign) float velocity;
@property (nonatomic, assign) float delay;
@property (nonatomic, assign) UIViewAnimationOptions options;

- (id)init:(BOOL)presenting params:(NSDictionary*)params;
@end

@interface BKBounceAnimation: CAKeyframeAnimation
@property (nonatomic, strong) id fromValue;
@property (nonatomic, strong) id toValue;
@property (nonatomic, assign) BOOL shaking;
@property (nonatomic, assign) BOOL overshoot;
@property (nonatomic, assign) NSUInteger bounces;
@property (nonatomic, assign) NSString *stiffness;

- (BKBounceAnimation*) initWithKeyPath:(NSString*)keyPath start:(SuccessBlock)start stop:(SuccessBlock)stop;
- (void) configure:(UIView*)view;
@end

@interface BKGlowAnimation: CABasicAnimation
@property (nonatomic, strong) UIColor *color;

- (BKGlowAnimation*) init:(SuccessBlock)start stop:(SuccessBlock)stop;
- (void) configure:(UIView*)view;
@end
