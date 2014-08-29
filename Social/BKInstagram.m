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
                       type:nil
                       body:nil];
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
    [self sendRequest:@"GET" path:@"/users/self" params:nil type:nil body:nil success:^(id result) {
        NSMutableDictionary *account = [[BKjs toDictionary:result name:@"data"] mutableCopy];
        if (!params || !params[@"id"]) self.account = account;
        account[@"type"] = self.name;
        account[@"icon"] = [account str:@"profile_picture"];
        account[@"alias"] = [account str:@"full_name"];
        account[@"instagram_id"] = [account str:@"id"];
        if (success) success(account);
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
                 body:nil
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
