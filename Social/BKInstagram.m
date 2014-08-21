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
    self.scope = @"likes+comments+relationships";
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
                                @"display": @"touch" }];
}

- (NSString*)getNextURL:(id)result
{
    return [BKjs toDictionaryString:result name:@"pagination" field:@"next_url"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/users/self" params:nil success:^(id result) {
        NSDictionary *user = [BKjs toDictionary:result name:@"data"];
        for (id key in user) self.account[key] = user[key];
        self.account[@"icon"] = user[@"profile_picture"];
        self.account[@"alias"] = user[@"full_name"];
        if (success) success(self.account);
    } failure:failure];
}

- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getPhotos:@"" params:@{}
            success:^(NSArray *photos) {
                NSArray *list = @[ @{ @"id": @"instagram", @"name": @"Instagram Photos", @"type": @"instagram", @"icon": photos.count ? photos[0][@"icon"] : @"", @"photos": photos } ];
                if (success) success(list);
            } failure:failure];
}

- (void)getPhotos:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self sendRequest:@"GET" path:@"/users/self/feed" params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSDictionary *item in result[@"data"]) {
            [list addObject:@{ @"type": self.name,
                               @"icon": item[@"images"][@"thumbnail"][@"url"],
                               @"image": item[@"images"][@"low_resolution"][@"url"],
                               @"photo": item[@"images"][@"standard_resolution"][@"url"] }];
        }
        if (success) success(list);
    } failure:failure];
}

@end
