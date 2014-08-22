//
//  BKui
//
//  Created by Vlad Seryakov on 7/04/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKui.h"
#import <sys/sysctl.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

static BKui *_BKui;
static NSMutableDictionary *_style;
static NSMutableDictionary *_controllers;
static UIActivityIndicatorView *_activity;

@interface BKui () <UIActionSheetDelegate,UIAlertViewDelegate,UITextViewDelegate>
@end

@implementation BKui

+ (instancetype)get
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{
        _BKui = [BKui new];
        _controllers = [@{} mutableCopy];
        _style = [@{} mutableCopy];
        
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

+ (NSMutableDictionary*)style
{
    return _style;
}

+ (NSMutableDictionary*)controllers
{
    return _controllers;
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

+ (UIViewController*)showViewController:(UIViewController*)owner name:(NSString*)name params:(NSDictionary*)params
{
    Logger(@"name: %@, params: %@", name, params ? params : @"");

    if (!name) return nil;
    NSString *title = name;
    NSString *mode = nil;
    
    // Split the name into name and mode
    NSArray *q = [title componentsSeparatedByString:@"@"];
    if (q.count > 1) {
        title = q[0];
        mode = q[1];
    }
    UIViewController *controller = self.controllers[title];
    if (!controller) controller = [[self get] getViewController:title];
    if (!controller) {
        if ([[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"]) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:[NSString stringWithFormat:@"MainStoryboard_%@", BKjs.iOSPlatform] bundle:nil];
            if (storyboard) controller = [storyboard instantiateViewControllerWithIdentifier:title];
        }
    }
    return [self showViewController:owner controller:controller name:title mode:mode params:params];
}

+ (UIViewController*)showViewController:(UIViewController*)owner controller:(UIViewController*)controller name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params
{
    Debug(@"name: %@, mode: %@, params: %@", name, mode, params ? params : @"");
    
    if (!controller) {
        Logger(@"Error: name: %@, mode: %@, no controller provided", name, mode);
        return nil;
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
    return controller;
}

+ (void)showAlert:(NSString *)title text:(NSString *)text delegate:(id)delegate cancelButtonText:(NSString*)cancel otherButtonTitles:(NSArray*)otherButtonTitles tag:(int)tag
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title message:text delegate:delegate cancelButtonTitle:cancel otherButtonTitles:nil];
    for (NSString *buttonTitle in otherButtonTitles) [alert addButtonWithTitle:buttonTitle];
    alert.tag = tag;
    [alert show];
}

+ (void)showAlert:(NSString*)title text:(NSString*)text finish:(AlertBlock)finish
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:@"OK" otherButtonTitles:nil];
    if (finish) objc_setAssociatedObject(alertView, @"alertBlock", finish, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (void)showConfirm:(NSString*)title text:(NSString*)text buttons:(NSArray*)buttons finish:(AlertBlock)finish
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:nil otherButtonTitles:nil];
    for (NSString *key in buttons) [alertView addButtonWithTitle:key];
    if (finish) objc_setAssociatedObject(alertView, @"alertBlock", finish, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (void)showConfirm:(NSString*)title text:(NSString*)text ok:(NSString*)ok cancel:(NSString*)cancel finish:(AlertBlock)finish
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:text delegate:[self get] cancelButtonTitle:cancel ? cancel : @"Cancel" otherButtonTitles:ok ? ok : @"OK",nil];
    if (finish) objc_setAssociatedObject(alertView, @"alertBlock", finish, OBJC_ASSOCIATION_RETAIN);
    [alertView show];
}

+ (UIActionSheet*)makeAction:(NSString *)title actions:(NSArray*)actions finish:(ActionBlock)finish
{
    UIActionSheet *action = [[UIActionSheet alloc] initWithTitle:title delegate:[self get] cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
    for (NSString *button in actions) [action addButtonWithTitle:button];
    action.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    if (finish) objc_setAssociatedObject(action, @"actionBlock", finish, OBJC_ASSOCIATION_RETAIN);
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
    [str addAttribute:NSFontAttributeName value:label.font range:NSMakeRange(0, str.length)];
    for (NSString *link in links) {
        NSRange range = [str.string rangeOfString:link];
        if (range.location == NSNotFound) continue;
        [str addAttribute:NSLinkAttributeName value:link range:range];
        [str addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    }
    [label setAttributedText:str];
    if (handler) objc_setAssociatedObject(label, @"urlBlock", handler, OBJC_ASSOCIATION_RETAIN);
    if (!label.delegate) label.delegate = [self get];
}

+ (UIImageView*)makeImageAvatar:(UIView*)view frame:(CGRect)frame eclipse:(UIImage*)eclipse
{
    if (eclipse) {
        UIImageView *avatar = [[UIImageView alloc] initWithImage:eclipse];
        avatar.frame = frame;
        [view addSubview:avatar];
    }
    UIImageView *img = [[UIImageView alloc] initWithFrame:CGRectInset(frame, 3, 3)];
    img.contentMode = UIViewContentModeScaleAspectFill;
    img.layer.cornerRadius = img.width/2;
    img.layer.masksToBounds = YES;
    [view addSubview:img];
    return img;
}

+ (void)setViewShadow:(UIView*)view color:(UIColor*)color offset:(CGSize)offset opacity:(float)opacity radius:(float)radius
{
    view.layer.masksToBounds = NO;
    view.layer.shadowColor = color ? color.CGColor : [UIColor blackColor].CGColor;
    view.layer.shadowOffset = offset;
    view.layer.shadowRadius = radius < 0 ? 3 : radius;
    view.layer.shadowOpacity = opacity < 0 ? 0.5 : opacity;
    view.layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
}

+ (void)setViewBorder:(UIView*)view color:(UIColor*)color width:(float)width radius:(float)radius
{
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = radius;
    view.layer.borderColor = color ? color.CGColor : [UIColor lightGrayColor].CGColor;
    view.layer.borderWidth = width < 0 ? 1 : width;
}

+ (void)setPlaceholder:(UITextView*)view text:(NSString*)text
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, view.bounds.size.width, 0)];
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor lightGrayColor];
    label.text = text;
    label.hidden = YES;
    label.tag = 19991;
    [view addSubview:label];
    [label sizeToFit];
    if (!view.text.length) label.hidden = NO;
}

+ (void)checkPlaceholder:(UITextView*)view
{
    UILabel *label = (UILabel*)[view viewWithTag:19991];
    if(!label) return;
    label.hidden = view.text.length > 0;
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

+ (UILabel*)makeBadge:(int)value font:(UIFont*)font color:(UIColor*)color bgColor:(UIColor*)bg borderColor:(UIColor*)border
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = color ? color : [UIColor whiteColor];
    label.font = font ? font : [UIFont systemFontOfSize:12];
    label.text = [NSString stringWithFormat:@"%d", value];
    [label sizeToFit];
    label.width += 3;
    label.height += 3;
    if (label.width < label.height) label.width = label.height;
    label.layer.borderWidth = 1;
    label.layer.borderColor = border ? border.CGColor : [UIColor clearColor].CGColor;
    label.backgroundColor = [UIColor clearColor];
    label.layer.backgroundColor = bg ? bg.CGColor : [UIColor colorWithRed:142.0f/255 green:156.0f/255 blue:183.0f/255 alpha:1.0].CGColor;
    label.layer.cornerRadius = label.height / 2;
    return label;
}

+ (UILabel*)makeBadge:(UIView*)view style:(NSDictionary*)style
{
    if (!style || [style num:@"count"] <= 0) {
        UIView *badge = [view viewWithTag:515151];
        [badge removeFromSuperview];
        return nil;
    }
    UILabel *badge = [BKui makeBadge:[style num:@"count"]
                                font:style[@"font"]
                               color:style[@"textColor"]
                             bgColor:style[@"backgroundColor"]
                         borderColor:style[@"borderColor"]];
    [view addSubview:badge];
    badge.tag = 515151;
    badge.centerX = view.width - badge.width/2;
    badge.centerY = badge.height/2;
    if (style[@"gloss"]) [self makeGloss:badge];
    if (style[@"x"]) badge.x = [style num:@"x"];
    if (style[@"y"]) badge.y = [style num:@"y"];
    return badge;
}

+ (void)makeGloss:(UIView*)view
{
    CAGradientLayer *gloss = [[CAGradientLayer alloc] init];
    gloss.frame = view.layer.bounds;
    gloss.cornerRadius = view.layer.cornerRadius;
    CGColorRef white = [UIColor whiteColor].CGColor;
    CGColorRef clear = CGColorCreateCopyWithAlpha(white, 0);
    gloss.colors = [NSArray arrayWithObjects:(__bridge id)white, (__bridge id)clear, nil];
    CFRelease(clear);
    gloss.startPoint = CGPointMake(0.5, -0.15);
    gloss.endPoint = CGPointMake(0.5, 0.65);
    [view.layer addSublayer:gloss];
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

+(UIButton*)makeCustomButton:(NSString*)title image:(UIImage*)image
{
    UIButton *sys = [UIButton buttonWithType:UIButtonTypeSystem];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.imageView.contentMode = UIViewContentModeCenter;
    btn.showsTouchWhenHighlighted = YES;
    btn.adjustsImageWhenHighlighted = YES;
    btn.titleLabel.font = [UIFont systemFontOfSize:17];
    if (image) {
        [btn setImage:image forState:UIControlStateNormal];
        [btn setImage:[BKui makeImageWithTint:image color:[btn tintColor]] forState:UIControlStateHighlighted];
    }
    if (title) [btn setTitle:title forState:UIControlStateNormal];
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

+ (void)getContacts:(SuccessBlock)finish
{
    CFErrorRef error = nil;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &error);
    if (!book) {
        finish(@[]);
        return;
    }
    
    ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
        NSMutableArray *items = [@[] mutableCopy];
        if (granted) {
            NSArray *contacts = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(book));
            for (int i = 0; i < contacts.count; i++) {
                ABRecordRef person = (__bridge ABRecordRef) [contacts objectAtIndex:i];
                
                NSString *str = CFBridgingRelease(ABRecordCopyCompositeName(person));
                if (str == nil) continue;
                
                NSMutableDictionary *item = [@{} mutableCopy];
                item[@"alias"] = str;

                item[@"id"] = @(ABRecordGetRecordID(person));
                
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonNicknameProperty));
                if (str) item[@"nickname"] = str;
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonFirstNameProperty));
                if (str) item[@"first_name"] = str;
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonLastNameProperty));
                if (str) item[@"last_name"] = str;
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonJobTitleProperty));
                if (str) item[@"job_title"] = str;
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonOrganizationProperty));
                if (str) item[@"company"] = str;
                str = CFBridgingRelease(ABRecordCopyValue(person, kABPersonNoteProperty));
                if (str) item[@"note"] = str;
                NSDate *date = CFBridgingRelease(ABRecordCopyValue(person, kABPersonBirthdayProperty));
                if (str) item[@"birthday"] = @([date timeIntervalSince1970]);
                date = CFBridgingRelease(ABRecordCopyValue(person, kABPersonModificationDateProperty));
                if (str) item[@"mtime"] = @([date timeIntervalSince1970]);

                if (ABPersonHasImageData(person)) {
                    UIImage *icon = [UIImage imageWithData:(NSData *)CFBridgingRelease(ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail))];
                    if (icon) item[@"icon"] = icon;
                }
                
                ABMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
                if (phones && ABMultiValueGetCount(phones) > 0) {
                    item[@"phone"] = [@{} mutableCopy];
                    for (CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
                        NSString *val = CFBridgingRelease(ABMultiValueCopyValueAtIndex(phones, i));
                        if (!val) continue;
                        str = @"phone";
                        CFStringRef label = ABMultiValueCopyLabelAtIndex(phones, i);
                        if (label) {
                            str = CFBridgingRelease(ABAddressBookCopyLocalizedLabel(label));
                            CFRelease(label);
                        }
                        for (int j = 1; ; j++) {
                            if (!item[@"phone"][str]) break;
                            str = [NSString stringWithFormat:@"%@%d", str, j];
                        }
                        item[@"phone"][str] = val;
                    }
                }
                if (phones) CFRelease(phones);
                
                ABMultiValueRef emails = ABRecordCopyValue(person, kABPersonEmailProperty);
                if (emails && ABMultiValueGetCount(emails) > 0) {
                    item[@"email"] = [@{} mutableCopy];
                    for (CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
                        NSString *val = CFBridgingRelease(ABMultiValueCopyValueAtIndex(emails, i));
                        if (!val) continue;
                        str = @"email";
                        CFStringRef label = ABMultiValueCopyLabelAtIndex(emails, i);
                        if (label) {
                            str = CFBridgingRelease(ABAddressBookCopyLocalizedLabel(label));
                            CFRelease(label);
                        }
                        for (int j = 1; ; j++) {
                            if (!item[@"email"][str]) break;
                            str = [NSString stringWithFormat:@"%@%d", str, j];
                        }
                        item[@"email"][str] = val;
                    }
                }
                if (emails) CFRelease(emails);
                
                ABMultiValueRef addrs = ABRecordCopyValue(person, kABPersonAddressProperty);
                if (addrs && ABMultiValueGetCount(addrs) > 0) {
                    item[@"address"] = [@{} mutableCopy];
                    for (CFIndex i = 0; i < ABMultiValueGetCount(addrs); i++) {
                        NSDictionary *addr = CFBridgingRelease(ABMultiValueCopyValueAtIndex(addrs, i));
                        if (!addr) continue;
                        str = @"address";
                        CFStringRef label = ABMultiValueCopyLabelAtIndex(addrs, i);
                        if (label) {
                            str = CFBridgingRelease(ABAddressBookCopyLocalizedLabel(label));
                            CFRelease(label);
                        }
                        NSString *val = [NSString stringWithFormat:@"%@ %@ %@ %@ %@",
                                         [addr str:CFBridgingRelease(kABPersonAddressStreetKey)],
                                         [addr str:CFBridgingRelease(kABPersonAddressCityKey)],
                                         [addr str:CFBridgingRelease(kABPersonAddressStateKey)],
                                         [addr str:CFBridgingRelease(kABPersonAddressZIPKey)],
                                         [addr str:CFBridgingRelease(kABPersonAddressCountryKey)]];
                        for (int j = 1; ; j++) {
                            if (!item[@"address"][str]) break;
                            str = [NSString stringWithFormat:@"%@%d", str, j];
                        }
                        item[@"address"][str] = val;
                    }
                }
                if (addrs) CFRelease(addrs);
               
                [items addObject:item];
            }
            CFRelease(book);
            [items sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"alias" ascending:YES]]];
        }
        finish(items);
    });
}

#pragma mark UI styles

+ (void)setStyle:(UIView*)view style:(NSDictionary*)style
{
    if (!view || !style) return;
    
    NSArray *keys = [[style allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *k in keys) {
        NSString *key = k;
        NSRange loc = [key rangeOfString:@"@"];
        if (loc.location != NSNotFound) key = [key substringFromIndex:loc.location + 1];
        id val = style[key];
        double num = [style num:key];
        if ([key isEqual:@"hidden"]) view.hidden = YES; else
        if ([key isEqual:@"visible"]) view.hidden = NO; else
        if ([key isEqual:@"frame"]) view.frame = [self toCGRect:style name:@"frame"]; else
        if ([key isEqual:@"x"]) view.x = num; else
        if ([key isEqual:@"y"]) view.y = num; else
        if ([key isEqual:@"width"]) view.width = num; else
        if ([key isEqual:@"height"]) view.height = num; else
        if ([key isEqual:@"centerX"]) view.centerX = num; else
        if ([key isEqual:@"centerY"]) view.centerY = num; else
        if ([key isEqual:@"frameInset"]) view.frame = CGRectInset(view.frame, [val num:@"x"], [val num:@"y"]);
        if ([key isEqual:@"backgroundColor"] && [val isKindOfClass:[UIColor class]]) view.backgroundColor = val; else
        if ([key isEqual:@"tintColor"] && [val isKindOfClass:[UIColor class]]) view.backgroundColor = val; else
        if ([key isEqual:@"alpha"]) view.alpha = num; else
        if ([key isEqual:@"tag"]) view.tag = num; else
        if ([key isEqual:@"gloss"]) [BKui makeGloss:view]; else
        if ([key isEqual:@"contentMode"]) view.contentMode = num; else
        if ([key isEqual:@"border"] && [val isKindOfClass:[NSDictionary class]]) [BKui setViewBorder:view color:val[@"color"] width:[val num:@"width"] radius:[val num:@"radius"]]; else
        if ([key isEqual:@"shadow"] && [val isKindOfClass:[NSDictionary class]]) [BKui setViewShadow:view color:val[@"color"] offset:CGSizeMake([val num:@"width"], [val num:@"height"]) opacity:[val num:@"opacity"] radius:[val num:@"radius"]]; else
        if ([key isEqual:@"masksToBounds"]) view.layer.masksToBounds = num; else
        if ([key isEqual:@"cornerRadius"]) view.layer.cornerRadius = num; else
        if ([key isEqual:@"corner-radius-eclipse"]) view.layer.cornerRadius = view.width/2; else
        if ([key isEqual:@"borderColor"] && [val isKindOfClass:[UIColor class]]) view.layer.borderColor = [val CGColor]; else
        if ([key isEqual:@"borderWidth"]) view.layer.borderWidth = num; else
        if ([key isEqual:@"background-image"]) {
            UIImageView *bg = [[UIImageView alloc] initWithImage:val];
            bg.frame = view.bounds;
            [view addSubview:bg];
            [view sendSubviewToBack:bg];
        } else
        if ([key isEqual:@"block"]) {
            SuccessBlock block = val;
            block(view);
        } else
        if ([key isEqual:@"badge"] && [val isKindOfClass:[NSDictionary class]]) {
            [self makeBadge:view style:val];
        }
        
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel*)view;
            if ([key isEqual:@"text"]) label.text = val; else
            if ([key isEqual:@"numberOfLines"]) label.numberOfLines = num; else
            if ([key isEqual:@"lineBreakMode"]) label.lineBreakMode = num; else
            if ([key isEqual:@"baselineAdjustment"]) label.baselineAdjustment = num; else
            if ([key isEqual:@"textAlignment"]) label.textAlignment = num; else
            if ([key isEqual:@"textColor"] && [val isKindOfClass:[UIColor class]]) label.textColor = val; else
            if ([key isEqual:@"font"] && [val isKindOfClass:[UIFont class]]) label.font = val;
        }
        
        if ([view isKindOfClass:[UITextField class]]) {
            UITextField *text = (UITextField*)view;
            if ([key isEqual:@"text"]) text.text = val; else
            if ([key isEqual:@"font"] && [val isKindOfClass:[UIFont class]]) text.font = val; else
            if ([key isEqual:@"textColor"] && [val isKindOfClass:[UIColor class]]) text.textColor = val; else
            if ([key isEqual:@"textAlignment"]) text.textAlignment = num; else
            if ([key isEqual:@"keyboardType"]) text.keyboardType = num; else
            if ([key isEqual:@"keyboardAppearance"]) text.keyboardAppearance = num; else
            if ([key isEqual:@"autocorrectionType"]) text.autocorrectionType = num; else
            if ([key isEqual:@"autocapitalizationType"]) text.autocapitalizationType = num; else
            if ([key isEqual:@"spellCheckingType"]) text.spellCheckingType = num; else
            if ([key isEqual:@"returnKeyTypen"]) text.returnKeyType = num;
        }

        if ([view isKindOfClass:[UITextView class]]) {
            UITextView *text = (UITextView*)view;
            if ([key isEqual:@"text"]) text.text = val; else
            if ([key isEqual:@"textContainerInset"]) text.textContainerInset = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"font"] && [val isKindOfClass:[UIFont class]]) text.font = val; else
            if ([key isEqual:@"textColor"] && [val isKindOfClass:[UIColor class]]) text.textColor = val; else
            if ([key isEqual:@"textAlignment"]) text.textAlignment = num; else
            if ([key isEqual:@"keyboardType"]) text.keyboardType = num; else
            if ([key isEqual:@"keyboardAppearance"]) text.keyboardAppearance = num; else
            if ([key isEqual:@"autocorrectionType"]) text.autocorrectionType = num; else
            if ([key isEqual:@"autocapitalizationType"]) text.autocapitalizationType = num; else
            if ([key isEqual:@"spellCheckingType"]) text.spellCheckingType = num; else
            if ([key isEqual:@"returnKeyTypen"]) text.returnKeyType = num;
        }

        if ([view isKindOfClass:[UITableView class]]) {
            UITableView *table = (UITableView*)view;
            if ([key isEqual:@"keyboardDismissMode"]) table.keyboardDismissMode = num; else
            if ([key isEqual:@"allowsMultipleSelection"]) table.allowsMultipleSelection = num; else
            if ([key isEqual:@"rowHeight"]) table.rowHeight = num; else
            if ([key isEqual:@"separatorColor"] && [val isKindOfClass:[UIColor class]]) table.separatorColor = val; else
            if ([key isEqual:@"separatorInset"]) table.separatorInset = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"contentInset"]) table.contentInset = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"separatorStyle"]) table.separatorStyle = num; else
            if ([key isEqual:@"tableHeaderView"] && [val isKindOfClass:[UIView class]]) table.tableHeaderView = val; else
            if ([key isEqual:@"tableFooterView"] && [val isKindOfClass:[UIView class]]) table.tableFooterView = val; else
            if ([key isEqual:@"backgroundView"] && [val isKindOfClass:[UIView class]]) table.backgroundView = val;
        }

        if ([view isKindOfClass:[UITableViewCell class]]) {
            UITableViewCell *cell = (UITableViewCell*)view;
            if ([key isEqual:@"title"]) cell.textLabel.text = val; else
            if ([key isEqual:@"subtitle"]) cell.detailTextLabel.text = val; else
            if ([key isEqual:@"textLabel"]) [BKui setStyle:cell.textLabel style:val]; else
            if ([key isEqual:@"detailTextLabel"]) [BKui setStyle:cell.detailTextLabel style:val]; else
            if ([key isEqual:@"imageView"]) [BKui setStyle:cell.imageView style:val]; else
            if ([key isEqual:@"contentView"]) [BKui setStyle:cell.contentView style:val]; else
            if ([key isEqual:@"backgroundView"]) [BKui setStyle:cell.backgroundView style:val]; else
            if ([key isEqual:@"accessoryView"]) [BKui setStyle:cell.accessoryView style:val]; else
            if ([key isEqual:@"indentationLevel"]) cell.indentationLevel = num; else
            if ([key isEqual:@"indentationWidth"]) cell.indentationWidth = num; else
            if ([key isEqual:@"accessoryType"]) cell.accessoryType = num; else
            if ([key isEqual:@"separatorInset"]) cell.separatorInset = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"editingAccessoryType"]) cell.editingAccessoryType = num; else
            if ([key isEqual:@"selectionStyle"]) cell.selectionStyle = num;
        }
        
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton*)view;
            if ([key isEqual:@"disabled"]) button.enabled = NO; else
            if ([key isEqual:@"enabled"]) button.enabled = YES; else
            if ([key isEqual:@"selected"]) button.selected = YES; else
            if ([key isEqual:@"highlighted"]) button.highlighted = YES; else
            if ([key isEqual:@"normal"]) button.selected = button.highlighted = NO; else
            if ([key isEqual:@"contentHorizontalAlignment"]) button.contentHorizontalAlignment = num; else
            if ([key isEqual:@"contentVerticalAlignment"]) button.contentVerticalAlignment = num; else
            if ([key isEqual:@"icon"]) [button setImage:[UIImage imageNamed:val] forState:UIControlStateNormal]; else
            if ([key isEqual:@"icon-tint"]) [button setImage:[BKui makeImageWithTint:[UIImage imageNamed:style[@"icon"]] color:[button tintColor]] forState:UIControlStateNormal]; else
            if ([key isEqual:@"icon-disabled"]) [button setImage:[UIImage imageNamed:val] forState:UIControlStateDisabled]; else
            if ([key isEqual:@"icon-highlighted"]) [button setImage:[UIImage imageNamed:val] forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"icon-highlighted-tint"]) [button setImage:[BKui makeImageWithTint:[UIImage imageNamed:style[@"icon"]] color:[button tintColor]] forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"icon-selected"]) [button setImage:[UIImage imageNamed:val] forState:UIControlStateSelected]; else
            if ([key isEqual:@"icon-selected-highlighted"]) [button setImage:[button imageForState:UIControlStateHighlighted] forState:UIControlStateSelected]; else
            if ([key isEqual:@"image"] && [val isKindOfClass:[UIImage class]]) [button setImage:val forState:UIControlStateNormal]; else
            if ([key isEqual:@"image-disabled"] && [val isKindOfClass:[UIImage class]]) [button setImage:val forState:UIControlStateDisabled]; else
            if ([key isEqual:@"image-highlighted"] && [val isKindOfClass:[UIImage class]]) [button setImage:val forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"image-highlighted-tint"]) [button setImage:[BKui makeImageWithTint:style[@"image"] color:[button tintColor]] forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"image-selected"] && [val isKindOfClass:[UIImage class]]) [button setImage:val forState:UIControlStateSelected]; else
            if ([key isEqual:@"image-selected-highlighted"]) [button setImage:[button imageForState:UIControlStateHighlighted] forState:UIControlStateSelected]; else
            if ([key isEqual:@"title"]) [button setTitle:val forState:UIControlStateNormal]; else
            if ([key isEqual:@"title-highlighted"]) [button setTitle:val forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"title-disabled"]) [button setTitle:val forState:UIControlStateDisabled]; else
            if ([key isEqual:@"color"] && [val isKindOfClass:[UIColor class]]) [button setTitleColor:val forState:UIControlStateNormal]; else
            if ([key isEqual:@"color-tint"]) [button setTitleColor:[button tintColor] forState:UIControlStateNormal]; else
            if ([key isEqual:@"color-highlighted"] && [val isKindOfClass:[UIColor class]]) [button setTitleColor:val forState:UIControlStateHighlighted]; else
            if ([key isEqual:@"color-selected"] && [val isKindOfClass:[UIColor class]]) [button setTitleColor:val forState:UIControlStateSelected]; else
            if ([key isEqual:@"color-selected-highlighted"]) [button setTitleColor:[button titleColorForState:UIControlStateHighlighted] forState:UIControlStateSelected]; else
            if ([key isEqual:@"color-disabled"] && [val isKindOfClass:[UIColor class]]) [button setTitleColor:val forState:UIControlStateDisabled]; else
            if ([key isEqual:@"font"] && [val isKindOfClass:[UIFont class]]) [button.titleLabel setFont:val]; else
            if ([key isEqual:@"contentEdgeInsets"]) button.contentEdgeInsets = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"imageEdgeInsets"]) button.imageEdgeInsets = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"titleEdgeInsets"]) button.titleEdgeInsets = [self toEdgeInsets:style name:key]; else
            if ([key isEqual:@"lineBreakMode"]) button.titleLabel.lineBreakMode = [self toLineBreak:style name:key]; else
            if ([key isEqual:@"imageContentMode"]) button.imageView.contentMode = num; else
            if ([key isEqual:@"fit"]) [button sizeToFit]; else
            if ([key isEqual:@"vertical"]) {
                // Align icon and title vertically in the button, vertical defines top/bottom padding
                CGFloat h = (button.imageView.height + button.titleLabel.height + [style num:key]);
                button.imageEdgeInsets = UIEdgeInsetsMake(- (h - button.imageView.height), 0.0f, 0.0f, - button.titleLabel.width);
                button.titleEdgeInsets = UIEdgeInsetsMake(0.0f, - button.imageView.width, - (h - button.titleLabel.height), 0.0f);
            }
        }
    }
}

+ (int)toLineBreak:(NSDictionary*)style name:(NSString*)name
{
    NSString *str = [style str:name];
    return [str isEqual:@"middle"] ? NSLineBreakByTruncatingMiddle :
           [str isEqual:@"word"] ? NSLineBreakByWordWrapping :
           [str isEqual:@"char"] ? NSLineBreakByCharWrapping :
           [str isEqual:@"clip"] ? NSLineBreakByClipping :
           [str isEqual:@"head"] ? NSLineBreakByTruncatingHead :
           [str isEqual:@"middle"] ? NSLineBreakByTruncatingMiddle : NSLineBreakByTruncatingTail;
}

+ (UIEdgeInsets)toEdgeInsets:(NSDictionary*)style name:(NSString*)name
{
    NSDictionary *item = [style dict:name];
    return UIEdgeInsetsMake([item num:@"top"], [item num:@"left"], [item num:@"bottom"], [item num:@"right"]);
}

+ (CGRect)toCGRect:(NSDictionary*)style name:(NSString*)name
{
    NSDictionary *item = [style dict:name];
    return CGRectMake([item num:@"x"], [item num:@"y"], [item num:@"width"], [item num:@"height"]);
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

