//
//  BKSocialAccount.h
//
//  Created by Vlad Seryakov on 12/1/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKSocialAccount.h"
#import "BKWebViewController.h"

// Social account for third parties
@interface BKSocialAccount: NSObject
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString *type;

@property (nonatomic, strong) NSString* clientId;
@property (nonatomic, strong) NSString* clientSecret;
@property (nonatomic, strong) NSString* scope;

@property (nonatomic, strong) NSString* baseURL;
@property (nonatomic, strong) NSString* redirectURL;
@property (nonatomic, strong) NSArray* launchURLs;

@property (nonatomic, strong) NSString* dataName;
@property (nonatomic, strong) NSString* parseTokenName;
@property (nonatomic, strong) NSString* requestTokenName;
@property (nonatomic, strong) NSString* refreshTokenName;
@property (nonatomic, strong) NSString* expiresName;
@property (nonatomic, strong) NSString* errorName;
@property (nonatomic, strong) NSString* errorDescr;
@property (nonatomic, strong) NSMutableDictionary* headers;

@property (nonatomic, strong) NSMutableDictionary* account;
@property (nonatomic, strong) NSString* accessToken;
@property (nonatomic, strong) NSString* refreshToken;

@property (nonatomic) NSInteger oauthExpires;
@property (nonatomic, strong) NSString* oauthCode;
@property (nonatomic, strong) NSString* oauthState;
@property (nonatomic, strong) NSMutableDictionary *oauthToken;

+ (NSMutableDictionary*)accounts;

- (id)init:(NSString*)name;
- (id)init:(NSString*)name clientId:(NSString*)clientId;

- (BOOL)isOpen;
- (void)logout;
- (void)login:(ErrorBlock)finished;
- (BOOL)launch;
- (void)enableCookies;
- (void)clearCookies;

- (NSMutableURLRequest*)getRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params;
- (NSMutableURLRequest *)getRequestOAuth1:(NSString *)method path:(NSString *)path params:(NSDictionary *)parameters;

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAuthenticateRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params;

- (BOOL)parseRedirectURL:(NSURLRequest*)request;

- (NSString*)getDataURL:(NSString*)path;
- (NSMutableDictionary*)getDataQuery:(NSString*)path params:(NSDictionary*)params;
- (NSString*)getDataNextURL:(id)result;

- (void)getData:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)postData:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

// Common functions
- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getPhotos:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

@end;
