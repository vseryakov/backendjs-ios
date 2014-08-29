//
//  BKGoogle.m
//
//  Created by Vlad Seryakov on 7/20/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKGoogle.h"

@implementation BKGoogle

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.type = @"oauth2";
    self.scope = @"email https://www.googleapis.com/auth/plus.login";
    self.baseURL = @"https://www.googleapis.com";
    self.redirectURL = @"http://localhost";
    self.launchURLs = @[ @{ @"url": @"google://%@", @"param": @"id" },
                         @{ @"url": @"https://plus.google.com/%@", @"param": @"id" } ];
    return self;
}

- (void)logout
{
    [super logout];
}

-(NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://accounts.google.com/o/oauth2/auth"
                     params: @{ @"response_type": @"code",
                                @"client_id": self.clientId,
                                @"scope": self.scope,
                                @"state": self.oauthState,
                                @"login_hint": @"email",
                                @"include_granted_scopes": @"true",
                                @"redirect_uri": self.redirectURL } type:nil body:nil];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"POST" path:@"https://accounts.google.com/o/oauth2/token"
                     params:@{ @"code": self.oauthCode,
                               @"grant_type": @"authorization_code",
                               @"redirect_uri": self.redirectURL,
                               @"client_id": self.clientId,
                               @"client_secret": self.clientSecret } type:nil body:nil];
    
}

- (NSString*)getNextURL:(id)result
{
    return [BKjs toDictionaryString:result name:@"paging" field:@"next"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/plus/v1/people/@id@"
                            params:params
                            defaults:@{ @"id": @"me",
                                        @"alt": @"json" }];

    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
          success:^(id result) {
              NSMutableDictionary *account = [[result isKindOfClass:[NSDictionary class]] ? result : @{} mutableCopy];
              if (!params || !params[@"id"]) self.account = account;
              account[@"type"] = self.name;
              account[@"alias"] = [account str:@[@"nickname", @"displayName"] dflt:nil];
              account[@"icon"] = [BKjs toDictionaryString:account name:@"image" field:@"url"];
              if (success) success(account);
          } failure:failure];
}

- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/m8/feeds/contacts/@id@/full"
                            params:params
                            defaults:@{ @"id": @"default",
                                        @"alt": @"json",
                                        @"max-results": @(10000)}];
    
    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSString *aid = params[@"id"];
                  if (!aid) aid = @"default";
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *item in [BKjs toDictionaryArray:result name:@"feed" field:@"entry"]) {
                      NSMutableDictionary *rec = [@{} mutableCopy];
                      rec[@"type"] = self.name;
                      rec[@"id"] = [BKjs toDictionaryString:item name:@"id" field:@"$t"];
                      rec[@"google_id"] = rec[@"id"];
                      rec[@"mtime"] = [BKjs toDictionaryString:item name:@"updated" field:@"$t"];
                      if (item[@"gContact$birthday"]) {
                          rec[@"birthday"] = [BKjs toDictionaryString:item name:@"gContact$birthday" field:@"when"];
                      }
                      if ([item[@"gd$email"] isKindOfClass:[NSArray class]]) {
                          rec[@"email"] = [@{} mutableCopy];
                          for (NSDictionary *link in item[@"gd$email"]) {
                              if (link[@"address"]) rec[@"email"][link[@"address"]] = [[[link str:@"rel"] componentsSeparatedByString:@"#"] lastObject];
                          }
                      } else {
                          rec[@"email"] = [@{} mutableCopy];
                          rec[@"email"][[BKjs toDictionaryString:item name:@"gd$email" field:@"address"]] = @"email";
                      }
                      if ([item[@"gd$phoneNumber"] isKindOfClass:[NSArray class]]) {
                          rec[@"phone"] = [@{} mutableCopy];
                          for (NSDictionary *link in item[@"gd$phoneNumber"]) {
                              if (link[@"$t"]) rec[@"phone"][link[@"$t"]] = [[[link str:@"rel"] componentsSeparatedByString:@"#"] lastObject];
                          }
                      } else {
                          rec[@"phone"] = [@{} mutableCopy];
                          rec[@"phone"][[BKjs toDictionaryString:item name:@"gd$phoneNumber" field:@"$t"]] = @"phone";
                      }
                      for (NSDictionary *link in item[@"link"]) {
                          if (link[@"rel"] && link[@"gd$etag"] && link[@"href"] && [link[@"rel"] hasSuffix:@"#photo"]) {
                              rec[@"icon"] = [NSString stringWithFormat:@"%@?access_token=%@", [link[@"href"] stringByReplacingOccurrencesOfString:@"www.googleapis.com" withString:@"www.google.com"], self.accessToken[@"access_token"]];
                          }
                      }
                      rec[@"alias"] = [BKjs toDictionaryString:item name:@"title" field:@"$t"];
                      if ([rec isEmpty:@"alias"] && rec[@"email"] && [rec[@"email"] count]) {
                          rec[@"alias"] = [rec[@"email"] allKeys][0];
                      }
                      if (![rec isEmpty:@"alias"]) [list addObject:rec];
                  }
                  Logger(@"%d records", (int)list.count);
                  if (success) success(list);
              } failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"message": msg ? msg : @"" } mutableCopy];
    for (id key in params) query[key] = params[key];
    [self sendRequest:@"POST" path:@"/me/feed" params:query type:nil body:nil success:success failure:failure];
}

@end
