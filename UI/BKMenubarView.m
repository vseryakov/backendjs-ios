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
   
    // Calculate width of every button, if we have specic width given for any button we
    // give remaining space to the rest of the buttons equally.
    int x = 0, count = items.count, width = self.width, len[count + 1];
    for (int i = 0; i < items.count; i++ ) {
        NSDictionary *obj = [items objectAtIndex:i];
        len[i] = 0;
        if (obj[@"width"]) {
            len[i] = [obj num:@"width"];
            width -= len[i];
            count--;
        }
    }
    
    for (int i = 0; i < items.count; i++ ) {
        if (!len[i]) len[i] = width / count;
        if (i) x += len[i - 1];
        
        NSDictionary *obj = [items objectAtIndex:i];
        NSString *name = [obj str:@[@"name",@"icon"] dflt:nil];
        
        NSMutableDictionary *item = [obj mutableCopy];
        [self.items addObject:item];

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(x, 20, len[i], 44);
        button.exclusiveTouch = YES;
        [button addTarget:self action:@selector(onButton:) forControlEvents:UIControlEventTouchUpInside];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        if (item[@"disabled"]) button.enabled = NO;
        if (item[@"hidden"]) button.hidden = YES;

        if (item[@"x-inset"] || item[@"y-inset"]) {
            button.frame = CGRectInset(button.frame, [item num:@"x-inset"], [item num:@"y-inset"]);
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
        // Apply params
        if (params) {
            if ([name isEqual:params[@"current"]]) {
                button.selected = YES;
            }
            for (NSString *d in params[@"disabled"]) {
                if ([name isEqual:d]) button.enabled = NO;
            }
            for (NSString *d in params[@"hidden"]) {
                if ([name isEqual:d]) button.hidden = NO;
            }
        }
        self.buttons[name] = button;
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
            for (NSDictionary *item in self.items) {
                if ([name isEqual:item[@"name"]] || [name isEqual:item[@"icon"]]) {
                    if (item[@"block"]) {
                        SuccessBlock block = item[@"block"];
                        block(item[@"params"]);
                    } else
                    if (item[@"selector"]) {
                        [BKjs invoke:item[@"delegate"] ? item[@"delegate"] : [BKui rootController] name:item[@"selector"] arg:item[@"params"]];
                    } else
                    if (item[@"view"]) {
                        // Replace active button with normal icon to keep tool bar state for drawers
                        if ([BKjs matchString:@"drawer" string:item[@"view"]]) {
                            button.highlighted = NO;
                        }
                        [BKui showViewController:nil name:item[@"view"] ? item[@"view"] : name params:item[@"params"]];
                    }
                    break;
                }
            }
            break;
        }
    }
}
@end;
