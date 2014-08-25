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
                       type:nil];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://www.linkedin.com/uas/oauth2/accessToken"
                     params:@{ @"code": self.oauthCode,
                               @"grant_type": @"authorization_code",
                               @"redirect_uri": self.redirectURL,
                               @"client_id": self.clientId,
                               @"client_secret": self.clientSecret }
                       type:nil];
                               
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
              success:^(id user) {
                  NSMutableDictionary *account = [user mutableCopy];
                  if (!params || !params[@"id"]) self.account = account;
                  self.account[@"linkedin_id"] = [user str:@"id"];
                  self.account[@"alias"] = [user str:@"formattedName"];
                  self.account[@"icon"] = [user str:@"pictureUrl"];
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
              success:success
              failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"message": msg ? msg : @"" } mutableCopy];
    for (id key in params) query[key] = params[key];
    /*<share>
    <comment>Check out the LinkedIn Share API!</comment>
    <content>
    <title>LinkedIn Developers Documentation On Using the Share API</title>
    <description>Leverage the Share API to maximize engagement on user-generated content on LinkedIn</description>
    <submitted-url>https://developer.linkedin.com/documents/share-api</submitted-url>
    <submitted-image-url>http://m3.licdn.com/media/p/3/000/124/1a6/089a29a.png</submitted-image-url>
    </content>
    <visibility>
    <code>anyone</code>
    </visibility>
    </share>*/
    [self sendRequest:@"POST"
                 path:@"/people/~/shares"
               params:query
                 type:nil
              success:success
              failure:failure];
}

@end
