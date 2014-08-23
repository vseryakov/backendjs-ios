//
//  BKSocialAccount.m
//
//  Created by Vlad Seryakov on 12/1/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKSocialAccount.h"

static NSMutableDictionary *_accounts;

@implementation BKQueryParams

- (instancetype)init:(NSString*)path params:(NSDictionary*)params defaults:(NSDictionary*)defaults
{
    self = [super init];
    self.path = path ? path : @"";
    self.params = [@{} mutableCopy];
    for (id key in params) self.params[key] = params[key];
    [self format:defaults];
    return self;
}

- (void)format:(NSDictionary*)defaults
{
    for (id key in defaults) {
        if (!self.params[key]) self.params[key] = defaults[key];
    }
    // Collect all params that should be present in the path so we need to remove them from the query
    NSMutableArray *clear = [@[] mutableCopy];
    for (id key in self.params) {
        if ([self.path rangeOfString:[NSString stringWithFormat:@"@%@@", key]].location != NSNotFound) [clear addObject:key];
    }
    self.path = [BKjs processTemplate:self.path params:self.params];
    [self.params removeObjectsForKeys:clear];
}

@end

@interface BKSocialAccount () <UIWebViewDelegate>
@property (nonatomic, strong) BKWebViewController *loginView;
@property (nonatomic, strong) NSString *oauthRealm;
@property (nonatomic, strong) NSString *oauthSignature;
@end

@implementation BKSocialAccount

+ (NSMutableDictionary*)accounts
{
    if (!_accounts) _accounts = [@{} mutableCopy];
    return _accounts;
}

+ (void)refresh
{
    for (id key in _accounts) [_accounts[key] refreshToken];
}

- (id)init:(NSString*)name
{
    return [self init:name clientId:nil];
}

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init];
    self.name = name;
    self.type = @"web";
    self.clientId = clientId ? clientId : [[NSBundle mainBundle] objectForInfoDictionaryKey:[NSString stringWithFormat:@"%@AppID", self.name]];
    self.redirectURL = [NSString stringWithFormat:@"http://%@/oauth/%@", BKjs.appDomain, self.clientId];
    self.oauthSignature = @"HMAC-SHA1";
    self.account = [@{} mutableCopy];
    self.oauthState = [BKjs getUUID];
    self.headers = [@{} mutableCopy];
    self.accessToken = [@{} mutableCopy];
    [[BKSocialAccount accounts] setObject:self forKey:self.name];
    [self restoreToken];
    return self;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: type=%@, open=%d", self.name, self.type, [self isValid]];
}

- (BOOL)isValid
{
    if ([self.type isEqual:@"oauth1"]) return ![self.accessToken isEmpty:@"oauth_token"];
    return ![self.accessToken isEmpty:@"access_token"];
}

- (void)saveToken
{
    [BKjs setPassword:[BKjs toJSONString:self.accessToken] forService:self.clientId account:self.name error:nil];
}

- (void)restoreToken
{
    NSDictionary *token = [BKjs toJSONObject:[BKjs passwordForService:self.clientId account:self.name error:nil]];
    [self.accessToken removeAllObjects];
    for (id key in token) self.accessToken[key] = token[key];
}

- (void)refreshToken
{
    Logger(@"%@: %@", self.name, self.accessToken);
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

#pragma mark Data access

- (NSError*)getError:(NSDictionary*)params
{
    if (params && params[@"error"]) {
        return [NSError errorWithDomain:self.name
                                   code:-1
                               userInfo:@{ NSLocalizedDescriptionKey: params[@"error"],
                                           NSLocalizedFailureReasonErrorKey: [params str:@"error_description"] }];
    }
    return nil;
}

- (NSString*)getURL:(NSString *)method path:(NSString*)path params:(NSDictionary*)params
{
    return [NSString stringWithFormat:@"%@%@", self.baseURL, path];
}

- (NSDictionary*)getQuery:(NSString *)method path:(NSString*)path params:(NSDictionary*)params
{
    if ([self.type isEqual:@"oauth1"] || !self.accessToken[@"access_token"]) return params;
    NSMutableDictionary *query = [params ? params : @{} mutableCopy];
    query[@"access_token"] = self.accessToken[@"access_token"];
    return query;
}

- (NSArray*)getItems:(id)result params:(NSDictionary*)params
{
    return nil;
}

- (NSString*)getNextURL:(id)result params:(NSDictionary*)params
{
    return nil;
}

- (NSMutableURLRequest*)getRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params type:(NSString*)type
{
    [self setHeaders:method path:path params:params];
    if ([self.type isEqual:@"oauth1"]) {
        NSMutableDictionary *query = [@{} mutableCopy];
        for (NSString *key in params) {
            if (![key hasPrefix:@"oauth_"]) query[key] = params[key];
        }
        params = query;
    }
    NSMutableURLRequest *request = [BKjs makeRequest:method path:path params:params type:type];
    for (NSString* key in self.headers) [request setValue:self.headers[key] forHTTPHeaderField:key];
    return request;
}

- (void)sendRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params type:(NSString*)type success:(SuccessBlock)success failure:(FailureBlock)failure
{
    GenericBlock relogin = ^() {
        [self login:^(NSError *error) {
            if (![self isValid]) {
                Logger(@"%@: %@", self.name, error ? error : @"login error");
                if (failure) failure(error ? error.code : -1, error ? error.description : @"login error");
            } else {
                [self getResult:method
                           path:[self getURL:method path:path params:params]
                         params:[self getQuery:method path:path params:params]
                           type:type
                        success:success
                        failure:failure];
            }
        }];
    };
    
    if (![self isValid]) {
        relogin();
        return;
    }
    
    [self getResult:method
               path:[self getURL:method path:path params:params]
             params:[self getQuery:method path:path params:params]
               type:type
            success:success
            failure:^(NSInteger code, NSString *reason) {
                // Empty token means we have to relogin
                if (!self.accessToken.count) {
                    relogin();
                } else {
                    if (failure) failure(code, reason);
                }
            }];
}

- (void)getResult:(NSString*)method path:(NSString*)path params:(NSDictionary*)params type:(NSString*)type success:(SuccessBlock)success failure:(FailureBlock)failure
{
    if ([method isEqual:@"POST"]) {
        NSMutableURLRequest *request = [self getRequest:@"POST" path:path params:params type:type];
        [BKjs sendRequest:request success:success failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
            [self processResponse:response error:error json:json failure:failure];
        }];
        return;
    }
    
    NSMutableArray *items = [@[] mutableCopy];
    NSMutableURLRequest *request = [self getRequest:@"GET" path:path params:params type:type];
    [BKjs sendRequest:request success:^(id result) {
        [self processResult:result params:params items:items success:success failure:^(NSInteger code, NSString *reason) {
            if (failure) failure(code, reason);
        }];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        [self processResponse:response error:error json:json failure:failure];
    }];
}

- (void)processResult:(id)result params:(NSDictionary*)params items:(NSMutableArray*)items success:(SuccessBlock)success failure:(FailureBlock)failure
{
    // Perform pagination and collect all items
    NSArray *list = [self getItems:result params:params];
    if (list) {
        for (id item in list) [items addObject:item];
        NSString *url = [self getNextURL:result params:params];
        if (url && url.length) {
            NSMutableURLRequest *request = [self getRequest:@"GET" path:url params:nil type:nil];
            [BKjs sendRequest:request success:^(id result) {
                [self processResult:result params:params items:items success:success failure:failure];
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
                [self processResponse:response error:error json:json failure:failure];
            }];
        } else {
            success(items);
        }
        return;
    }
    success(result);
}

- (void)processResponse:(NSHTTPURLResponse*)response error:(NSError*)error json:(id)json failure:(FailureBlock)failure
{
    if (response.statusCode == 401) [self.accessToken removeAllObjects];
    if (failure) failure(response.statusCode, error.description);
}

#pragma mark Web Authentication

- (void)login:(ErrorBlock)finished
{
    [self.accessToken removeAllObjects];
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
    [self.account removeAllObjects];
    [self.accessToken removeAllObjects];
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
    
    if (!self.loginView) self.loginView = [BKWebViewController initWithDelegate:self completionHandler:nil];
    [self enableCookies];
    [self.loginView start:request completionHandler:completionHandler];
}

#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    Debug(@"%@", [request URL]);
    
    // Parse access token from the url or the data,
    if ([[[request URL] absoluteString] hasPrefix:self.redirectURL]) {
        // By default client-side OAuth 2.0 uses the url fragment in the redirect url
        [self.accessToken removeAllObjects];
        self.accessToken[@"mtime"] = @(BKjs.now);
        id token = [BKjs parseQueryString:[[request URL] fragment]];
        for (id key in token) self.accessToken[key] = token[key];
        
        // Try the query string in case when access token is in the parameters
        if (![self isValid]) {
            token = [BKjs parseQueryString:[[request URL] query]];
            for (id key in token) self.accessToken[key] = token[key];
        }
        Logger(@"%@", self.accessToken);
        [self saveToken];
        [self.loginView finish:request error:[self getError:self.accessToken]];
        return NO;
    }
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    Debug(@"%@", [webView.request URL]);
    
    [self.loginView show];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSString* url = error.userInfo[NSURLErrorFailingURLStringErrorKey];
    if (![url hasPrefix:self.redirectURL]) {
        Logger(@"%@: %@", url, error);
        // Schedule block due to the webview being slow closing
        [BKjs scheduleBlock:0.5 block:^(id obj) { [self.loginView finish:webView.request error:error]; } params:nil];
    }
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
            Logger(@"%@", json);
            for (id key in json) self.accessToken[key] = json[key];
            self.accessToken[@"mtime"] = @(BKjs.now);
            [self saveToken];
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
    [self getRequestToken:^{
        NSMutableURLRequest *request = [self getAuthorizeRequest:@{ @"oauth_token": [self.accessToken str:@"oauth_token"] }];
        [self showWebView:request completionHandler:^(NSURLRequest *request, NSError *error) {
            NSDictionary *query = [BKjs parseQueryString:[[request URL] query]];
            if (query[@"oauth_verifier"]) self.accessToken[@"oauth_verifier"] = query[@"oauth_verifier"];
            [self getAccessToken:^{
                self.accessToken[@"mtime"] = @(BKjs.now);
                [self saveToken];
                finished(nil);
            } failure:finished];
        }];
    } failure:finished];
}

- (void)getRequestToken:(GenericBlock)success failure:(ErrorBlock)failure
{
    NSMutableDictionary *params = [self oauthParameters];
    params[@"oauth_callback"] = self.redirectURL;
    if (self.scope && ![self isValid]) params[@"scope"] = self.scope;
    
    NSMutableURLRequest *request = [self getRequestTokenRequest:params];
    [request setHTTPBody:nil];
    AFHTTPRequestOperation *operation = [[BKjs get] HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            id token = [BKjs parseQueryString:operation.responseString];
            for (id key in token) self.accessToken[key] = token[key];
            Logger(@"%@", self.accessToken);
            success();
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        Logger(@"%@: error: %@", request.URL, error);
        [self.accessToken removeAllObjects];
        if (failure) failure(error);
    }];
    [[BKjs get] enqueueHTTPRequestOperation:operation];
}

- (void)getAccessToken:(GenericBlock)success failure:(ErrorBlock)failure
{
    if (self.accessToken[@"oauth_token"] && self.accessToken[@"oauth_verifier"]) {
        NSMutableDictionary *params = [self oauthParameters];
        params[@"oauth_token"] = self.accessToken[@"oauth_token"];
        params[@"oauth_verifier"] = self.accessToken[@"oauth_verifier"];
        NSMutableURLRequest *request = [self getAccessTokenRequest:params];
        AFHTTPRequestOperation *operation = [[BKjs get] HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (success) {
                id token = [BKjs parseQueryString:operation.responseString];
                for (id key in token) self.accessToken[key] = token[key];
                Logger(@"%@", self.accessToken);
                success();
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            Logger(@"%@: error: %@", request.URL, error);
            [self.accessToken removeAllObjects];
            if (failure) failure(error);
        }];
        [[BKjs get] enqueueHTTPRequestOperation:operation];
    } else {
        NSError *error = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:NSURLErrorBadServerResponse userInfo:@{ NSLocalizedFailureReasonErrorKey: @"Bad OAuth response received from the server" }];
        [self.accessToken removeAllObjects];
        if (failure) failure(error);
    }
}

- (void)setHeaders:(NSString *)method path:(NSString *)path params:(NSDictionary *)parameters
{
    if ([self.type isEqual:@"oauth1"]) {
        NSMutableDictionary *params = parameters ? [parameters mutableCopy] : [NSMutableDictionary dictionary];
        NSMutableDictionary *aparams = [NSMutableDictionary dictionary];
        NSString *secret = [self.accessToken str:@"oauth_token_secret"];
        
        if (self.accessToken[@"oauth_token"]) {
            [aparams addEntriesFromDictionary:[self oauthParameters]];
            aparams[@"oauth_token"] = self.accessToken[@"oauth_token"];
        }
        [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"oauth_"]) aparams[key] = obj;
        }];
        [params addEntriesFromDictionary:aparams];
        
        if ([self.oauthSignature isEqual:@"PLAINTEXT"]) {
            aparams[@"oauth_signature"] = [NSString stringWithFormat:@"%@&%@", self.clientSecret, secret];
        }
        
        if ([self.oauthSignature isEqual:@"HMAC-SHA1"]) {
            NSString *secretString = [NSString stringWithFormat:@"%@&%@", [BKjs escapeString:self.clientSecret], [BKjs escapeString:secret]];
            NSData *secretData = [secretString dataUsingEncoding:NSUTF8StringEncoding];
            
            NSString *str = [NSString stringWithFormat:@"%@&%@&%@", method, [BKjs escapeString:path], [BKjs escapeString:[BKjs makeQuery:params]]];
            NSData *requestData = [str dataUsingEncoding:NSUTF8StringEncoding];

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
        self.headers[@"Authorization"] = [NSString stringWithFormat:@"OAuth %@", [items componentsJoinedByString:@", "]];
    }
}

#pragma mark Methods to override

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implemented"); }
- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implemented"); }
- (void)getPhotos:(NSDictionary*)album params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implemented"); }
- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implemented"); }
- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure { if (failure) failure(-1, @"not implemented"); };
- (void)sendMessage:(NSString*)subject body:(NSString*)body params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure{ if (failure) failure(-1, @"not implemented"); };

- (NSMutableURLRequest*)getAuthorizeRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getAuthenticateRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getAccessTokenRequest:(NSDictionary*)params { return nil; }
- (NSMutableURLRequest*)getRequestTokenRequest:(NSDictionary*)params { return nil; }

@end;
