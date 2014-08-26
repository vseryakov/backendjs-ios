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
    self.type = @"oauth1";
    self.baseURL = @"https://api.twitter.com/1.1";
    self.launchURLs = @[ @{ @"url": @"twitter://user?id=%@", @"param": @"id" },
                         @{ @"url": @"http://www.twitter.com/%@", @"param": @"username" } ];
    return self;
}

- (void)processResponse:(NSHTTPURLResponse*)response error:(NSError*)error json:(id)json failure:(FailureBlock)failure
{
    NSInteger code = response.statusCode;
    NSString *reason = error.description;
    NSArray *errors = [BKjs toArray:json name:@"errors"];
    if (errors.count) {
        code = [errors[0] num:@"code"];
        reason = [errors[0] str:@"message"];
        if (code == 89 || code == 215) code = 401;
    }
    if (failure) failure(code, reason);
}

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [BKjs makeRequest:@"GET" path:@"https://api.twitter.com/oauth/authorize" params:params type:nil];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://api.twitter.com/oauth/access_token" params:params type:nil];
}

- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://api.twitter.com/oauth/request_token" params:params type:nil];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/account/verify_credentials.json" params:params type:nil success:^(id user) {
        NSMutableDictionary *account = [user mutableCopy];
        if (!params || !params[@"id"]) self.account = account;
        account[@"type"] = self.name;
        account[@"alias"] = [account str:@"name"];
        account[@"icon"] = [account str:@"profile_image_url"];
        if (success) success(account);
        
    } failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"status": msg ? msg : @"" } mutableCopy];
    for (id key in params) query[key] = params[key];
    if (image) {
        [self setHeaders:@"POST" path:@"/statuses/update_with_media.json" params:query];
        [BKjs uploadImage:[self getURL:@"POST" path:@"/statuses/update_with_media.json" params:params]
                     name:@"media[]"
                    image:image
                   params:query
                  headers:self.headers
                  success:success
                  failure:failure];
    } else {
        [self sendRequest:@"POST"
                     path:@"/statuses/update.json"
                   params:query
                     type:nil
                  success:success
                  failure:failure];
    }
}

@end
