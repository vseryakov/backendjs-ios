//
//  BKTwitter.m
//
//  Created by Vlad Seryakov on 9/17/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKTwitter.h"

@implementation BKTwitter

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.baseURL = @"https://api.twitter.com/1.1/";
    self.launchURLs = @[ @{ @"url": @"twitter://user?id=%@", @"param": @"id" },
                         @{ @"url": @"http://www.twitter.com/%@", @"param": @"username" } ];
    return self;
}

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://api.twitter.com/oauth/authorize" params:params];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequestOAuth1:@"GET" path:@"https://api.twitter.com/oauth/access_token" params:params];
}

- (NSMutableURLRequest*)getRequestTokenReqiest:(NSDictionary*)params
{
    return [self getRequestOAuth1:@"GET" path:@"https://api.twitter.com/oauth/request_token" params:params];
}

@end
