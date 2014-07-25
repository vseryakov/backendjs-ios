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
    self.scope = @"email https://www.googleapis.com/auth/plus.login";
    self.baseURL = @"https://www.googleapis.com";
    self.redirectURL = @"http://localhost";
    self.launchURLs = @[ @{ @"url": @"fb://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.facebook.com/%@", @"param": @"username" } ];
    return self;
}

- (void)logout
{
    [super logout];
}

-(NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://accounts.google.com/o/oauth2/auth"
                     params: @{ @"response_type": @"token",
                                @"client_id": self.clientId,
                                @"scope": self.scope,
                                @"state": self.oauthState,
                                @"login_hint": @"email",
                                @"include_granted_scopes": @"true",
                                @"redirect_uri": self.redirectURL }];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"POST" path:@"https://accounts.google.com/o/oauth2/token"
                     params:@{ @"code": self.oauthCode,
                               @"grant_type": @"authorization_code",
                               @"redirect_uri": self.redirectURL,
                               @"client_id": self.clientId,
                               @"client_secret": self.clientSecret }];
    
}

- (NSString*)getNextURL:(id)result
{
    return [BKjs toDictionaryString:result name:@"paging" field:@"next"];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/plus/v1/people/me" params:[BKjs mergeParams:params params:@{ @"fields": @"picture.type(large),id,email,name,birthday,gender" }]
          success:^(id result) {
              NSDictionary *user = [result isKindOfClass:[NSDictionary class]] ? result : @{};
              for (id key in user) self.account[key] = user[key];
              self.account[@"alias"] = user[@"nickname"] ? user[@"nickname"] : user[@"displayName"];
              self.account[@"icon"] = [BKjs toDictionaryString:user name:@"image" field:@"url"];
              if (success) success(self.account);
          } failure:failure];
}

- (void)getFriends:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self getData:@"/me/friends" params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSDictionary *item in result[@"data"]) {
            NSMutableDictionary *rec = [item mutableCopy];
            rec[@"type"] = @"facebook";
            rec[@"icon"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=small", rec[@"id"]];
            [list addObject:rec];
        }
        if (success) success(list);
    } failure:failure];
}

@end
