//
//  BKMenubarView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKMenubarView: UIView
@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) NSMutableDictionary *buttons;

- (instancetype)init:(CGRect)frame items:(NSArray*)items params:(NSDictionary*)params;
- (void)updateButtonStyle:(NSString*)name params:(NSDictionary*)params;
- (void)update:(NSDictionary*)params;

@end
