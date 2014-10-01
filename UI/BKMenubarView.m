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
    self.contentInsets = UIEdgeInsetsZero;
    self.items = [@[] mutableCopy];
    self.buttons = [@{} mutableCopy];
    [self setMenu:items params:params];
    return self;
}

- (void)setMenu:(NSArray*)items params:(NSDictionary*)params
{
    if (!items) return;
    [self.items removeAllObjects];
    for (id name in self.buttons) [self.buttons[name] removeFromSuperview];
    [self.buttons removeAllObjects];
    
    // Calculate width of every button, if we have specic width given for any button we
    // give remaining space to the rest of the buttons equally.
    unsigned long x = 0, count = items.count, width = self.width - self.contentInsets.left - self.contentInsets.right, len[count + 1];
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
        NSString *name = [obj str:@[@"name",@"title",@"icon"] dflt:[NSString stringWithFormat:@"%d", i]];
        
        NSMutableDictionary *item = [obj mutableCopy];
        [self.items addObject:item];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(self.contentInsets.left + x, self.contentInsets.top, len[i], self.height - self.contentInsets.top - self.contentInsets.bottom);
        button.exclusiveTouch = YES;
        [button addTarget:self action:@selector(onButton:) forControlEvents:UIControlEventTouchUpInside];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        [self addSubview:button];
        [BKui setStyle:button style:item];
        self.buttons[name] = button;
    }
    [self update:params];
}

- (BOOL)checkItem:(NSString*)name params:(NSDictionary*)params item:(NSString*)item
{
    if (!params) return NO;
    if ([params[item] isKindOfClass:[NSArray class]]) return [params[item] containsObject:name];
    return [name isEqual:params[item]];
}

- (void)update:(NSDictionary*)params
{
    if (!params) return;
    for (NSString *name in self.buttons) {
        [self update:name params:params[name]];
    }
}

- (void)update:(NSString*)name params:(NSDictionary*)params
{
    if (!name || !params) return;
    [BKui setStyle:self.buttons[name] style:params];
}

- (IBAction)onButton:(id)sender
{
    for (NSString *name in self.buttons) {
        UIButton *button = self.buttons[name];
        if (sender == button) {
            // Find additional parameters for given action
            for (NSDictionary *item in self.items) {
                id delegate = item[@"delegate"] ? item[@"delegate"] : self.delegate ? self.delegate : [BKui rootController];
                if ([name isEqual:item[@"name"]] || [name isEqual:item[@"title"]] || [name isEqual:item[@"icon"]]) {
                    if (item[@"block"]) {
                        SuccessBlock block = item[@"block"];
                        block(item[@"params"] ? item[@"params"] : item);
                    } else
                    if (item[@"selector"]) {
                        [BKjs invoke:delegate name:item[@"selector"] arg:item];
                    } else
                    if (item[@"view"]) {
                        // Replace active button with normal icon to keep tool bar state for drawers
                        if ([BKjs matchString:@"drawer" string:item[@"view"]]) {
                            button.highlighted = NO;
                        }
                        [BKui showViewController:delegate name:item[@"view"] ? item[@"view"] : name params:item];
                    }
                    break;
                }
            }
            break;
        }
    }
}
@end;
