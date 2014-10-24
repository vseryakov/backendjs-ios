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
    NSString *reason = [BKjs getErrorMessage:error];
    NSArray *errors = [BKjs toArray:json name:@"errors"];
    if (errors.count) {
        code = [errors[0] num:@"code"];
        reason = [errors[0] str:@"message"];
        if (code == 89 || code == 215) code = 401;
    }
    if (failure) failure(code, reason);
}

- (NSString*)getURL:(NSString *)method path:(NSString*)path params:(NSDictionary*)params
{
    if ([path hasPrefix:@"/media/upload.json"]) return @"https://upload.twitter.com/1.1/media/upload.json";
    return [super getURL:method path:path params:params];
}

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [BKjs makeRequest:@"GET" path:@"https://api.twitter.com/oauth/authorize" params:params type:nil];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://api.twitter.com/oauth/access_token" params:params type:nil body:nil];
}

- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://api.twitter.com/oauth/request_token" params:params type:nil body:nil];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/account/verify_credentials.json" params:params type:nil body:nil success:^(id user) {
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
    NSMutableDictionary *query = [@{} mutableCopy];
    if (msg) query[@"status"] = msg;
    
    if (params && params[@"retweet_id"]) {
        [self sendRequest:@"POST"
                     path:[NSString stringWithFormat:@"/statuses/retweet/%@.json", params[@"retweet_id"]]
                   params:nil
                     type:nil
                     body:nil
                  success:success
                  failure:failure];
    } else
    if (image) {
        [self setHeaders:@"POST" path:@"https://upload.twitter.com/1.1/media/upload.json" params:nil];
        [BKjs uploadImage:@"https://upload.twitter.com/1.1/media/upload.json"
                     name:@"media"
                    image:image
                   params:nil
                  headers:self.headers
                  success:^(id obj) {
                      if (!obj[@"media_id_string"]) {
                          if (failure) failure(-1, @"error uploading an image");
                          return;
                      }
                      
                      query[@"media_ids"] = obj[@"media_id_string"];
                      [self sendRequest:@"POST"
                                   path:@"/statuses/update.json"
                                 params:query
                                   type:nil
                                   body:nil
                                success:success
                                failure:failure];
                  }
                  failure:failure];
    } else {
        [self sendRequest:@"POST"
                     path:@"/statuses/update.json"
                   params:query
                     type:nil
                     body:nil
                  success:success
                  failure:failure];
    }
}

@end
