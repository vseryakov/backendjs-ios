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
    self.accessTokenName = @"oauth2_access_token";
    self.scope = @"r_ basicprofile r_emailaddress r_fullprofile r_network r_contactinfo w_messages";
    self.baseURL = @"https://www.linkedin.com";
    self.launchURLs = @[ @{ @"url": @"linkedin://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.linkedin.com/%@", @"param": @"username" } ];
    return self;
}

- (void)logout
{
    [super logout];
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
    [self getData:@"/people~" params:params success:^(id user) {
        NSMutableDictionary *account = [user mutableCopy];
        self.account = account;
        if (success) success(account);
        
    } failure:failure];
}

@end
