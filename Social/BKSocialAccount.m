//
//  BKSocialAccount.m
//
//  Created by Vlad Seryakov on 12/1/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKSocialAccount.h"

@interface BKSocialAccount () <UIWebViewDelegate>
@property (nonatomic, strong) BKWebViewController *loginView;

@property (nonatomic, strong) NSString *oauthRealm;
@property (nonatomic, strong) NSString *oauthSignature;
@end

@implementation BKSocialAccount

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implmented"); };
- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implmented"); };
- (void)getPhotos:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implmented"); };
- (NSString*)getDataNextURL:(id)result { return nil; }

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getAuthenticateRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params { return nil; }

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init];
    self.name = name;
    self.type = @"web";
    self.clientId = clientId;
    self.accessToken = [BKjs passwordForService:self.clientId account:self.name error:nil];
    self.redirectURL = [NSString stringWithFormat:@"http://%@/oauth/%@", BKjs.appDomain, self.clientId];
    self.accessTokenName = @"access_token";
    self.refreshTokenName = @"refresh_token";
    self.expiresName = @"expires_in";
    self.errorName = @"error";
    self.dataName = @"data";
    self.oauthSignature = @"HMAC-SHA1";
    self.account = [@{} mutableCopy];
    self.oauthState = [BKjs getUUID];
    self.headers = [@{} mutableCopy];
    return self;
}

- (BOOL)isOpen
{
    return self.accessToken != nil && self.accessToken.length > 0;
}

// List of objects with "url" and "param" properties
- (BOOL)launch
{
    for (NSDictionary *item in self.launchURLs) {
        // A parameter to pass with the url, must exists in the account
        if ([BKjs isEmpty:self.account name:item[@"param"]]) return NO;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:item[@"url"],self.account[item[@"param"]]]];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            return [[UIApplication sharedApplication] openURL:url];
        }
    }
    return NO;
}

// By default save id and username for each social account, some API requests work by id some only by username
- (void)saveAccount
{
    NSString *aid = [NSString stringWithFormat:@"%@_id",self.name];
    NSString *aname = [NSString stringWithFormat:@"%@_username",self.name];
    
    BKjs.account[aid] = [self.account str:@"id"];
    BKjs.account[aname] = [self.account str:@"username"];
}

// Parse access token from the url or the data,
- (BOOL)parseRedirectURL:(NSURLRequest *)request
{
    // By default client-side OAuth 2.0 uses the url fragment in the redirect url
    NSMutableDictionary *query = [BKjs parseQueryString:[[request URL] fragment]];
    NSString *token = query[self.accessTokenName];
    NSString *error = query[self.errorName];
    
    if ([BKjs isEmpty:token]) {
        // Try the query string in case when access token is in the parameters
        query = [BKjs parseQueryString:[[request URL] query]];
        token = query[self.accessTokenName];
        if (!error) error = query[self.errorName];
    }
    if (![BKjs isEmpty:token]) {
        self.accessToken = [token copy];
        [BKjs setPassword:self.accessToken forService:self.clientId account:self.name error:nil];
    } else {
        self.accessToken = nil;
    }
    [self.loginView finish:request error:error ? [NSError errorWithDomain:self.name code:0 userInfo:@{ NSLocalizedDescriptionKey: error }] : nil];
    return NO;
}

- (NSString*)getDataURL:(NSString*)path
{
    return [NSString stringWithFormat:@"%@%@", self.baseURL, path];
}

- (NSMutableDictionary*)getDataQuery:(NSString*)path params:(NSDictionary*)params
{
    NSMutableDictionary *query = [@{} mutableCopy];
    for (id key in params) query[key] = params[key];
    if (self.accessToken) query[self.accessTokenName] = self.accessToken;
    return query;
}

- (void)getData:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    GenericBlock relogin = ^() {
        [self login:^(NSError *error) {
            if (![self isOpen]) {
                Logger(@"%@: %@", self.name, error);
                if (failure) failure(error ? error.code : -1, error.description);
            } else {
                [self getResult:[self getDataURL:path] params:[self getDataQuery:path params:params] success:success failure:failure];
            }
        }];
    };
    
    if (![self isOpen]) {
        relogin();
        return;
    }
    
    [self getResult:[self getDataURL:path] params:[self getDataQuery:path params:params] success:success failure:^(NSInteger code, NSString *reason) {
        // Token expired, try to login and send again
        relogin();
    }];
}

- (void)postData:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [BKjs sendRequest:[self getDataURL:path] method:@"POST" params:[self getDataQuery:path params:params] headers:self.headers body:nil success:success failure:failure];
}

- (void)getResult:(NSString*)path params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSMutableArray *items = [@[] mutableCopy];
    [BKjs sendRequest:path method:@"GET" params:params headers:self.headers body:nil success:^(id result) {
        [self processResult:result items:items success:success failure:^(NSInteger code, NSString *reason) {
            if (failure) failure(code, reason);
        }];
    } failure:failure];
}

- (void)processResult:(id)result items:(NSMutableArray*)items success:(SuccessBlock)success failure:(FailureBlock)failure
{
    // Result is not an object with dataName property, return as is
    if (!self.dataName || ![result isKindOfClass:[NSDictionary class]] || ![result[self.dataName] isKindOfClass:[NSArray class]]) {
        if (success) success(result);
        return;
    }
    
    // Perform pagination and collect all items
    for (id item in [BKjs toArray:result name:self.dataName]) [items addObject:item];
    NSString *url = [self getDataNextURL:result];
    if (url && url.length) {
        [BKjs sendRequest:url method:@"GET" params:nil headers:self.headers body:nil success:^(id result) {
            [self processResult:result items:items success:success failure:failure];
        } failure:failure];
        return;
    }
    NSMutableDictionary *rc = [@{ self.dataName: items } mutableCopy];
    // Copy all other properties except the items list
    for (id key in result) if (![key isEqual:self.dataName]) rc[key] = result[key];
    if (success) success(rc);
}

- (void)login:(ErrorBlock)finished
{
    if ([self.type isEqual:@"oauth1"]) {
        [self authorize1:finished];
    } else
    if ([self.type isEqual:@"oauth2"]) {
        [self authorize2:finished];
    } else {
        NSURLRequest *request = [self getAuthorizeRequest:nil];
        [self showWebView:request completionHandler:^(NSURLRequest *req, NSError *error) { finished(error); }];
    }
}

- (void)logout
{
    self.account = [@{} mutableCopy];
    self.accessToken = nil;
    [BKjs deletePasswordForService:self.clientId account:self.name error:nil];
    [self clearCookies];
}

- (void)enableCookies
{
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
}

- (void)clearCookies
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:self.baseURL]];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
}

- (void)showWebView:(NSURLRequest*)request completionHandler:(WebViewCompletionBlock)completionHandler
{
    Debug(@"%@", [request URL]);
    
    self.accessToken = nil;
    if (!self.loginView) self.loginView = [BKWebViewController initWithDelegate:self completionHandler:nil];
    [self enableCookies];
    [self.loginView start:request completionHandler:completionHandler];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    Debug(@"%@", [request URL]);
    
    if ([[[request URL] absoluteString] hasPrefix:self.redirectURL]) {
        return [self parseRedirectURL:request];
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    Debug(@"%@", [webView.request URL]);
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    Debug(@"%@", [webView.request URL]);
    
    [self.loginView show];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSString* url = error.userInfo[@"NSURLErrorFailingURLErrorKey"];
    if (![url hasPrefix:self.redirectURL]) {
        Logger(@"%@: %@", [webView.request URL], error);
        // Schedule block due to the webview being slow closing
        [BKjs scheduleBlock:0.5 block:^(id obj) {
            [self.loginView finish:webView.request error:error];
        } params:nil];
    }
}

- (NSMutableURLRequest*)getRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params
{
    return [[BKjs get] requestWithMethod:method path:path parameters:params];
}

#pragma mark OAUTH 2

- (void)authorize2:(ErrorBlock)finished
{
    NSMutableURLRequest *request = [self getAuthorizeRequest:nil];
    [self showWebView:request completionHandler:^(NSURLRequest *request, NSError *error) {
        NSDictionary *query = [BKjs parseQueryString:[[request URL] query]];
        if (error || !query[@"code"]) {
            finished(error ? error : [NSError errorWithDomain:@"OAUTH" code:500 userInfo:@{ @"message": @"no code" }]);
            return;
        }
        self.oauthCode = query[@"code"];
        request = [self getAccessTokenRequest:nil];
        [BKjs sendRequest:request success:^(NSDictionary *json) {
            self.accessToken = [BKjs toString:json name:self.accessTokenName];
            self.refreshToken = [BKjs toString:json name:self.refreshTokenName];
            if (self.expiresName) self.oauthExpires = [query num:self.expiresName];
            finished(nil);
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            finished(error);
        }];
    }];
}

#pragma mark OAUTH 1

- (NSMutableDictionary *)oauthParameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"oauth_version"] = @"1.0";
    params[@"oauth_signature_method"] = self.oauthSignature;
    params[@"oauth_consumer_key"] = self.clientId;
    params[@"oauth_timestamp"] = [@(floor([[NSDate date] timeIntervalSince1970])) stringValue];
    params[@"oauth_nonce"] = [BKjs getUUID];
    if (self.oauthRealm) params[@"realm"] = self.oauthRealm;
    return params;
}

- (void)authorize1:(ErrorBlock)finished
{
    [self getRequestToken:self.scope success:^(NSMutableDictionary *requestToken) {
        NSMutableURLRequest *request = [self getAuthorizeRequest:@{ @"oauth_token": [BKjs toString:requestToken name:@"oauth_token"] }];
        [request setHTTPShouldHandleCookies:NO];
        Logger(@"%@", requestToken);
        
        [self showWebView:request completionHandler:^(NSURLRequest *request, NSError *error) {
            NSURL *url = [request URL];
            NSDictionary *query = [BKjs parseQueryString:[url query]];
            if (query[@"oauth_verifier"]) requestToken[@"oauth_verifier"] = query[@"oauth_verifier"];
            
            [self getAccessToken:requestToken success:^(NSMutableDictionary *accessToken) {
                if (accessToken) {
                    self.oauthToken = accessToken;
                    finished(nil);
                } else {
                    finished(nil);
                }
            } failure:^(NSError *error) {
                finished(error);
            }];
        }];
        
    } failure:^(NSError *error) {
        finished(error);
    }];
}

- (void)getRequestToken:(NSString *)scope success:(SuccessBlock)success failure:(ErrorBlock)failure
{
    NSMutableDictionary *params = [self oauthParameters];
    params[@"oauth_callback"] = self.redirectURL;
    if (scope && !self.accessToken) params[@"scope"] = scope;
    
    NSMutableURLRequest *request = [self getRequestTokenRequest:params];
    [request setHTTPBody:nil];
    AFHTTPRequestOperation *operation = [[BKjs get] HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            NSMutableDictionary *requestToken = [BKjs parseQueryString:operation.responseString];
            success(requestToken);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        Logger(@"%@: error: %@", request.URL, error);
        if (failure) failure(error);
    }];
    [[BKjs get] enqueueHTTPRequestOperation:operation];
}

- (void)getAccessToken:(NSMutableDictionary *)requestToken success:(SuccessBlock)success failure:(ErrorBlock)failure
{
    if (requestToken && requestToken[@"oauth_token"] && requestToken[@"oauth_verifier"]) {
        self.oauthToken = requestToken;
        
        NSMutableDictionary *params = [self oauthParameters];
        params[@"oauth_token"] = requestToken[@"oauth_token"];
        params[@"oauth_verifier"] = requestToken[@"oauth_verifier"];
        NSMutableURLRequest *request = [self getAccessTokenRequest:params];
        AFHTTPRequestOperation *operation = [[BKjs get] HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (success) {
                NSMutableDictionary *accessToken = [BKjs parseQueryString:operation.responseString];
                success(accessToken);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            Logger(@"%@: error: %@", request.URL, error);
            if (failure) failure(error);
        }];
        [[BKjs get] enqueueHTTPRequestOperation:operation];
    } else {
        NSError *error = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:NSURLErrorBadServerResponse userInfo:@{ NSLocalizedFailureReasonErrorKey: @"Bad OAuth response received from the server" }];
        if (failure) failure(error);
    }
}

- (NSMutableURLRequest *)getRequestOAuth1:(NSString *)method path:(NSString *)path params:(NSDictionary *)parameters
{
    NSMutableDictionary *params = parameters ? [parameters mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary *aparams = [NSMutableDictionary dictionary];
    NSString *token = self.oauthToken ? self.oauthToken[@"oauth_token"] : nil;
    NSString *secret = [BKjs toString:self.oauthToken name:@"oauth_token_secret"];
    
    if (token) {
        [aparams addEntriesFromDictionary:[self oauthParameters]];
        aparams[@"oauth_token"] = token;
    }
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"oauth_"]) aparams[key] = obj;
    }];
    [params addEntriesFromDictionary:aparams];
    
    if ([self.oauthSignature isEqual:@"PLAINTEXT"]) {
        aparams[@"oauth_signature"] = [NSString stringWithFormat:@"%@&%@", self.clientSecret, secret];
    }
    
    if ([self.oauthSignature isEqual:@"HMAC-SHA1"]) {
        NSMutableURLRequest *request = [[BKjs get] requestWithMethod:method path:path parameters:params];
        NSString *secretString = [NSString stringWithFormat:@"%@&%@", [BKjs escapeString:self.clientSecret], [BKjs escapeString:secret]];
        NSData *secretData = [secretString dataUsingEncoding:NSUTF8StringEncoding];
        
        NSString *queryString = [BKjs escapeString:[[[[[request URL] query] componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@"&"]];
        NSString *requestString = [NSString stringWithFormat:@"%@&%@&%@", [request HTTPMethod], [BKjs escapeString:[[[request URL] absoluteString] componentsSeparatedByString:@"?"][0]], queryString];
        NSData *requestData = [requestString dataUsingEncoding:NSUTF8StringEncoding];
        
        uint8_t digest[CC_SHA1_DIGEST_LENGTH];
        CCHmacContext cx;
        CCHmacInit(&cx, kCCHmacAlgSHA1, secretData.bytes, secretData.length);
        CCHmacUpdate(&cx, requestData.bytes, requestData.length);
        CCHmacFinal(&cx, digest);
        aparams[@"oauth_signature"] = [BKjs toBase64:[NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH]];
    }
    
    NSArray *components = [[AFQueryStringFromParametersWithEncoding(aparams, NSUTF8StringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *component in components) {
        NSArray *parts = [component componentsSeparatedByString:@"="];
        if (parts.count != 2) continue;
        [items addObject:[NSString stringWithFormat:@"%@=\"%@\"", parts[0], parts[1]]];
    }
    NSString *authHeader = [NSString stringWithFormat:@"OAuth %@", [items componentsJoinedByString:@", "]];
    
    params = [parameters mutableCopy];
    for (NSString *key in parameters) {
        if ([key hasPrefix:@"oauth_"]) [params removeObjectForKey:key];
    }
    Logger(@"%@: %@: %@", path, authHeader, params);

    NSMutableURLRequest *request = [[BKjs get] requestWithMethod:method path:path parameters:params];
    [request setValue:authHeader forHTTPHeaderField:@"Authorization"];
    [request setHTTPShouldHandleCookies:NO];
    return request;
}

@end;
