//
//  BKui
//
//  Created by Vlad Seryakov on 7/04/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKui.h"
#import <sys/sysctl.h>

static BKui *_BKui;
static UIActivityIndicatorView *_activity;

@interface BKui () <UIActionSheetDelegate,UIAlertViewDelegate,UITextViewDelegate>
@end

@implementation BKui

+ (instancetype)get
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{
        _BKui = [BKui new];
        _BKui.controllers = [@{} mutableCopy];
        
        _activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activity.hidesWhenStopped = YES;
        _activity.hidden = YES;
        _activity.layer.backgroundColor = [[UIColor colorWithWhite:0.0f alpha:0.4f] CGColor];
        _activity.frame = CGRectMake(0, 0, 64, 64);
        _activity.layer.masksToBounds = YES;
        _activity.layer.cornerRadius = 8;
    });
    return _BKui;
}

- (void)configure
{
    
}
#pragma mark Utilities

+ (void)set:(BKui*)obj
{
    _BKui = obj;
}

#pragma mark UIView and controllers

+ (UIViewController*)rootController:(UIViewController*)controller
{
    UIViewController *root = controller;
    
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = ((UINavigationController *)root).visibleViewController;
        if (visible) root = visible;
    }
    return (root != controller ? root : nil);
}

+ (UIViewController*)rootController
{
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *next = nil;
    while ((next = [BKui rootController:root]) != nil) root = next;
    return root;
}

- (UIViewController*)getViewController:(NSString*)name
{
    return nil;
}

+ (void)showViewController:(UIViewController*)owner name:(NSString*)name params:(NSDictionary*)params
{
    Logger(@"name: %@, params: %@", name, params ? params : @"");

    if (!name) return;
    NSString *title = name;
    NSString *mode = nil;
    
    // Split the name into name and mode
    NSArray *q = [title componentsSeparatedByString:@"@"];
    if (q.count > 1) {
        title = q[0];
        mode = q[1];
    }
    UIViewController *controller = [self get].controllers[title];
    if (!controller) controller = [[self get] getViewController:title];
    if (!controller) {
        if ([[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"]) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[NSString stringWithFormat:@"MainStoryboard_%@", BKjs.iOSPlatform] bundle:nil];
            if (storyboard) controller = [storyboard instantiateViewControllerWithIdentifier:title];
        }
    }
    [self showViewController:owner controller:controller name:title mode:mode params:params];
}

+ (void)showViewController:(UIViewController*)owner controller:(UIViewController*)controller name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params
{
    Debug(@"name: %@, mode: %@, params: %@", name, mode, params ? params : @"");
    
    if (!controller) {
        Logger(@"Error: name: %@, mode: %@, no controller provided", name, mode);
        return;
    }
    BKViewController *view = nil;
    if (!owner) owner = [self rootController];
    
    // Pass parameters to the new controller, save caller and controller name for reference
    if ([controller isKindOfClass:[BKViewController class]]) {
        view = (BKViewController*)controller;
        [view prepareForShow:owner name:name mode:mode params:params];
    }
    
    if ([mode hasPrefix:@"modal"]) {
        [owner presentViewController:controller animated:YES completion:nil];
    } else
    if ([mode hasPrefix:@"push"]) {
        [owner.navigationController pushViewController:controller animated:YES];
    } else
    if ([mode hasPrefix:@"drawer"]) {
        if (view) [view showDrawer:owner];
    } else {
        [owner.navigationController setViewControllers:@[controller] animated:YES];
    }
}

+ (void)showAlert:(NSString *)title text:(NSString *)text delegate:(id)delegate cancelButtonText:(NSString*)cancel otherButtonTitles:(NSArray*)otherButtonTitles tag:(int)tag
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:text delegate:delegate cancelButtonTitle:cancel otherButtonTitles:nil];
    for (NSString *buttonTitle in otherButtonTitles) [alert addButtonWithTitle:buttonTitle];
    alert.tag = tag;
    [alert show];
}

+ (void)showAlert:(NSString*)title text:(NSString*)text confirmHandler:(AlertBlock)confirmHandler
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:@"OK" otherButtonTitles:nil];
    if (confirmHandler) objc_setAssociatedObject(alertView, @"alertBlock", confirmHandler, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (void)showConfirm:(NSString*)title text:(NSString*)text buttons:(NSArray*)buttons confirmHandler:(AlertBlock)confirmHandler
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:nil otherButtonTitles:nil];
    for (NSString *key in buttons) [alertView addButtonWithTitle:key];
    if (confirmHandler) objc_setAssociatedObject(alertView, @"alertBlock", confirmHandler, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (void)showConfirm:(NSString*)title text:(NSString*)text ok:(NSString*)ok cancel:(NSString*)cancel confirmHandler:(AlertBlock)confirmHandler
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:cancel ? cancel : @"Cancel" otherButtonTitles:ok ? ok : @"OK",nil];
    if (confirmHandler) objc_setAssociatedObject(alertView, @"alertBlock", confirmHandler, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (UIActionSheet*)makeAction:(NSString *)title actions:(NSArray*)actions confirmHandler:(ActionBlock)confirmHandler
{
    UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:title delegate:[self get] cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *button in actions) [action addButtonWithTitle:button];
    action.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    if (confirmHandler) objc_setAssociatedObject(action, @"actionBlock", confirmHandler, OBJC_ASSOCIATION_RETAIN);
    return action;
}

+ (void)showActivity
{
    UIViewController *root = [BKui rootController];
    [self showActivityInView:root.view];
}

+ (void)showActivityInView:(UIView*)view
{
    if (_activity.superview) return;
    [view addSubview:_activity];
    _activity.center = view.center;
    _activity.hidden = NO;
    [_activity startAnimating];
}

+ (void)hideActivity
{
    [_activity stopAnimating];
    [_activity removeFromSuperview];
}

#pragma mark UI components

+ (UIColor*)makeColor:(NSString *)color
{
    int r, g, b;
    if (color && color.length == 7) {
        const char *str = [color UTF8String];
        sscanf(str, "#%2x%2x%2x", &r, &g, &b);
        return [UIColor colorWithRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0];
    } else
    if (color && color.length == 4) {
        const char *str = [color UTF8String];
        sscanf(str, "#%x%x%x", &r, &g, &b);
        return [UIColor colorWithRed:(r / 255.0) green:(g / 255.0) blue:(b / 255.0) alpha:1.0];
    }
    return nil;
}

+ (UILabel*)makeLabel:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font
{
    UILabel* label = [[UILabel alloc] initWithFrame:frame];
    label.text = [BKjs toString:text];
    if (color) label.textColor = color;
    if (font) label.font = font;
    return label;
}

+ (UITextView*)makeTextView:(CGRect)frame text:(NSString*)text color:(UIColor*)color font:(UIFont*)font
{
    UITextView* label = [[UITextView alloc] initWithFrame:frame];
    label.text = [BKjs toString:text];
    label.editable = NO;
    if (color) label.textColor = color;
    if (font) label.font = font;
    return label;
}

+ (void)setLabelLink:(UILabel*)label text:(NSString*)text link:(NSString*)link handler:(SuccessBlock)handler
{
    if (!text || !text.length || !link || !link.length) return;
    NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
    [str addAttribute:NSLinkAttributeName value:link range:[str.string rangeOfString:link]];
    [str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:[str.string rangeOfString:link]];
    [label setAttributedText:str];
    label.userInteractionEnabled = YES;
    
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setFrame:label.frame];
    [btn addTarget:[self get] action:@selector(onLabelLink:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(btn, @"labelLink", link, OBJC_ASSOCIATION_RETAIN);
    if (handler) objc_setAssociatedObject(btn, @"labelBlock", handler, OBJC_ASSOCIATION_RETAIN);
    [label addSubview:btn];
}

- (void)onLabelLink:(id)sender
{
    NSString *link = objc_getAssociatedObject(sender, @"labelLink");
    SuccessBlock block = objc_getAssociatedObject(sender, @"labelBlock");
    Debug(@"%@", link);
    if (block) {
        block(link);
    } else {
        if (link) [BKWebViewController showURL:link completionHandler:nil];
    }
}

+ (void)setTextLinks:(UITextView*)label text:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler
{
    NSMutableAttributedString* str = [[NSMutableAttributedString alloc] initWithString:text];
    for (NSString *link in links) {
        [str addAttribute:NSLinkAttributeName value:link range:[str.string rangeOfString:link]];
        [str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:[str.string rangeOfString:link]];
    }
    [label setAttributedText:str];
    if (handler) objc_setAssociatedObject(label, @"urlBlock", handler, OBJC_ASSOCIATION_RETAIN);
    if (!label.delegate) label.delegate = [self get];
}

+ (UIImageView*)makeImageAvatar:(UIView*)view frame:(CGRect)frame eclipse:(UIImage*)eclipse
{
    UIImageView *avatar = [[UIImageView alloc] initWithImage:eclipse];
    avatar.frame = frame;
    [view addSubview:avatar];
    
    UIImageView *img = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, avatar.width-3, avatar.height-3)];
    img.center = avatar.center;
    img.contentMode = UIViewContentModeScaleAspectFill;
    img.layer.cornerRadius = img.width/2;
    img.layer.masksToBounds = YES;
    [view addSubview:img];
    return img;
}

+ (void)setViewShadow:(UIView*)view color:(UIColor*)color offset:(CGSize)offset opacity:(float)opacity
{
    view.layer.masksToBounds = NO;
    view.layer.shadowColor = color ? color.CGColor : [UIColor blackColor].CGColor;
    view.layer.shadowOffset = offset;
    view.layer.shadowOpacity = opacity < 0 ? 0.5 : opacity;
    view.layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
}

+ (void)setViewBorder:(UIView*)view color:(UIColor*)color radius:(float)radius
{
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = radius;
    view.layer.borderColor = color ? color.CGColor : [UIColor lightGrayColor].CGColor;
    view.layer.borderWidth = 1;
}

+ (void)setLabelAttributes:(UILabel*)label color:(UIColor*)color font:(UIFont*)font range:(NSRange)range
{
    NSMutableAttributedString *attr = label.attributedText ?
    [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText] :
    [[NSMutableAttributedString alloc] initWithString:label.text];
    
    if (color) [attr addAttributes:@{NSForegroundColorAttributeName: color} range:range];
    if (font) [attr addAttributes:@{NSFontAttributeName: font} range:range];
    label.attributedText = attr;
}

+ (void)setImageBorder:(UIView*)view color:(UIColor*)color radius:(float)radius border:(int)border
{
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = radius ? radius : view.frame.size.width/2;
    view.layer.borderColor = color ? color.CGColor : [UIColor lightGrayColor].CGColor;
    view.layer.borderWidth = border;
}

+ (void)addImageWithBorderAndShadow:(UIView*)view image:(UIImageView*)image color:(UIColor*)color radius:(float)radius
{
    UIView *shadowView = [[UIView alloc] initWithFrame:view.bounds];
    shadowView.center = CGPointMake(view.frame.size.width / 2, view.frame.size.height / 2);
    shadowView.backgroundColor = [UIColor clearColor];
    shadowView.layer.shadowColor = [[UIColor blackColor] CGColor];
    shadowView.layer.shadowOpacity = 0.9;
    shadowView.layer.shadowRadius = 2;
    shadowView.layer.shadowOffset = CGSizeMake(0, 0);
    
    image.frame = view.bounds;
    image.center = shadowView.center;
    image.layer.cornerRadius = radius ? radius : image.frame.size.width/2;
    image.layer.masksToBounds = YES;
    image.layer.borderColor = color ? color.CGColor : [UIColor whiteColor].CGColor;
    image.layer.borderWidth = 3;
    image.contentMode = UIViewContentModeScaleAspectFill;
    [shadowView addSubview:image];
    
    [view addSubview:shadowView];
}

+ (void)setRoundCorner:(UIView*)view corner:(UIRectCorner)corner radius:(float)radius
{
    if (!corner) corner = UIRectCornerTopLeft|UIRectCornerTopRight;
    if (!radius) radius = 8;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:view.bounds byRoundingCorners:corner cornerRadii:CGSizeMake(radius, radius)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.frame = view.bounds;
    mask.path = path.CGPath;
    view.layer.mask = mask;
    view.layer.masksToBounds = YES;
}

+ (void)addImageAtCorner:(UIView*)view image:(UIImageView*)image corner:(UIRectCorner)corner
{
    [view addSubview:image];
    if (corner == UIRectCornerTopRight) {
        image.layer.anchorPoint = CGPointMake(0, 1);
        image.frame = CGRectMake(view.frame.size.width - image.frame.size.width, 0.0, image.frame.size.width, image.frame.size.height);
    } else
    if (corner == UIRectCornerTopLeft) {
        image.layer.anchorPoint = CGPointMake(0, 0);
        image.frame = CGRectMake(0, 0, image.frame.size.width, image.frame.size.height);
    } else
    if (corner == UIRectCornerBottomLeft) {
        image.layer.anchorPoint = CGPointMake(1, 0);
        image.frame = CGRectMake(0, view.frame.size.height - image.frame.size.height, image.frame.size.width, image.frame.size.height);
    } else
    if (corner == UIRectCornerBottomRight) {
        image.layer.anchorPoint = CGPointMake(1, 1);
        image.frame = CGRectMake(view.frame.size.width - image.frame.size.width, view.frame.size.height - image.frame.size.height, image.frame.size.width, image.frame.size.height);
    }
}

+ (UIImageView*)makeImageWithBadge:(CGRect)frame icon:(NSString*)icon color:(UIColor*)color value:(int)value
{
    UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:icon]];
    if (frame.size.width && frame.size.height) {
        image.contentMode = UIViewContentModeScaleAspectFit;
        image.frame = frame;
    } else {
        image.frame = CGRectMake(frame.origin.x, frame.origin.y, image.frame.size.width, image.frame.size.height);
    }
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(3, 3, image.frame.size.width-6, image.frame.size.height-6)];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.textColor = color ? color : [UIColor darkGrayColor];
    label.text = [NSString stringWithFormat:@"%d", value];
    [image addSubview:label];
    return image;
}

+ (UIImage*)makeImageWithTint:(UIImage*)image color:(UIColor*)color
{
    CGRect drawRect = CGRectMake(0, 0, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, drawRect, image.CGImage);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextSetBlendMode(context, kCGBlendModeSourceAtop);
    CGContextFillRect(context, drawRect);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tintedImage;
}

+ (UIColor *)makeColor:(UIColor*)color h:(double)h s:(double)s b:(double)b a:(double)a
{
    CGFloat w1, h1, s1, b1, a1;
    if ([color getHue:&h1 saturation:&s1 brightness:&b1 alpha:&a1]) {
        b1 += b - 1;
        b1 = MAX(MIN(b1, 1.0), 0.0);
        s1 += s - 1;
        s1 = MAX(MIN(s1, 1.0), 0.0);
        h1 += h - 1;
        h1 = MAX(MIN(h1, 1.0), 0.0);
        a1 += a - 1;
        a1 = MAX(MIN(a1, 1.0), 0.0);
        return [UIColor colorWithHue:h1 saturation:s1 brightness:b1 alpha:a1];
    }
    if ([color getWhite:&w1 alpha:&a1]) {
        w1 += (b - 1.0);
        w1 = MAX(MIN(b, 1.0), 0.0);
        a1 += a - 1;
        a1 = MAX(MIN(a1, 1.0), 0.0);
        return [UIColor colorWithWhite:w1 alpha:a1];
    }
    return color;
}

+(UIButton*)makeCustomButton
{
    UIButton *sys = [UIButton buttonWithType:UIButtonTypeSystem];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.imageView.contentMode = UIViewContentModeCenter;
    btn.showsTouchWhenHighlighted = YES;
    btn.adjustsImageWhenHighlighted = YES;
    btn.titleLabel.font = sys.titleLabel.font;
    [btn setTitleColor:sys.tintColor forState:UIControlStateNormal];
    [btn setTitleColor:[self makeColor:sys.tintColor h:1 s:1 b:1.5 a:0.5] forState:UIControlStateHighlighted];
    [btn setTitleColor:[self makeColor:sys.tintColor h:1 s:1 b:1.5 a:0.5] forState:UIControlStateSelected];
    [btn setTitleColor:[self makeColor:sys.tintColor h:1 s:1 b:0.5 a:1] forState:UIControlStateDisabled];
    return btn;
}

+ (void)shakeView:(UIView*)view
{
    CAKeyframeAnimation * anim = [ CAKeyframeAnimation animationWithKeyPath:@"transform" ] ;
    anim.values = @[ [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-5.0f, 0.0f, 0.0f) ],
                     [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(5.0f, 0.0f, 0.0f) ] ] ;
    anim.autoreverses = YES ;
    anim.repeatCount = 2.0f ;
    anim.duration = 0.07f ;
    [view.layer addAnimation:anim forKey:nil];
}

+ (void)jiggleView:(UIView*)view
{
    float angle = 1.0 * (1.0f + ((rand() / (float)RAND_MAX) - 0.5f) * 0.1f);
    float rotate = angle / 180. * M_PI;
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    animation.duration = 0.1;
    animation.additive = YES;
    animation.autoreverses = YES;
    animation.repeatCount = FLT_MAX;
    animation.fromValue = @(-rotate);
    animation.toValue = @(rotate);
    animation.timeOffset = (rand() / (float)RAND_MAX) * 0.1;
    [view.layer addAnimation:animation forKey:@"jiggle"];
}

#pragma mark UIImage manipulations

+ (UIImage*)scaleToFill:(UIImage*)image size:(CGSize)size
{
    size_t width = (size_t)(size.width * image.scale);
    size_t height = (size_t)(size.height * image.scale);
    if (image.imageOrientation == UIImageOrientationLeft || image.imageOrientation == UIImageOrientationLeftMirrored || image.imageOrientation == UIImageOrientationRight || image.imageOrientation == UIImageOrientationRightMirrored) {
        size_t temp = width;
        width = height;
        height = temp;
    }
    static CGColorSpaceRef _colorSpace = NULL;
    if (!_colorSpace) _colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image.CGImage);
    BOOL hasAlpha = (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast || alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast);
    CGImageAlphaInfo alphaInfo = (hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, _colorSpace, kCGBitmapByteOrderDefault | alphaInfo);
    
    CGContextSetShouldAntialias(context, true);
    CGContextSetAllowsAntialiasing(context, true);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    
    UIGraphicsPushContext(context);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), image.CGImage);
    UIGraphicsPopContext();
    
    CGImageRef scaledRef = CGBitmapContextCreateImage(context);
    UIImage* scaled = [UIImage imageWithCGImage:scaledRef scale:image.scale orientation:image.imageOrientation];
    
    CGImageRelease(scaledRef);
    CGContextRelease(context);
    
    return scaled;
}

+ (UIImage*)scaleToFit:(UIImage*)image size:(CGSize)size
{
    size_t width, height;
    if (image.size.width > image.size.height) {
        width = (size_t)size.width;
        height = (size_t)(image.size.height * size.width / image.size.width);
    } else {
        height = (size_t)size.height;
        width = (size_t)(image.size.width * size.height / image.size.height);
    }
    if (width > size.width) {
        width = (size_t)size.width;
        height = (size_t)(image.size.height * size.width / image.size.width);
    }
    if (height > size.height) {
        height = (size_t)size.height;
        width = (size_t)(image.size.width * size.height / image.size.height);
    }
    return [BKui scaleToFill:image size:CGSizeMake(width, height)];
}

+ (UIImage*)scaleToSize:(UIImage*)image size:(CGSize)size
{
    size_t width, height;
    CGFloat widthRatio = size.width / image.size.width;
    CGFloat heightRatio = size.height / image.size.height;
    if (heightRatio > widthRatio) {
        height = (size_t)size.height;
        width = (size_t)(image.size.width * size.height / image.size.height);
    } else {
        width = (size_t)size.width;
        height = (size_t)(image.size.height * size.width / image.size.width);
    }
    return [BKui scaleToFill:image size:CGSizeMake(width, height)];
}

+ (UIImage *)cropImage:(UIImage*)image frame:(CGRect)frame
{
    frame = CGRectMake(frame.origin.x * image.scale, frame.origin.y * image.scale, frame.size.width * image.scale, frame.size.height * image.scale);
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, frame);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return newImage;
}

+ (UIImage *)orientImage:(UIImage *)image
{
    if (image.imageOrientation == UIImageOrientationUp) return image;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:(CGRect){0, 0, image.size}];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)captureImage:(UIView *)view
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextFillRect(ctx, (CGRect){CGPointZero, size});
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

# pragma mark - CAAnimation methods

- (void)animationDidStart:(CAAnimation *)animation
{
    SuccessBlock block = [animation valueForKey:@"startBlock"];
    if (block) block(animation);
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag
{
    SuccessBlock block = [animation valueForKey:@"stopBlock"];
    if (block) block(animation);
}

#pragma mark UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    SuccessBlock block = objc_getAssociatedObject(textView, @"urlBlock");
    if (block) {
        block(URL.absoluteString);
        return NO;
    }
    return YES;
}

#pragma mark - UIActionSheet methods

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *action = [actionSheet buttonTitleAtIndex:buttonIndex];
    ActionBlock block = objc_getAssociatedObject(actionSheet, @"actionBlock");
    if (block) block(actionSheet, action);
}

# pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)index
{
    NSString *title = [alertView buttonTitleAtIndex:index];
    AlertBlock block = objc_getAssociatedObject(alertView, @"alertBlock");
    if (block) block(alertView, title);
}

@end;

#ifdef BKUI_FONT

// Replacing default system font
@implementation UIFont (CustomSystemFont)

+(void)load
{
    SEL original = @selector(systemFontOfSize:);
    SEL modified = @selector(regularFontWithSize:);
    SEL originalBold = @selector(boldSystemFontOfSize:);
    SEL modifiedBold = @selector(boldFontWithSize:);
    
    Method originalMethod = class_getClassMethod(self, original);
    Method modifiedMethod = class_getClassMethod(self, modified);
    method_exchangeImplementations(originalMethod, modifiedMethod);
    
    Method originalBoldMethod = class_getClassMethod(self, originalBold);
    Method modifiedBoldMethod = class_getClassMethod(self, modifiedBold);
    method_exchangeImplementations(originalBoldMethod, modifiedBoldMethod);
}

+(UIFont *)regularFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:BKUI_FONT size:size];
}

+(UIFont *)boldFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:BKUI_FONT size:size];
}
@end;

#endif
