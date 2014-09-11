//
//  BKLinkedIn.m
//
//  Created by Vlad Seryakov on 9/17/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKLinkedIn.h"

@implementation BKLinkedIn
- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.type = @"oauth2";
    self.scope = @"r_emailaddress r_fullprofile r_network r_contactinfo w_messages rw_nus";
    self.baseURL = @"https://api.linkedin.com/v1";
    self.launchURLs = @[ @{ @"url": @"linkedin://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.linkedin.com/%@", @"param": @"username" } ];
    return self;
}

- (void)logout
{
    [super logout];
}

- (NSString*)getURL:(NSString *)method path:(NSString*)path params:(NSDictionary*)params
{
    NSString *url = [super getURL:method path:path params:params];
    if ([method isEqual:@"POST"] && self.accessToken[@"access_token"]) {
        return [NSString stringWithFormat:@"%@?oauth2_access_token=%@", url, self.accessToken[@"access_token"]];
    }
    return url;
}

- (NSDictionary*)getQuery:(NSString *)method path:(NSString*)path params:(NSDictionary*)params
{
    if (!self.accessToken[@"access_token"] || [method isEqual:@"POST"]) return params;
    return [BKjs mergeParams:params params:@{ @"oauth2_access_token": self.accessToken[@"access_token"] }];
}

-(NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://www.linkedin.com/uas/oauth2/authorization"
                     params: @{ @"response_type": @"code",
                                @"client_id": self.clientId,
                                @"scope": self.scope,
                                @"state": self.oauthState,
                                @"redirect_uri": self.redirectURL }
                       type:nil body:nil];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://www.linkedin.com/uas/oauth2/accessToken"
                     params:@{ @"code": self.oauthCode,
                               @"grant_type": @"authorization_code",
                               @"redirect_uri": self.redirectURL,
                               @"client_id": self.clientId,
                               @"client_secret": self.clientSecret }
                       type:nil body:nil];
                               
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/people/@id@:@fields@"
                            params:params
                            defaults:@{ @"id": @"~",
                                        @"fields": @"(id,first-name,last-name,formatted-name,email-address,picture-url,public-profile-url,headline,industry)" }];
    
    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id user) {
                  NSMutableDictionary *account = [user mutableCopy];
                  if (!params || !params[@"id"]) self.account = account;
                  account[@"type"] = self.name;
                  account[@"linkedin_id"] = [account str:@"id"];
                  account[@"alias"] = [account str:@"formattedName"];
                  account[@"icon"] = [account str:@"pictureUrl"];
                  if (success) success(account);
              } failure:failure];
}

- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/people/@id@/connections:@fields@"
                            params:params
                            defaults:@{ @"id": @"~",
                                        @"fields": @"(id,formatted-name,picture-url,public-profile-url,location,headline,industry)",
                                        @"count": @(500) }];

    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *item in result[@"values"]) {
                      if (!item[@"id"] || !item[@"formattedName"]) continue;
                      NSMutableDictionary *rec = [item mutableCopy];
                      rec[@"linkedin_id"] = rec[@"id"];
                      rec[@"type"] = self.name;
                      rec[@"alias"] = item[@"formattedName"];
                      rec[@"icon"] = [item str:@"pictureUrl"];
                      [list addObject:rec];
                  }
                  Logger(@"%d records", (int)list.count);
                  if (success) success(list);
              } failure:failure];
}

- (void)sendMessage:(NSString*)subject body:(NSString*)body params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"subject": subject ? subject : @"", @"body": body ? body : @"" } mutableCopy];
    NSMutableArray *to = [@[] mutableCopy];
    for (NSString *key in [BKjs toArray:params name:@"to"]) {
        [to addObject:@{ @"person": @{ @"_path": [NSString stringWithFormat:@"/people/%@", key] } }];
    }
    query[@"recipients"] = @{ @"values": to };
    [self sendRequest:@"POST"
                 path:@"/people/~/mailbox"
               params:query
                 type:@"application/json"
                 body:nil
              success:success
              failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"visibility": @{ @"code": @"anyone" } } mutableCopy];
    if (msg) query[@"comment"] = msg;
    if (params[@"link"]) {
        query[@"content"] = [@{ @"title": [params str:@"title"], @"submitted-url": params[@"link"] } mutableCopy];
    }
    [self sendRequest:@"POST"
                 path:@"/people/~/shares"
               params:query
                 type:@"application/json"
                 body:nil
              success:success
              failure:failure];
}

@end
