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
    unsigned long x = 0, count = items.count, width = self.width, len[count + 1];
    memset(len, 0, sizeof(len));
    for (int i = 0; i < items.count; i++ ) {
        NSDictionary *obj = [items objectAtIndex:i];
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
        NSString *name = [obj str:@[@"title",@"icon"] dflt:nil];
        
        NSMutableDictionary *item = [obj mutableCopy];
        [self.items addObject:item];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(x, self.height == 64 ? 20 : 0, len[i], 44);
        button.exclusiveTouch = YES;
        [button addTarget:self action:@selector(onButton:) forControlEvents:UIControlEventTouchUpInside];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [self addSubview:button];
        self.buttons[name] = button;
        [BKui setStyle:button style:item];
        [self updateButtonStyle:name params:params];
    }
    return self;
}

- (BOOL)checkItem:(NSString*)name params:(NSDictionary*)params item:(NSString*)item
{
    if (!params) return NO;
    if ([params[item] isKindOfClass:[NSArray class]]) return [params[item] containsObject:name];
    return [name isEqual:params[item]];
}

- (void)update:(NSDictionary*)params
{
    for (NSString *name in self.buttons) {
        [self updateButtonStyle:name params:params];
    }
}

- (void)updateButtonStyle:(NSString*)name params:(NSDictionary*)params
{
    if (!name || !params) return;
    UIButton *button = self.buttons[name];
    if (!button) return;

    if ([name isEqual:params[@"current"]]) button.selected = YES;
    if ([self checkItem:name params:params item:@"disabled"]) button.enabled = NO;
    if ([self checkItem:name params:params item:@"enabled"]) button.enabled = YES;
    if ([self checkItem:name params:params item:@"hidden"]) button.hidden = YES;
    if ([self checkItem:name params:params item:@"visible"]) button.hidden = NO;
    if (params[@"badge"] && params[@"badge"][name]) [BKui makeBadge:button style:params[@"badge"][name]];
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
