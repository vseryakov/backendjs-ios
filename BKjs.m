//
//  BKjs
//
//  Created by Vlad Seryakov on 7/04/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKjs.h"
#import <sys/sysctl.h>
#import <Security/Security.h>

static BKjs *_bkjs;
static CLLocationManager *_locationManager;
static CLLocation* _location;
static NSCache* _cache;
static NSMutableDictionary *_account;
static NSMutableDictionary *_images;
static NSMutableDictionary *_params;
static NSString* _appName;
static NSString* _appVersion;
static NSString* _serverVersion;
static NSString* _iOSVersion;
static NSString* _iOSPlatform;
static NSString *_iOSModel;

static NSString *SysCtlByName(char *typeSpecifier)
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    char *str = malloc(size);
    sysctlbyname(typeSpecifier, str, &size, NULL, 0);
    NSString *rc = [NSString stringWithCString:str encoding: NSUTF8StringEncoding];
    free(str);
    return rc;
}

@implementation BKjs

+ (instancetype)get
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{
        NSString *url = nil;
#ifdef BK_BASEURL
        url = [NSString stringWithFormat:@"%s", BK_BASEURL];
#endif
        if (!url || !url.length) url = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"BKBaseURL"];
        if (!url || !url.length) url = [NSString stringWithFormat:@"http://%@", [self appDomain]];
        
        _bkjs = [[self alloc] initWithBaseURL:[[NSURL alloc] initWithString:url ? url : @"http://google.com"]];
        _appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        _appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        _iOSVersion = [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0];
        _iOSPlatform = @"iPhone";
        
        _iOSModel = SysCtlByName("hw.machine");
        if ([_iOSModel isEqual:@"x86_64"] && BKScreenWidth >= 768) _iOSPlatform = @"iPad";
        if ([_iOSModel hasPrefix:@"iPad"]) _iOSPlatform = @"iPad";
        if ([_iOSModel hasPrefix:@"iPod"]) _iOSPlatform = @"iPod";

        _account = [@{} mutableCopy];
        _images = [@{} mutableCopy];
        _params = [@{} mutableCopy];
        _cache = [[NSCache alloc] init];

        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = _bkjs;
        [_locationManager setDesiredAccuracy:kCLLocationAccuracyKilometer];
        [_locationManager setDistanceFilter:1000];
        [_locationManager startUpdatingLocation];
        
        [_bkjs setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkStatusChanged" object:self userInfo:@{ @"status": @(status) }];
            });
        }];
    });
    return _bkjs;
}

+ (void)set:(BKjs*)obj
{
    _bkjs = obj;
}

#pragma mark Utilities

+ (void)setCredentials:(NSString *)login secret:(NSString*)secret
{
    [self setPassword:login forService:@"login" account:BKjs.appName error:nil];
    [self setPassword:secret forService:@"secret" account:BKjs.appName error:nil];
}

+ (long long)now
{
    return [[NSDate date] timeIntervalSince1970];
}

+ (NSMutableDictionary*)account
{
    return _account;
}

+ (NSMutableDictionary*)images
{
    return _images;
}

+ (NSMutableDictionary*)params
{
    return _params;
}

+ (NSString*)appName
{
    return _appName;
}

+ (NSString*)appVersion
{
    return _appVersion;
}

+ (NSString*)serverVersion
{
    return _serverVersion;
}

+ (NSString*)iOSModel
{
    return _iOSModel;
}

+ (NSString*)iOSVersion
{
    return _iOSVersion;
}

+ (NSString*)iOSPlatform
{
    return _iOSPlatform;
}

+ (NSString*)appDomain
{
    NSString *bundle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSArray *domain = [bundle componentsSeparatedByString:@"."];
    if (domain.count > 1) return [NSString stringWithFormat:@"%@.%@", domain[1], domain[0]];
    return bundle;
}

+ (NSUserDefaults*)defaults
{
    return [NSUserDefaults standardUserDefaults];
}

+ (NSString *)documentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

+ (id)appDelegate
{
    return [[UIApplication sharedApplication] delegate];
}

+ (double)rand:(double)from to:(double)to
{
    return (((double)(arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * (to - from)) + from;
}

+ (BOOL)matchString:(NSString *)pattern string:(NSString*)string
{
    if (!pattern || !string) return NO;
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    if (regex == nil) {
        Logger(@"matchString: %@: %@", pattern, error);
        return NO;
    }
    return [regex numberOfMatchesInString:string options:0 range:NSMakeRange(0, string.length)] > 0;
}

+ (NSString*)getUUID
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return (NSString *)CFBridgingRelease(string);
}

+ (NSString*)strftime:(long long)seconds format:(NSString*)format
{
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:format ? format : @"EEE, MMM d, h:mm a"];
    return [fmt stringFromDate:now];
}

+ (NSInvocation*)getInvocation:(id)target name:(NSString*)name
{
    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(target), selector);
    if (method == NULL) return nil;
    struct objc_method_description* desc = method_getDescription(method);
    if (desc == NULL || desc->name == NULL) return nil;
    
    NSMethodSignature* sig = [NSMethodSignature signatureWithObjCTypes:desc->types];
    NSInvocation* inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setSelector:selector];
    [inv setTarget:target];
    return inv;
}

+ (void)invoke:(id)target name:(NSString*)name arg:(id)arg
{
    NSInvocation* inv = [BKjs getInvocation:target name:arg ? [NSString stringWithFormat:@"%@:", name ] : name];
    if (inv) {
        if (arg) [inv setArgument:&arg atIndex:2];
        [inv invoke];
    } else {
        Logger(@"ERROR: unknown method: %@ in %@", name, target);
    }
}

- (void)onBlockTimer:(NSTimer *)timer
{
    SuccessBlock block = timer.userInfo[@"block"];
    block(timer.userInfo[@"params"]);
}

+ (void)scheduleBlock:(double)seconds block:(SuccessBlock)block params:(id)params
{
    if (!block) return;
    [NSTimer scheduledTimerWithTimeInterval:seconds target:[BKjs get] selector:@selector(onBlockTimer:) userInfo:@{ @"block": [block copy],  @"params": params ? params : @{} } repeats:NO];
}

+ (void)initDefaultsFromSettings
{
    NSMutableDictionary *defaults = [@{} mutableCopy];
    NSArray *preferences = [[NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"] stringByAppendingPathComponent:@"Root.plist"]] objectForKey:@"PreferenceSpecifiers"];
    for (NSDictionary *item in preferences) {
        NSString *key = item[@"Key"];
        NSString *val = item[@"DefaultValue"];
        if (key && val) defaults[key] = val;
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSData*)getSystemLog:(long)secondsAgo
{
    NSMutableData *data = [NSMutableData dataWithLength:0];
    
    char mtime[256];
    sprintf(mtime, "%lu", time(0) - secondsAgo);
    
    aslmsg m, q = asl_new(ASL_TYPE_QUERY);
    NSString *app = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    asl_set_query(q, ASL_KEY_SENDER, [app cStringUsingEncoding:NSASCIIStringEncoding], ASL_QUERY_OP_EQUAL);
    asl_set_query(q, ASL_KEY_TIME, mtime, ASL_QUERY_OP_GREATER | ASL_QUERY_OP_NUMERIC);
    aslresponse r = asl_search(NULL, q);
    while ((m = aslresponse_next(r))) {
        const char *val = asl_get(m, ASL_KEY_TIME);
        if (val) [data appendBytes:val length:strlen(val)];
        [data appendBytes:" " length:1];
        val = asl_get(m, ASL_KEY_MSG);
        if (val) [data appendBytes:val length:strlen(val)];
        [data appendBytes:"\n" length:1];
    }
    aslresponse_free(r);
    return data;
}

+ (NSMutableDictionary*)mergeParams:(NSDictionary*)item params:(NSDictionary*)params
{
    NSMutableDictionary *rc = [@{} mutableCopy];
    for (id key in item) rc[key] = item[key];
    for (id key in params) if (!rc[key]) rc[key] = params[key];
    return rc;
}

#pragma mark Generic dictionary access

+ (BOOL)isEmpty:(id)obj
{
    return [BKjs toString:obj].length == 0;
}

+ (BOOL)isEmpty:(id)obj name:(NSString*)name
{
    if (!obj || ![obj isKindOfClass:[NSDictionary class]]) return YES;
    id val = obj[name];
    return val == nil || [BKjs toString:val].length == 0;
}

+ (BOOL)toBool:(id)obj
{
    NSString *rc = [BKjs toString:obj];
    if ([BKjs matchString:@"1|t|true|yes" string:rc]) return YES;
    return NO;
}

+ (NSString*)toString:(id)obj
{
    return [NSString stringWithFormat:@"%@", obj == nil ? @"" : obj];
}

+ (double)toNumber:(id)obj
{
    return [[BKjs toString:obj] doubleValue];
}

+ (NSArray*)toArray:(id)obj name:(NSString*)name
{
    if (![obj isKindOfClass:[NSDictionary class]]) return @[];
    id rc = obj[name];
    if (![rc isKindOfClass:[NSArray class]]) return @[];
    return rc;
}

+ (NSString*)toString:(id)obj name:(NSString*)name
{
    if (![obj isKindOfClass:[NSDictionary class]]) return @"";
    return [BKjs toString:obj[name]];
}

+ (double)toNumber:(id)obj name:(NSString*)name
{
    if (![obj isKindOfClass:[NSDictionary class]]) return 0;
    if ([name length] == 0) {
        return 0;
    }
    
    return [BKjs toNumber:obj[name]];
}

+ (NSDictionary*)toDictionary:(id)obj name:(NSString*)name
{
    if (![obj isKindOfClass:[NSDictionary class]]) return @{};
    id rc = obj[name];
    if (![rc isKindOfClass:[NSDictionary class]]) return @{};
    return rc;
}

+ (NSMutableDictionary*)toDictionary:(id)obj params:(NSDictionary*)params
{
    NSMutableDictionary *rc = [@{} mutableCopy];
    if ([obj isKindOfClass:[NSDictionary class]]) for (id key in obj) rc[key] = obj[key];
    for (id key in params) rc[key] = params[key];
    return rc;
}

+ (NSArray*)toDictionaryArray:(id)obj name:(NSString*)name field:(NSString*)field
{
    return [BKjs toArray:[BKjs toDictionary:obj name:name] name:field];
}

+ (NSString*)toDictionaryString:(id)obj name:(NSString*)name field:(NSString*)field
{
    return [BKjs toString:[BKjs toDictionary:obj name:name] name:field];
}

+ (NSString*)toString:(id)obj names:(NSArray*)names dflt:(NSString*)dflt
{
    for (NSString *key in names) {
        if (obj[key]) return [obj str:key];
    }
    return dflt;
}

+ (double)toNumber:(id)obj names:(NSArray*)names dflt:(double)dflt
{
    for (NSString *key in names) {
        if (obj[key]) return [obj num:key];
    }
    return dflt;
}

#pragma mark Query parser

+ (NSMutableDictionary *)parseQueryString:(NSString *)query
{
    NSMutableDictionary *dict = [@{} mutableCopy];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [dict setObject:val forKey:key];
    }
    return dict;
}

+ (NSString *)escapeString:(NSString  *)string
{
	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)@"[].", (__bridge CFStringRef)@":/?&=;+!@#$()',*", kCFStringEncodingUTF8);
}

+ (NSString*)toHmacSHA1:(NSData*)data secret:(NSString*)secret
{
    unsigned char hmac[20];
    NSData *secretData = [secret dataUsingEncoding:NSUTF8StringEncoding];
    CCHmac(kCCHmacAlgSHA1, [secretData bytes], [secretData length], [data bytes], [data length], hmac);
    return [BKjs toBase64:[NSData dataWithBytes:hmac length:sizeof(hmac)]];
}

+ (NSString*)toBase64:(NSData*)data
{
    return [data base64EncodedStringWithOptions:0];
}

+ (NSData*)fromBase64:(NSString*) string
{
    return [[NSData alloc] initWithBase64EncodedString:string options:0];
}

+ (NSMutableURLRequest *)makeRequest:(NSString *)method path:(NSString *)path params:(NSDictionary *)params
{
    NSURL *url = [NSURL URLWithString:path relativeToURL:[BKjs get].baseURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];
    [request setTimeoutInterval:30];
    if (!params) return request;
    
    if ([method isEqual:@"GET"] || [method isEqual:@"HEAD"] || [method isEqual:@"DELETE"]) {
        url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:[path rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", [BKjs makeQuery:params]]];
        [request setURL:url];
    } else {
        [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[[BKjs makeQuery:params] dataUsingEncoding:NSUTF8StringEncoding]];
    }
	return request;
}

+ (NSString*)makeQuery:(NSDictionary*)params
{
    NSMutableArray *list = [@[] mutableCopy];
    for (NSString *key in params.allKeys) {
        NSString* val = [[BKjs escapeString:[params str:key]] stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
        [list addObject:[NSString stringWithFormat:@"%@=%@", key, val]];
    }
    NSString *query = [[list sortedArrayUsingComparator:^(NSString *a, NSString *b) { return [a compare:b]; }] componentsJoinedByString:@"&"];
    return query;
}

#pragma mark API requests

// Build full URL and check
- (NSString*)getURL:(NSString*)path
{
    return path;
}

+ (void)parseServerVersion:(NSHTTPURLResponse*)response
{
    if (_serverVersion || !response) return;
    NSString *hdr = response.allHeaderFields[@"Server"];
    if (!hdr) return;
    NSArray *v = [hdr componentsSeparatedByString:@"/"];
    _serverVersion = v.count > 0 ? v[v.count-1] : nil;
}

+ (NSDictionary*)sign:(NSString*)path method:(NSString*)method params:(NSDictionary*)params contentType:(NSString*)contentType expires:(NSTimeInterval)expires checksum:(NSString*)checksum
{
    NSMutableDictionary *rc = [@{} mutableCopy];
    if (!checksum) checksum = @"";
    if (!method) method = @"GET";
    if (!contentType) contentType = @"application/x-www-form-urlencoded";
    
    // Default expiration if not specified
    if (expires == 0) expires = 30;
    NSNumber *expire = [NSNumber numberWithLongLong:([BKjs now] + expires) * 1000];
    
    // Local date for the API to use proper timezone
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    rc[@"Date"] = [dateFormatter stringFromDate:[NSDate date]];
    
    // Content type must be in the signature and the headers
    rc[@"Content-Type"] = contentType;
    
    NSString *req = path;
    // Setup query params, use from the path if no in params
    NSString *query = params && [contentType hasPrefix:@"application/x-www-form-urlencoded"] ? [BKjs makeQuery:params] : @"";
    NSArray *q = query.length == 0 ? [path componentsSeparatedByString:@"?"] : @[];
    if (q.count > 1) {
        req = q[0];
        NSArray *pairs = [q[1] componentsSeparatedByString:@"&"];
        query = [[pairs sortedArrayUsingComparator:^(NSString *a, NSString *b) { return [a compare:b]; }] componentsJoinedByString:@"&"];
    }
    NSURL *url = [NSURL URLWithString:req relativeToURL:[BKjs get].baseURL];
    NSString *login = [self passwordForService:@"login" account:BKjs.appName error:nil];
    NSString *secret = [self passwordForService:@"secret" account:BKjs.appName error:nil];
    
    NSString *str = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n%@\n",method,url.host,url.path,query,expire,[contentType lowercaseString],checksum];
    NSString *sig = [BKjs toHmacSHA1:[str dataUsingEncoding:NSUTF8StringEncoding] secret:secret];
    rc[@"bk-signature"] = [NSString stringWithFormat:@"1||%@|%@|%@|%@|", login, sig, [expire stringValue], checksum];
    //Debug(@"%@: %@", str, rc);
    return rc;
}

+ (void)sendQuery:(NSString *)path method:(NSString*)method params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    path = [[BKjs get] getURL:path];
    NSDictionary *headers = [BKjs sign:path method:method params:params contentType:nil expires:0 checksum:nil];
    [BKjs sendRequest:path method:method params:params headers:headers body:nil success:success failure:failure];
}

+ (void)sendJSON:(NSString*)path method:(NSString*)method params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSError *error = nil;
    path = [[BKjs get] getURL:path];
    NSDictionary *headers = [BKjs sign:path method:method params:nil contentType:@"application/json; charset=UTF-8" expires:0 checksum:nil];
    NSData *body = [NSJSONSerialization dataWithJSONObject:params options:(NSJSONWritingOptions)0 error:&error];
    if (error) Logger(@"%@: %@", path, error);
    [BKjs sendRequest:path method:method params:nil headers:headers body:body success:success failure:failure];
}

+ (void)sendRequest:(NSString*)path method:(NSString*)method params:(NSDictionary*)params headers:(NSDictionary*)headers body:(NSData*)body success:(SuccessBlock)success failure:(FailureBlock)failure
{
    if (!method) method = @"GET";
    
    NSMutableURLRequest *request = [BKjs makeRequest:method path:path params:params];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];

    if (body) [request setHTTPBody:body];
    request.timeoutInterval = 30;
    
    [self sendRequest:request success:success failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        NSString *reason = [BKjs toString:json name:@"message"];
        if (reason.length == 0) reason = error.description;
        if (failure) failure(response.statusCode, reason);
    }];
}

+ (void)sendRequest:(NSURLRequest*)request success:(SuccessBlock)success failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure
{
    Logger(@"url=%@", request.URL);
    
    AFJSONRequestOperation *op = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id json) {
        [self parseServerVersion:response];
        if (success) success(json);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        Logger(@"url=%@, status=%ld, response: %@", request.URL, (long)response.statusCode, json ? json : error);
        [self parseServerVersion:response];
        if (failure) failure(request, response, error, json);
    }];
    [[BKjs get].operationQueue addOperation:op];
}

+ (void)getImage:(NSString*)url request:(NSURLRequest*)request success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    if (url == nil || url.length == 0) {
        if (failure) failure(0, @"no url provided");
        return;
    }
    if (!request) request = [[BKjs get] requestWithMethod:@"GET" path:url parameters:nil];
    [BKjs getImage:request success:success failure:failure];
}

+ (void)getImage:(NSURLRequest*)request success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    if (![request isKindOfClass:[NSURLRequest class]]) {
        if (failure) failure(-1, @"invalid request");
        return;
    }
    
    NSString *url = request.URL.absoluteString;
    if ([request.HTTPMethod isEqual:@"POST"]) {
        NSString *type = [request valueForHTTPHeaderField:@"Content-Type"];
        if (type && [type hasPrefix:@"application/x-www-form-urlencoded"]) {
            url = [url stringByAppendingString:[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding]];
        }
    }
    
    UIImage *cached = [[BKjs get] getCachedImage:url];
    if (cached) {
        if (success) success(cached, request.URL.absoluteString);
        return;
    }
    
    Logger(@"%@", request);
    
    AFImageRequestOperation *op = [AFImageRequestOperation
                                   imageRequestOperationWithRequest:request
                                   imageProcessingBlock:^UIImage *(UIImage *image) {
                                       return image;
                                   }
                                   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                       [self parseServerVersion:response];
                                       [[BKjs get] cacheImage:request.URL.absoluteString image:image];
                                       if (success) success(image, request.URL.absoluteString);
                                   }
                                   failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                       [self parseServerVersion:response];
                                       Logger(@"%@: error: %ld: %@", request.URL, (long)response.statusCode, error);
                                       if (failure) failure(response.statusCode, error.description);
                                   }];
    [[BKjs get].operationQueue addOperation:op];
}

# pragma Icon API

+ (void)getIcon:(NSString*)path params:(NSDictionary*)params success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    path = [[BKjs get] getURL:path];
    NSDictionary *headers = [BKjs sign:path method:@"GET" params:params contentType:nil expires:0 checksum:nil];
    NSMutableURLRequest *request = [BKjs makeRequest:@"GET" path:[[BKjs get] getURL:path] params:params];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    [BKjs getImage:request success:success failure:failure];
}

+ (void)getIcon:(NSString*)url success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url relativeToURL:[BKjs get].baseURL]];
    [request setTimeoutInterval:30];
    NSDictionary *headers = [BKjs sign:request.URL.absoluteString method:@"GET" params:nil contentType:nil expires:0 checksum:nil];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    [BKjs getImage:request success:success failure:failure];
}

#pragma mark Image cache

- (UIImage*)getCachedImage:(NSString*)url
{
    return url ? [_cache objectForKey:url] : nil;
}

- (void)cacheImage:(NSString*)url image:(UIImage*)image
{
    if (url && image) [_cache setObject:image forKey:url];
}

- (void)uncacheImage:(NSString*)url
{
    if (url) [_cache removeObjectForKey:url];
}

#pragma mark Account Icon API

+ (void)getAccountIcons:(NSDictionary*)params success:(ArrayBlock)success failure:(GenericBlock)failure
{
    [BKjs sendQuery:@"/account/select/icon"
             method:@"POST"
             params:params
            success:^(NSArray *json) {
                if (success) success([json isKindOfClass:[NSArray class]] ? json : @[]);
            }
            failure:failure];
}

+ (void)getAccountIcon:(NSDictionary*)params success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    [self getIcon:@"/account/get/icon" params:params success:success failure:failure];
}

// Sending nil image will delete the icon for the given type
+ (void)putAccountIcon:(UIImage*)image params:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    if (!image || ![image isKindOfClass:[UIImage class]]) {
        if (failure) failure(-1, @"invalid image");
        return;
    }
    
    NSMutableDictionary *query = [@{} mutableCopy];
    for (id key in params) query[key] = params[key];
    
    NSData *jpeg = UIImageJPEGRepresentation(image, 1.0);
    if (!jpeg) {
        Logger(@"cannot convert to JPEG: %@", image);
        if (failure) failure(-1, @"bad jpeg");
        return;
    }
    query[@"icon"] = [BKjs toBase64:jpeg];
    Logger(@"putAccountIcon: %gx%g: size=%d, %@", image.size.width, image.size.height, (int)jpeg.length, params);
    
    [BKjs sendJSON:@"/account/put/icon"
           method:@"POST"
           params:query
          success:success
          failure:failure];
}

+ (void)delAccountIcon:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/account/del/icon"
           method:@"POST"
           params:params
          success:success
          failure:failure];
}

#pragma mark Account API

+ (void)getAccount:(NSDictionary*)params success:(DictionaryBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/account/get"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              // Current account
              if ((!params || !params[@"id"]) && [json isKindOfClass:[NSDictionary class]]) {
                  for (NSString *key in json) BKjs.account[key] = json[key];
                  if (success) success(BKjs.account);
              } else {
                  if (success) success(json);
              }
          } failure:failure];
}

+ (void)addAccount:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/account/add"
           method:@"POST"
           params:params
            success:^(NSDictionary *json) {
                for (NSString *key in json) BKjs.account[key] = json[key];
                if (success) success(BKjs.account);
            }
          failure:failure];
}

+ (void)delAccount:(NSDictionary*)params success:(GenericBlock)success failure:(GenericBlock)failure
{
    [BKjs sendQuery:@"/account/del"
           method:@"POST"
           params:params
          success:success
          failure:failure];
}

+ (void)updateAccount:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/account/update"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              // Update local account record with the same field values
              for (NSString *key in params) BKjs.account[key] = params[key];
              if (success) success();
          }
          failure:failure];
}

#pragma mark Connection API
    
+ (void)getReference:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/reference/get"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success(json);
          }
          failure:failure];
}

+ (void)selectReference:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/reference/get"
             method:@"POST"
             params:params
            success:^(NSDictionary *json) {
                if (success) success([BKjs toArray:json name:@"data"]);
            }
            failure:failure];
}

+ (void)addConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/add"
           method:@"POST"
           params:params
          success:success
          failure:failure];
}

+ (void)getConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/get"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success(json);
          }
          failure:failure];
}

+ (void)selectConnection:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/select"
             method:@"POST"
             params:params
            success:^(NSDictionary *json) {
                if (success) success([BKjs toArray:json name:@"data"]);
            }
            failure:failure];
}

+ (void)updateConnection:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/update"
           method:@"POST"
           params:params
          success:success
          failure:failure];
}

+ (void)incrConnection:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/incr"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

#pragma mark - Message API

+ (void)getConversation:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [BKjs getSentMessages:params success:^(NSArray *list) {
        [BKjs getArchivedMessages:params success:^(NSArray *list2) {
            NSArray* rc = [list arrayByAddingObjectsFromArray:list2];
            rc = [rc sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                double m1 = [BKjs toNumber:a name:@"mtime"];
                double m2 = [BKjs toNumber:b name:@"mtime"];
                return m1 < m2 ? NSOrderedAscending : m1 > m2 ? NSOrderedDescending : NSOrderedSame;
            }];
            if (success) success(rc);
        } failure:failure];
    } failure:failure];
}

+ (void)getNewMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toArray:json name:@"data"]);
          }
          failure:failure];
}

+ (void)getSentMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get/sent"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toArray:json name:@"data"]);
          }
          failure:failure];
}

+ (void)getArchivedMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get/archive"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toArray:json name:@"data"]);
          }
          failure:failure];
}

+ (void)addMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSMutableDictionary* query = [@{} mutableCopy];
    for (id key in params) {
        if ([params[key] isKindOfClass:[UIImage class]]) {
            NSData* jpeg = UIImageJPEGRepresentation(params[key], 1.0);
            query[@"icon"] = [BKjs toBase64:jpeg];
        } else {
            query[key] = params[key];
        }
    }
    [self sendJSON:@"/message/add"
           method:@"POST"
           params:query
          success:success
          failure:failure];
}

+ (void)archiveMessage:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/archive"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delMessage:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delArchivedMessage:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del/archive"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delSentMessage:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del/sent"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)getMessageIcon:(NSDictionary*)params success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    [self getIcon:@"/message/image"
             params:params
            success:success
            failure:failure];
}

#pragma mark - Location API

+ (CLLocationManager*)locationManager
{
    return _locationManager;
}

+ (CLLocation*)location;
{
    return _location ? _location : [[CLLocation alloc] initWithLatitude:0 longitude:0];
}

+ (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    _location = [locations lastObject];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"LocationChanged" object:self userInfo:@{ @"location": _location }];
}

+ (void)putLocation:(CLLocation*)location params:(NSDictionary*)params success:(GenericBlock)success failure:(FailureBlock)failure
{
    Logger(@"putLocation: %g %g", location.coordinate.latitude, location.coordinate.longitude);
    
    [BKjs sendQuery:@"/location/put"
           method:@"POST"
           params:@{@"latitude" : @(location.coordinate.latitude),
                    @"longitude" : @(location.coordinate.longitude)}
          success:success
          failure:failure];
}

+ (void)getLocation:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/location/get"
           method:@"POST"
           params:params
          success:success
          failure:failure];
}

#pragma mark Keychain methods

+ (NSString*)keychainErrorString:(OSStatus)status
{
    switch (status) {
		case errSecSuccess: return nil;
		case errSecBadReq: return @"Bad parameter or invalid state for operation";
		case errSecUnimplemented: return @"Function or operation not implemented";
		case errSecParam: return @"One or more parameters passed to the function were not valid";
		case errSecAllocate: return @"Failed to allocate memory";
		case errSecNotAvailable: return @"No trust results are available";
		case errSecDuplicateItem: return @"The item already exists";
		case errSecItemNotFound: return @"The item cannot be found";
		case errSecInteractionNotAllowed: return @"Interaction with the Security Server is not allowed";
		case errSecDecode: return @"Unable to decode the provided data";
		case errSecAuthFailed: return @"Authorization/Authentication failed";
        case errSecUserCanceled: return @"User canceled the operation";
        case errSecIO: return @"I/O error";
		default: return @"Uknown error";
	}
}

+ (NSMutableDictionary *)keychainQueryForService:(NSString *)service account:(NSString *)account
{
    NSMutableDictionary *query = [@{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                     (__bridge id)kSecAttrAccount: account,
                                     (__bridge id)kSecAttrService: service } mutableCopy];
    return query;
}

+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error
{
    OSStatus status = errSecBadReq;
    NSString *result = nil;
    if (service && service.length > 0 && account && account.length > 0) {
        CFTypeRef passwd = NULL;
        NSMutableDictionary *query = [self keychainQueryForService:service account:account];
        [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
        [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

        status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&passwd);
        if (status != errSecSuccess) {
            if (status != errSecItemNotFound) Logger(@"ERROR: %@: %@: %d: %@", service, account, (int)status, [self keychainErrorString:status]);
            if (error != NULL) *error = [NSError errorWithDomain:@"Keychain" code:status userInfo:@{ @"message": [self keychainErrorString:status]}];
            return nil;
        }
        NSData *data = (__bridge_transfer NSData *)passwd;
        result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return result;
}


+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error
{
    OSStatus status = errSecBadReq;
    if (service && service.length > 0 && account && account.length > 0) {
        NSMutableDictionary *query = [self keychainQueryForService:service account:account];
        status = SecItemDelete((__bridge CFDictionaryRef)query);
    }
    if (status != errSecSuccess && error != NULL) {
        Logger(@"ERROR: %@: %@: %d: %@", service, account, (int)status, [self keychainErrorString:status]);
        if (error != NULL) *error = [NSError errorWithDomain:@"Keychain" code:status userInfo:@{ @"message": [self keychainErrorString:status]}];
    }
    return status == errSecSuccess;
}

+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account error:(NSError **)error
{
    OSStatus status = errSecBadReq;
    if (service && service.length > 0 && account && account.length > 0) {
        [self deletePasswordForService:service account:account error:nil];
        if (password && password.length > 0) {
            NSMutableDictionary *query = [self keychainQueryForService:service account:account];
            NSData *passwd = [password dataUsingEncoding:NSUTF8StringEncoding];
            [query setObject:passwd forKey:(__bridge id)kSecValueData];
            status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        }
    }
    if (status != errSecSuccess && error != NULL) {
        Logger(@"ERROR: %@: %@: %d: %@", service, account, (int)status, [self keychainErrorString:status]);
        if (error != NULL) *error = [NSError errorWithDomain:@"Keychain" code:status userInfo:@{ @"message": [self keychainErrorString:status]}];
    }
    return status == errSecSuccess;
}

@end

#pragma mark NSDictionary util

@implementation NSDictionary (util)

- (NSArray*)list:(NSString*)name
{
    id rc = self[name];
    if (!rc || ![rc isKindOfClass:[NSArray class]]) return @[];
    return rc;
}

- (NSDictionary*)dict:(NSString*)name
{
    id rc = self[name];
    if (!rc || ![rc isKindOfClass:[NSDictionary class]]) return @{};
    return rc;
}

- (NSString*)str:(NSString*)name
{
    return [BKjs toString:self[name]];
}

- (NSString*)str:(NSArray*)names dflt:(NSString*)dflt
{
    return [BKjs toString:self names:names dflt:dflt];
}

- (double)num:(NSArray*)names dflt:(double)dflt
{
    return [BKjs toNumber:self names:names dflt:dflt];
}

- (double)num:(NSString*)name
{
    return [BKjs toNumber:self[name]];
}

- (long long)llong:(NSString*)name
{
    return [BKjs toNumber:self[name]];
}

- (BOOL)bool:(NSString*)name
{
    return [BKjs toBool:self[name]];
}

- (BOOL)isEmpty:(NSString*)name
{
    return [BKjs isEmpty:self name:name];
}

@end;
