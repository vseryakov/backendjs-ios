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
@property (nonatomic, strong) NSString* scope;

@property (nonatomic, strong) NSString* clientId;
@property (nonatomic, strong) NSString* clientSecret;

@property (nonatomic, strong) NSString* baseURL;
@property (nonatomic, strong) NSString* redirectURL;
@property (nonatomic, strong) NSArray* launchURLs;

@property (nonatomic, strong) NSMutableDictionary* headers;
@property (nonatomic, strong) NSMutableDictionary* account;

@property (nonatomic, strong) NSMutableDictionary *accessToken;

@property (nonatomic, strong) NSString* oauthCode;
@property (nonatomic, strong) NSString* oauthState;

+ (NSMutableDictionary*)accounts;
+ (void)refresh;

- (id)init:(NSString*)name;
- (id)init:(NSString*)name clientId:(NSString*)clientId;

- (BOOL)isValid;
- (void)logout;
- (void)login:(ErrorBlock)finished;
- (BOOL)launch;
- (void)enableCookies;
- (void)clearCookies;

- (NSMutableURLRequest*)getRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params;
- (void)setHeaders:(NSString *)method path:(NSString *)path params:(NSDictionary *)parameters;

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAuthenticateRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params;

- (void)processResponse:(NSHTTPURLResponse*)response error:(NSError*)error json:(id)json failure:(FailureBlock)failure;

- (NSError*)getError:(NSDictionary*)params;
- (NSString*)getURL:(NSString*)path;
- (NSString*)getNextURL:(id)result;
- (NSArray*)getItems:(id)result;
- (NSDictionary*)getQuery:(NSString*)path params:(NSDictionary*)params;

// High level methods for API calls
- (void)sendRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

// High level API common for all services
- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getPhotos:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

@end;
