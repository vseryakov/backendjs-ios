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
@property (nonatomic, strong) NSString* type;
@property (nonatomic, strong) NSString* scope;

@property (nonatomic, strong) NSString* clientId;
@property (nonatomic, strong) NSString* clientSecret;

@property (nonatomic, strong) NSString* baseURL;
@property (nonatomic, strong) NSString* redirectURL;
@property (nonatomic, strong) NSArray* launchURLs;

@property (nonatomic, strong) NSMutableDictionary* headers;
@property (nonatomic, strong) NSMutableDictionary* account;
@property (nonatomic, strong) NSMutableDictionary* params;

@property (nonatomic, strong) NSMutableDictionary *accessToken;

@property (nonatomic, strong) NSString* oauthCode;
@property (nonatomic, strong) NSString* oauthState;

+ (NSMutableDictionary*)accounts;
+ (void)refresh;
+ (void)getContacts:(NSArray*)types items:(NSMutableArray*)items finish:(GenericBlock)finish;
+ (void)getFriends:(NSArray*)types items:(NSMutableArray*)items finish:(GenericBlock)finish;
+ (void)getAlbums:(NSArray*)types items:(NSMutableArray*)items finish:(GenericBlock)finish;

- (id)init:(NSString*)name;
- (id)init:(NSString*)name clientId:(NSString*)clientId;

- (BOOL)isValid;
- (BOOL)isAuthenticating;
- (BOOL)isRunning;
- (void)logout;
- (void)login:(ErrorBlock)finished;
- (BOOL)launch;
- (void)enableCookies;
- (void)clearCookies;
- (void)saveToken;
- (void)restoreToken;
- (void)refreshToken;

// High level methods for API calls
- (NSMutableURLRequest*)getRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params type:(NSString*)type body:(NSData*)body;
- (void)sendRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params type:(NSString*)type body:(NSData*)body success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)setHeaders:(NSString *)method path:(NSString *)path params:(NSDictionary *)parameters;

// OAUTH methods
- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAuthenticateRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params;
- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params;

// API customizations
- (NSError*)getError:(NSDictionary*)params;
- (NSString*)getURL:(NSString *)method path:(NSString*)path params:(NSDictionary*)params;
- (NSString*)getNextURL:(NSURLRequest*)request result:(id)result params:(NSDictionary*)params;
- (NSArray*)getItems:(id)result params:(NSDictionary*)params;
- (NSDictionary*)getQuery:(NSString *)method path:(NSString*)path params:(NSDictionary*)params;
- (void)processResponse:(NSHTTPURLResponse*)response error:(NSError*)error json:(id)json failure:(FailureBlock)failure;

// High level API common for all services
- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getPhotos:(NSDictionary*)album params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)getFriends:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
- (void)sendMessage:(NSString*)subject body:(NSString*)body params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

@end;
