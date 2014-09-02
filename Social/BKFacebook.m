//
//  BKFacebook.m
//
//  Created by Vlad Seryakov on 9/17/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKFacebook.h"

@implementation BKFacebook

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.scope = @"email";
    self.baseURL = @"https://graph.facebook.com";
    self.launchURLs = @[ @{ @"url": @"fb://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.facebook.com/%@", @"param": @"username" } ];
    return self;
}

- (void)checkResponse:(NSURLRequest*)request response:(NSHTTPURLResponse*)response error:(NSError*)error json:(id)json
{
    if (response.statusCode == 401) [self.accessToken removeAllObjects];
}

- (NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET"
                       path:@"https://graph.facebook.com/oauth/authorize"
                     params:@ { @"client_id": self.clientId,
                                @"redirect_uri": self.redirectURL,
                                @"scope": self.scope,
                                @"type": @"user_agent",
                                @"display": @"touch" }
                       type:nil body:nil];
}

- (NSArray*)getItems:(id)result params:(NSDictionary*)params
{
    return [BKjs toArray:result name:@"data" dflt:nil];
}

- (NSString*)getNextURL:(NSURLRequest*)request result:(id)result params:(NSDictionary*)params
{
    return [BKjs toDictionaryString:result name:@"paging" field:@"next"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/@id@"
                            params:params
                            defaults:@{ @"id": @"me",
                                        @"fields": @"picture.type(large),id,email,name,birthday,gender" }];

    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSMutableDictionary *account = [[result isKindOfClass:[NSDictionary class]] ? result : @{} mutableCopy];
                  if (!params || !params[@"id"]) self.account = account;
                  account[@"type"] = self.name;
                  account[@"facebook_id"] = [account str:@"id"];
                  account[@"alias"] = [account str:@"name"];
                  account[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:account name:@"picture"] name:@"data" field:@"url"];
                  if (success) success(account);
              } failure:failure];
}

- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/@id@"
                            params:params
                            defaults:@{ @"id": @"me",
                                        @"fields": @"albums.fields(name,photos.limit(1).fields(picture),count)" }];

    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *album in [BKjs toArray:result[@"albums"] name:@"data"]) {
                      for (NSDictionary *icon in [BKjs toArray:album[@"photos"] name:@"data"]) {
                          [list addObject:@{ @"type": self.name,
                                             @"id": [album str:@"id"],
                                             @"name": [album str:@"name"],
                                             @"icon": [icon str:@"picture"],
                                             @"count": [album str:@"count"] }];
                      }
                  }
                  if (success) success(list);
              } failure:failure];
}

- (void)getPhotos:(NSDictionary*)album params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self sendRequest:@"GET"
                 path:[NSString stringWithFormat:@"/%@/photos", album[@"id"]]
               params:params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *item in result) {
                      [list addObject:@{ @"type": self.name,
                                         @"icon": [item str:@"picture"],
                                         @"image": [item str:@"source"] }];
                  }
                  if (success) success(list);
              } failure:failure];
}

- (void)getFriends:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/@id@/friends"
                            params:params
                            defaults:@{ @"id": @"me",
                                        @"fields": @"id,email,name,birthday,gender" }];

    [self sendRequest:@"GET"
                 path:query.path
               params:query.params
                 type:nil
                 body:nil
              success:^(id result) {
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *item in result) {
                      NSMutableDictionary *rec = [item mutableCopy];
                      rec[@"facebook_id"] = [rec str:@"id"];
                      rec[@"type"] = self.name;
                      rec[@"alias"] = [item str:@"name"];
                      rec[@"icon"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=small", rec[@"id"]];
                      [list addObject:rec];
                  }
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
