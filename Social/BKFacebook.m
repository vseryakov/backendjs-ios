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
    self.scope = @"email,user_friends";
    self.baseURL = @"https://graph.facebook.com";
    self.launchURLs = @[ @{ @"url": @"fb://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.facebook.com/%@", @"param": @"username" } ];
    return self;
}

- (void)logout
{
    [super logout];
}

- (NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET"
                       path:@"https://graph.facebook.com/oauth/authorize"
                     params:@ { @"client_id": self.clientId,
                                @"redirect_uri": self.redirectURL,
                                @"scope": self.scope,
                                @"type": @"user_agent",
                                @"display": @"touch" }];
}

- (NSString*)getDataNextURL:(id)result
{
    return [BKjs toDictionaryString:result name:@"paging" field:@"next"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/me" params:[BKjs mergeParams:params params:@{ @"fields": @"picture.type(large),id,email,name,birthday,gender" }]
          success:^(id result) {
              NSDictionary *user = [result isKindOfClass:[NSDictionary class]] ? result : @{};
              for (id key in user) self.account[key] = user[key];
              self.account[@"alias"] = user[@"name"];
              self.account[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:user name:@"picture"] name:@"data" field:@"url"];
              if (success) success(self.account);
          } failure:failure];
}

- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/me" params:[BKjs mergeParams:params params:@{ @"fields": @"albums.fields(name,photos.limit(1).fields(picture),count)" }]
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

- (void)getPhotos:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self getData:[NSString stringWithFormat:@"/%@/photos",name] params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSDictionary *item in result[@"data"]) {
            [list addObject:@{ @"type": self.name,
                               @"icon": [item str:@"picture"],
                               @"image": [item str:@"source"] }];
        }
        if (success) success(list);
    } failure:failure];
}

- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/me/friends" params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSDictionary *item in result[@"data"]) {
            NSMutableDictionary *rec = [item mutableCopy];
            rec[@"type"] = self.name;
            rec[@"alias"] = item[@"name"];
            rec[@"icon"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=small", rec[@"id"]];
            [list addObject:rec];
        }
        if (success) success(list);
    } failure:failure];
}

-(void)getMutualFriends:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:[NSString stringWithFormat:@"/me/mutualfriends/%@",name] params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSMutableDictionary *item in result[@"data"]) {
            item[@"type"] = self.name;
            item[@"alias"] = item[@"name"];
            item[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:item name:@"picture"] name:@"data" field:@"url"];
            [list addObject:item];
        }
        if (success) success(list);
    } failure:failure];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    NSMutableDictionary *query = [@{ @"message": msg ? msg : @"" } mutableCopy];
    for (id key in params) query[key] = params[key];
    [self postData:@"/me/feed" params:query success:success failure:failure];
}
     
@end
