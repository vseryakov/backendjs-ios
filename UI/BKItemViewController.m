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
    
    self.avatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    [BKui setImageBorder:self.avatar color:nil radius:0 border:1];
    self.avatar.hidden = YES;
    [self.scroll addSubview:self.avatar];
    
    self.source = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
    self.source.contentMode = UIViewContentModeScaleAspectFit;
    self.source.centerX = self.avatar.centerX;
    self.source.hidden = YES;
    [self.scroll addSubview:self.source];
    
    self.header = [BKui makeLabel:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor blackColor] font:[UIFont boldSystemFontOfSize:16]];
    self.header.numberOfLines = 0;
    [self.scroll addSubview:self.header];
    
    self.line1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.line1.backgroundColor = [BKui makeColor:@"#EEEEEE"];
    self.line1.hidden = YES;
    [self.scroll addSubview:self.line1];
    
    self.line2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.line2.backgroundColor = [BKui makeColor:@"#EEEEEE"];
    self.line2.hidden = YES;
    [self.scroll addSubview:self.line2];

    SuccessBlock urlBlock = ^(id url) { [BKWebViewController showURL:url completionHandler:nil]; };
    
    self.msg = [BKui makeTextView:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor darkTextColor] font:[UIFont systemFontOfSize:17]];
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
    
    self.text = [BKui makeTextView:CGRectMake(0, 0, 0, 0) text:@"" color:[UIColor darkTextColor] font:[UIFont systemFontOfSize:16]];
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

- (void)setFrame:(CGRect)frame;
{
    [super setFrame:frame];
    self.scroll.frame = self.bounds;
}

- (void)clean
{
    for (UIView *view in self.scroll.subviews) {
        if (view != self.avatar &&
            view != self.source &&
            view != self.header &&
            view != self.msg &&
            view != self.icon &&
            view != self.title &&
            view != self.line1 &&
            view != self.line2 &&
            view != self.text) {
            [view removeFromSuperview];
        }
    }
    self.source.image = nil;
    self.icon.image = nil;
    self.avatar.image = nil;
    self.header.text = @"";
    self.msg.text =  @"";
    self.title.text = @"";
    self.text.text = @"";
}

- (void)update:(NSDictionary*)params
{
    int y = 5, x = 5;
    
    if (params[@"avatar"] || params[@"avatar_id"]) {
        self.avatar.hidden = NO;
        self.avatar.x = x;
        self.avatar.y = y;
        self.avatar.image = [UIImage imageNamed:[params str:@[@"avatar_none"] dflt:@"avatar"]];

        if (params[@"avatar"]) {
            if ([params[@"avatar"] rangeOfString:@"/"].location == NSNotFound) {
                UIImage *img = [UIImage imageNamed:params[@"avatar"]];
                if (img) self.avatar.image = img;
            } else {
                [BKjs getIcon:params[@"avatar"] options:BKCacheModeCache success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
            }
        } else {
            // Default account icon using generic interface in case all icons are public
            [BKjs getIconByPrefix:@{ @"id": [params str:@"avatar_id"], @"type": [params str:@[@"avatar_type"] dflt:@"0"] } options:BKCacheModeCache success:^(UIImage *image, NSString *url) { self.avatar.image = image; } failure:nil];
        }
        x = self.avatar.right + 5;
    } else {
        self.avatar.hidden = YES;
    }
    
    if (params[@"source"]) {
        self.source.hidden = NO;
        self.source.frame = CGRectMake(0, 0, 13, 13);
        self.source.center = CGPointMake(21, self.avatar.bottom + 13);
        if ([params[@"source"] rangeOfString:@"/"].location == NSNotFound) {
            self.source.image = [UIImage imageNamed:params[@"source"]];
        } else {
            [BKjs getImage:params[@"source"] options:BKCacheModeCache success:^(UIImage *image, NSString *url) { self.source.image = image; } failure:nil];
        }
    } else {
        self.source.hidden = YES;
    }

    if (params[@"header"]) {
        self.header.hidden = NO;
        self.header.frame = CGRectMake(x, y + 5, self.width - x - 5, 0);
        self.header.text = params[@"header"];
        [self.header sizeToFit];
        y = self.header.bottom + 5;
    } else
    if (params[@"alias"]) {
        self.header.hidden = NO;
        self.header.frame = CGRectMake(x, y + 5, self.width - x - 5, 0);
        NSString *mtime = params[@"mtime"] ? [BKjs strftime:[params num:@"mtime"]/1000 format:nil] : @"";
        NSString *str = [NSString stringWithFormat:@"%@  %@", params[@"alias"], mtime];
        NSMutableAttributedString* astr = [[NSMutableAttributedString alloc] initWithString:str];
        [astr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:13] range:[str rangeOfString:params[@"alias"]]];
        [astr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:12] range:[str rangeOfString:mtime]];
        [self.header setAttributedText:astr];
        [self.header sizeToFit];
        y = self.header.bottom + 5;
        
    } else {
        self.header.hidden = YES;
    }
    
    self.line1.frame = CGRectMake(x, self.header.bottom + 1, self.width - x - 5, 1);
    self.line1.hidden = self.header.hidden;

    if (params[@"msg"]) {
        self.msg.hidden = NO;
        self.msg.backgroundColor = [UIColor clearColor];
        self.msg.attributedText = [[NSAttributedString alloc] initWithString:params[@"msg"]
                                                                  attributes:@{ NSFontAttributeName: self.msg.font }];
        self.msg.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.msg sizeToFit];
        y = self.msg.bottom + 5;
    } else {
        self.msg.hidden = YES;
    }
    
    if (params[@"image"] && [params[@"image"] isKindOfClass:[UIImage class]]) {
        UIImage *image = params[@"image"];
        self.icon.contentMode = image.size.width < self.icon.width && image.size.height < self.icon.height ? UIViewContentModeCenter : UIViewContentModeScaleAspectFit;
        self.icon.hidden = NO;
        self.icon.frame = CGRectMake(x, y, self.width - x - 5, self.width/2);
        self.icon.image = image;
        y = self.icon.bottom + 5;
    } else
    if (params[@"icon"]) {
        self.icon.hidden = NO;
        self.icon.frame = CGRectMake(x, y, self.width - x - 5, self.width/2);
        [BKjs getIcon:params[@"icon"] options:BKCacheModeCache|(params[@"icon_auth"] ? 0 : BKNoSignature) success:^(UIImage *image, NSString *url) {
            self.icon.contentMode = image.size.width < self.icon.width && image.size.height < self.icon.height ? UIViewContentModeCenter : UIViewContentModeScaleAspectFit;
            self.icon.image = image;
        } failure:nil];
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

    self.line2.frame = CGRectMake(x, self.title.bottom + 1, self.width - x - 5, 1);
    self.line2.hidden = self.title.hidden;

    if (params[@"text"]) {
        self.text.hidden = NO;
        self.text.backgroundColor = [UIColor clearColor];
        self.text.attributedText = [[NSAttributedString alloc] initWithString:params[@"text"]
                                                                   attributes:@{ NSFontAttributeName: self.text.font }];
        self.text.frame = CGRectMake(x, y, self.width - x - 5, 0);
        [self.text sizeToFit];
        y = self.text.bottom + 5;
    } else {
        self.text.hidden = YES;
    }

    self.scroll.contentSize = CGSizeMake(self.width, y + 10);
}

@end

@implementation BKItemPopupView

- (instancetype)initWithFrame:(CGRect)frame params:(NSDictionary*)params
{
    self = [super initWithFrame:frame];
    self.itemView = [[BKItemView alloc] initWithFrame:CGRectMake(0, 44, self.width, self.height - 44) params:params];
    [self addSubview:self.itemView];
    
    return self;
}

@end

@implementation BKItemViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.itemView = [[BKItemView alloc] initWithFrame:CGRectMake(0, self.toolbarHeight + self.barHeight, self.view.width, self.view.height - self.toolbarHeight - self.barHeight) params:nil];
    [self.view addSubview:self.itemView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.itemView update:self.params];
}

@end
