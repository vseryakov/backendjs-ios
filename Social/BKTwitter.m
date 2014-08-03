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

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/1/account/verify_credentials.json" params:params success:^(id user) {
        NSMutableDictionary *account = [user mutableCopy];
        self.account = account;
        self.account[@"alias"] = [account str:@"name"];
        self.account[@"icon"] = [account str:@"profile_image_url"];
        if (success) success(account);
        
    } failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"status": msg ? msg : @"" } mutableCopy];
    for (id key in params) query[key] = params[key];
    if (image) {
        [BKjs uploadImage:@"/1.1/statuses/update_with_media.json" name:@"media[]" image:image params:query success:success failure:failure];
    } else {
        [self postData:@"/1.1/statuses/update.json" params:query success:success failure:failure];
    }
}

@end
