//
//  BKMenubarView.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

@interface BKMenubarView: UIView
@property (strong, nonatomic) NSMutableArray *items;
@property (strong, nonatomic) NSMutableDictionary *buttons;
@property (nonatomic) UIEdgeInsets contentInsets;
@property (nonatomic, weak) id delegate;

- (instancetype)init:(CGRect)frame items:(NSArray*)items params:(NSDictionary*)params;
- (void)setMenu:(NSArray*)items params:(NSDictionary*)params;
- (void)update:(NSString*)name params:(NSDictionary*)params;
- (void)update:(NSDictionary*)params;

@end
