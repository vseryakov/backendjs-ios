//
//  BKMenubarView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKMenubarView.h"

@implementation BKMenubarView

- (instancetype)init:(CGRect)frame items:(NSArray*)items params:(NSDictionary*)params
{
    self = [super initWithFrame:frame];
    self.userInteractionEnabled = YES;

    self.items = [@[] mutableCopy];
    self.buttons = [@{} mutableCopy];
   
    int i = 0, w = self.width / items.count;
    
    for (NSDictionary *obj in items) {
        NSString *name = [obj str:@[@"name", @"icon"] dflt:nil];
        if (!name) continue;
        
        NSMutableDictionary *item = [obj mutableCopy];
        [self.items addObject:item];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i * w, 20, w, 44);
        button.exclusiveTouch = YES;
        [button addTarget:self action:@selector(onButton:) forControlEvents:UIControlEventTouchUpInside];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        if (item[@"x-inset"] || item[@"y-inset"]) {
            button.frame = CGRectInset(button.frame, [item num:@"x-inset"], [item num:@"y-inset"]);
        }
        if (item[@"disabled"]) {
            button.enabled = NO;
        }
        if (item[@"icon"]) {
            UIImage *image = [UIImage imageNamed:item[@"icon"]];
            [button setImage:image forState:UIControlStateNormal];
            if (item[@"icon-disabled"]) [button setImage:[UIImage imageNamed:item[@"icon-disabled"]] forState:UIControlStateDisabled];
            if (item[@"icon-highlighted"]) {
                [button setImage:[UIImage imageNamed:item[@"icon-highlighted"]] forState:UIControlStateHighlighted];
            } else
                if (item[@"icon-highlighted-tint"]) {
                    [button setImage:[BKui makeImageWithTint:image color:[button tintColor]] forState:UIControlStateHighlighted];
                }
            if (item[@"icon-selected"]) {
                [button setImage:[UIImage imageNamed:item[@"icon-selected"]] forState:UIControlStateSelected];
            } else {
                [button setImage:[button imageForState:UIControlStateHighlighted] forState:UIControlStateSelected];
            }
        }
        if (item[@"name"]) {
            [button setTitle:item[@"name"] forState:UIControlStateNormal];
            if (item[@"name-highlighted"]) [button setTitle:item[@"name-highlighted"] forState:UIControlStateHighlighted];
            if (item[@"name-disabled"]) [button setTitle:item[@"name-disabled"] forState:UIControlStateDisabled];
            if (item[@"color"]) [button setTitleColor:item[@"color"] forState:UIControlStateNormal];
            if (item[@"color-highlighted"]) [button setTitleColor:item[@"color-highlighted"] forState:UIControlStateHighlighted];
            if (item[@"color-selected"])
                [button setTitleColor:item[@"color-selected"] forState:UIControlStateSelected];
            else {
                [button setTitleColor:[button titleColorForState:UIControlStateHighlighted] forState:UIControlStateSelected];
            }
            if (item[@"color-disabled"]) [button setTitleColor:item[@"color-disabled"] forState:UIControlStateDisabled];
            if (item[@"font"]) [button.titleLabel setFont:item[@"font"]];
            
            // Align icon and title vertically in the button, vertical defines top/bottom padding
            if (item[@"vertical"] && item[@"icon"]) {
                CGFloat h = (button.imageView.height + button.titleLabel.height + [item num:@"vertical"]);
                button.imageEdgeInsets = UIEdgeInsetsMake(- (h - button.imageView.height), 0.0f, 0.0f, - button.titleLabel.width);
                button.titleEdgeInsets = UIEdgeInsetsMake(0.0f, - button.imageView.width, - (h - button.titleLabel.height), 0.0f);
            }
        }
        [self addSubview:button];
        
        // Configure the menubar
        if (params) {
            if ([name isEqual:params[@"current"]]) {
                button.selected = YES;
            }
            for (NSString *d in params[@"menubar-disabled"]) {
                if ([name isEqual:d]) button.enabled = NO;
            }
        }
        self.buttons[name] = button;
        i++;
    }
    return self;
}

- (void)setButton:(NSString*)name enabled:(BOOL)enabled
{
    UIButton *button = self.buttons[name];
    if (!button) return;
    button.enabled = enabled;
}

- (IBAction)onButton:(id)sender
{
    for (NSString *name in self.buttons) {
        UIButton *button = self.buttons[name];
        if (sender == button) {
            // Find additional parameters for given action
            NSDictionary *action = @{};
            for (NSDictionary *item in self.items) {
                if ([name isEqual:item[@"name"]] || [name isEqual:item[@"icon"]]) {
                    action = item;
                    break;
                }
            }
            if (action[@"block"]) {
                SuccessBlock block = action[@"block"];
                block(action[@"params"]);
            } else
            if (action[@"selector"]) {
                [BKjs invoke:action[@"delegate"] ? action[@"delegate"] : self name:action[@"selector"] arg:action[@"params"]];
            } else
            if (action[@"view"]) {
                // Replace active button with normal icon to keep tool bar state for drawers
                if ([BKjs matchString:@"drawer" string:action[@"view"]]) {
                    button.highlighted = NO;
                }
                [BKui showViewController:nil name:action[@"view"] ? action[@"view"] : name params:action[@"params"]];
            }
            break;
        }
    }
}

@end;
