//
//  BKInstagram.m
//
//  Created by Vlad Seryakov on 9/17/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKInstagram.h"

@implementation BKInstagram

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.scope = @"basic";
    self.baseURL = @"https://api.instagram.com/v1";
    self.launchURLs = @[ @{ @"url": @"instagram://user?username=%@", @"param": @"username" },
                         @{ @"url": @"http://instagram.com/%@", @"param": @"username" } ];
    return self;
}

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET"
                       path:@"https://api.instagram.com/oauth/authorize/"
                     params:@ { @"client_id": self.clientId,
                                @"redirect_uri": self.redirectURL,
                                @"scope": self.scope,
                                @"response_type": @"token",
                                @"display": @"touch" }
                       type:nil];
}

- (NSArray*)getItems:(id)result params:(NSDictionary*)params
{
    return [BKjs toArray:result name:@"data" dflt:nil];
}

- (NSString*)getNextURL:(id)result params:(NSDictionary*)params
{
    if (params && params[@"_1"]) return nil;
    return [BKjs toDictionaryString:result name:@"pagination" field:@"next_url"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/users/self" params:nil type:nil success:^(id result) {
        NSDictionary *user = [BKjs toDictionary:result name:@"data"];
        for (id key in user) self.account[key] = user[key];
        self.account[@"icon"] = [user str:@"profile_picture"];
        self.account[@"alias"] = [user str:@"full_name"];
        self.account[@"instagram_id"] = [user str:@"id"];
        if (success) success(self.account);
    } failure:failure];
}

- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getPhotos:@{}
             params:@{ @"count": @(1), @"_1": @(1) }
            success:^(NSArray *photos) {
                NSArray *list = @[ @{ @"id": self.name,
                                      @"name": @"Instagram Photos",
                                      @"type": self.name,
                                      @"icon": photos.count ? photos[0][@"icon"] : @"instagram" } ];
                if (success) success(list);
            } failure:failure];
}

- (void)getPhotos:(NSDictionary*)album params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self sendRequest:@"GET"
                 path:@"/users/self/media/recent"
               params:[BKjs mergeParams:@{ @"count": @(100), @"min_timestamp": @(0) } params:params]
                 type:nil
              success:^(NSArray *photos) {
                  NSMutableArray *list = [@[] mutableCopy];
                  for (NSDictionary *item in photos) {
                      [list addObject:@{ @"type": self.name,
                                         @"icon": item[@"images"][@"thumbnail"][@"url"],
                                         @"image": item[@"images"][@"low_resolution"][@"url"],
                                         @"photo": item[@"images"][@"standard_resolution"][@"url"] }];
                  }
                  if (success) success(list);
              } failure:failure];
}

@end
