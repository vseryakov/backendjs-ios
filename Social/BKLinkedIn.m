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

- (NSDictionary*)getDataQuery:(NSString*)path params:(NSDictionary*)params
{
    if (!self.accessToken[@"access_token"]) return params;
    return [BKjs mergeParams:params params:@{ @"oauth2_access_token": self.accessToken[@"access_token"] }];
}

-(NSURLRequest*)getAuthorizeRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://www.linkedin.com/uas/oauth2/authorization"
                     params: @{ @"response_type": @"code",
                                @"client_id": self.clientId,
                                @"scope": self.scope,
                                @"state": self.oauthState,
                                @"redirect_uri": self.redirectURL }];
}

- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params
{
    return [self getRequest:@"GET" path:@"https://www.linkedin.com/uas/oauth2/accessToken"
                     params:@{ @"code": self.oauthCode,
                               @"grant_type": @"authorization_code",
                               @"redirect_uri": self.redirectURL,
                               @"client_id": self.clientId,
                               @"client_secret": self.clientSecret }];
                               
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/people/~:(id,first-name,last-name,formatted-name,email-address,picture-url,public-profile-url,headline,industry)"
           params:[BKjs mergeParams:params params:@{ @"format": @"json" }]
          success:^(id user) {
              NSMutableDictionary *account = [user mutableCopy];
              self.account = account;
              self.account[@"alias"] = user[@"formattedName"];
              self.account[@"icon"] = user[@"pictureUrl"];
              if (success) success(account);
          } failure:failure];
}

- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendRequest:@"GET" path:@"/people/~/connections:(id,formatted-name,picture-url,public-profile-url,location,headline,industry)" params:params success:^(id result) {
        NSMutableArray *list = [@[] mutableCopy];
        for (NSDictionary *item in result[@"data"]) {
            NSMutableDictionary *rec = [item mutableCopy];
            rec[@"type"] = self.name;
            rec[@"alias"] = item[@"formattedName"];
            rec[@"icon"] = item[@"pictureUrl"];
            [list addObject:rec];
        }
        if (success) success(list);
    } failure:failure];
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
    [self sendRequest:@"POST" path:@"http://api.linkedin.com/v1/people/~/shares" params:query success:success failure:failure];
}

@end
