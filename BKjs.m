//
//  BKjs
//
//  Created by Vlad Seryakov on 7/04/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKjs.h"
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <pthread.h>
#import <stdint.h>

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
static NSString *_deviceToken;

static int _log_max = 0;
static NSMutableArray *_log;
static pthread_mutex_t _log_lock = PTHREAD_MUTEX_INITIALIZER;

void BKLog(NSString *format, ...)
{
    if (!format || !format.length) return;
    
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _log = [@[] mutableCopy]; });
    
    va_list ap;
    va_start(ap, format);
    NSLogv(format, ap);
    NSString *str = CFBridgingRelease(CFStringCreateWithFormatAndArguments(NULL, NULL, (CFStringRef)format, ap));
    va_end(ap);
    
    pthread_mutex_lock(&_log_lock);
    if (str && str.length) [_log addObject:str];
    if (_log.count > _log_max) {
        str = [_log componentsJoinedByString:@"\n"];
        [_log removeAllObjects];
    } else {
        str = nil;
    }
    pthread_mutex_unlock(&_log_lock);
    if (!str || !str.length) return;
    
    [BKjs sendJSON:@"/system/log"
            method:@"POST"
            params:@{ @"log": str,
                      @"id": [BKjs.account str:@"id"],
                      @"alias": [BKjs.account str:@"alias"] }
           success:nil
           failure:nil];
}

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

+ (instancetype)instance
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
        _bkjs.delegate = _bkjs;

        [_bkjs setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"BKNetworkStatusChangedNotification" object:self userInfo:@{ @"status": @(status) }];
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

+ (void)logout
{
    [self setCredentials:nil secret:nil];
    [self.account removeAllObjects];
}

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
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _account = [@{} mutableCopy]; });
    return _account;
}

+ (NSMutableDictionary*)images
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _images = [@{} mutableCopy]; });
    return _images;
}

+ (NSMutableDictionary*)params
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _params = [@{} mutableCopy]; });
    return _params;
}

+ (NSCache*)cache
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _cache = [[NSCache alloc] init]; });
    return _cache;
}

+ (NSString*)appName
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"]; });
    return _appName;
}

+ (NSString*)appVersion
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _appVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]; });
    return _appVersion;
}

+ (NSString*)serverVersion
{
    return _serverVersion;
}

+ (NSString*)iOSModel
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _iOSModel = SysCtlByName("hw.machine"); });
    return _iOSModel;
}

+ (NSString*)iOSVersion
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{ _iOSVersion = [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0]; });
    return _iOSVersion;
}

+ (NSString*)iOSPlatform
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{
        _iOSPlatform = @"iPhone";
        if ([self.iOSModel isEqual:@"x86_64"] && BKScreenWidth >= 768) _iOSPlatform = @"iPad";
        if ([self.iOSModel hasPrefix:@"iPad"]) _iOSPlatform = @"iPad";
        if ([self.iOSModel hasPrefix:@"iPod"]) _iOSPlatform = @"iPod";
    });
    return _iOSPlatform;
}

+ (NSString*)appDomain
{
    NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *domain = [bundle componentsSeparatedByString:@"."];
    if (domain.count > 1) return [NSString stringWithFormat:@"%@.%@", domain[1], domain[0]];
    return bundle;
}

+ (NSUserDefaults*)defaults
{
    return [NSUserDefaults standardUserDefaults];
}

+ (BOOL)checkDefaults:(NSString*)key
{
    if (![self.defaults boolForKey:key]) {
        [self.defaults setObject:@(1) forKey:key];
        [self.defaults synchronize];
        return NO;
    }
    return YES;
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

+ (NSString*)toDuration:(double)seconds format:(NSString*)fmt
{
    NSString *str = @"";
    if (seconds > 0) {
        int d = floor(seconds / 86400);
        int h = floor((seconds - d * 86400) / 3600);
        int m = floor((seconds - d * 86400 - h * 3600) / 60);
        if (d > 0) {
            str = [NSString stringWithFormat:@"%d day%@", d, d > 1 ? @"s" : @""];
            if (h > 0) str = [NSString stringWithFormat:@"%@ %d hour%@", str, h, h > 1 ? @"s" : @""];
            if (m > 0) str = [NSString stringWithFormat:@"%@ %d minute%@", str, m, m > 1 ? @"s" : @""];
        } else
        if (h > 0) {
            str = [NSString stringWithFormat:@"%d hour%@", h, h > 1 ? @"s" : @""];
            if (m > 0) str = [NSString stringWithFormat:@"%@ %d minute%@", str, m, m > 1 ? @"s" : @""];
        } else
        if (m > 0) {
            str = [NSString stringWithFormat:@"%d minute%@", m, m > 1 ? @"s" : @""];
        } else {
            str = [NSString stringWithFormat:@"%d seconds", (int)seconds];
        }
        if (fmt && str.length) str = [NSString stringWithFormat:fmt, str];
    }
    return str;
}

+ (NSString*)toAge:(double)mtime format:(NSString*)fmt
{
    NSString *str = @"";
    if (mtime > 0) {
        if (mtime > UINT32_MAX) mtime /= 1000;
        long long seconds = self.now - mtime;
        int d = floor(seconds / 86400);
        int h = floor((seconds - d * 86400) / 3600);
        int m = floor((seconds - d * 86400 - h * 3600) / 60);
        if (d > 0) {
            str = [NSString stringWithFormat:@"%d day%@", d, d > 1 ? @"s" : @""];
        } else
        if (h > 0) {
            str = [NSString stringWithFormat:@"%d hour%@", h, h > 1 ? @"s" : @""];
        } else
        if (m > 0) {
            str = [NSString stringWithFormat:@"%d minute%@", m, m > 1 ? @"s" : @""];
        } else {
            str = [NSString stringWithFormat:@"%d seconds", (int)MAX(0, seconds)];
        }
        if (fmt && str.length) str = [NSString stringWithFormat:fmt, str];
    }
    return str;
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

- (void)onBlock:(id)userInfo
{
    SuccessBlock block = userInfo[@"block"];
    if (block) block(userInfo[@"params"]);
}

- (void)onTimer:(NSTimer *)timer
{
    [self performSelectorOnMainThread:@selector(onBlock:) withObject:timer.userInfo waitUntilDone:NO];
}

+ (void)scheduleBlock:(double)seconds block:(SuccessBlock)block params:(id)params
{
    if (!block) return;
    [NSTimer scheduledTimerWithTimeInterval:seconds target:[self instance] selector:@selector(onTimer:) userInfo:@{ @"block": [block copy],  @"params": params ? params : @{} } repeats:NO];
}

+ (NSData*)getSystemLog:(long)secondsAgo
{
    NSMutableData *data = [NSMutableData dataWithLength:0];
    
    char mtime[256];
    sprintf(mtime, "%lu", time(0) - secondsAgo);
    
    aslmsg m, q = asl_new(ASL_TYPE_QUERY);
    NSString *app = [self appName];
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

+ (NSString*)processTemplate:(NSString*)text params:(NSDictionary*)params
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"@[a-z0-9_]+@" options:0 error:nil];
    while (1) {
        NSArray *matches = [regex matchesInString:text options:NSMatchingReportProgress range:NSMakeRange(0, text.length)];
        if (matches.count == 0) break;
        NSTextCheckingResult *match = matches[0];
        NSString *key = [text substringWithRange:NSMakeRange(match.range.location + 1, match.range.length-2)];
        text = [text stringByReplacingCharactersInRange:match.range withString:[params str:key]];
    }
    return text;
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

+ (NSArray*)toArray:(id)obj name:(NSString*)name dflt:(id)dflt
{
    if (![obj isKindOfClass:[NSDictionary class]]) return dflt;
    id rc = obj[name];
    if (![rc isKindOfClass:[NSArray class]]) return dflt;
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

+ (NSDictionary*)toDictionary:(id)obj name:(NSString*)name dflt:(id)dflt
{
    if (![obj isKindOfClass:[NSDictionary class]]) return dflt;
    id rc = obj[name];
    if (![rc isKindOfClass:[NSDictionary class]]) return dflt;
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
    if (!obj) return dflt;
    for (NSString *key in names) {
        if (obj[key]) return [obj str:key];
    }
    return dflt;
}

+ (double)toNumber:(id)obj names:(NSArray*)names dflt:(double)dflt
{
    if (!obj) return dflt;
    for (NSString *key in names) {
        if (obj[key]) return [obj num:key];
    }
    return dflt;
}

+ (NSData*)toJSON:(id)obj
{
    if (!obj) return nil;
    if (![NSJSONSerialization isValidJSONObject:obj]) {
        Logger(@"ERROR: invalid JSON: %@", obj);
        return nil;
    }
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:obj options:(NSJSONWritingOptions)0 error:&error];
    if (error) {
        Logger(@"%@: %@", error, obj);
        return nil;
    }
    return json;
}

+ (NSString*)toJSONString:(id)obj
{
    NSData *data = [self toJSON:obj];
    if (!data) return nil;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (id)toJSONObject:(NSString*)json
{
    if (!json || !json.length) return nil;
    NSError *error;
    return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                           options:NSJSONReadingMutableContainers
                                             error:&error];
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

+ (NSMutableURLRequest *)makeRequest:(NSString *)method path:(NSString *)path params:(NSDictionary *)params type:(NSString*)type
{
    NSURL *url = [NSURL URLWithString:path relativeToURL:[self instance].baseURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:method];
    [request setTimeoutInterval:30];
    if (!params) return request;
    
    if ([method isEqual:@"GET"] || [method isEqual:@"HEAD"] || [method isEqual:@"DELETE"]) {
        url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:[path rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", [BKjs makeQuery:params]]];
        [request setURL:url];
    } else {
        if ([type hasPrefix:@"application/json"]) {
            [request setValue:type forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[BKjs toJSON:params]];
        } else {
            [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[[BKjs makeQuery:params] dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
	return request;
}

+ (NSMutableURLRequest*)makeRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params headers:(NSDictionary*)headers body:(NSData*)body
{
    if (!method) method = @"GET";
    NSString *type = nil;
    for (NSString *key in headers) {
        if ([[key lowercaseString] isEqual:@"content-type"]) type = headers[key];
    }
    NSMutableURLRequest *request = [BKjs makeRequest:method path:path params:params type:type];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    if (body) [request setHTTPBody:body];
    request.timeoutInterval = 30;
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
    if (!path) return @"";
    // By default use plain HTTP for image requests
    if ([[self.baseURL scheme] isEqual:@"https"]) {
        if ([path hasPrefix:@"/image/"] ||
            [path hasPrefix:@"/icon/get"] ||
            [path hasPrefix:@"/account/get/icon"]) {
            return [NSString stringWithFormat:@"%@%@", [[self.baseURL absoluteString] stringByReplacingOccurrencesOfString:@"https://" withString:@"http://"], path];
        }
    }
    return path;
}

+ (NSString*)getAbsoluteURL:(NSString*)path
{
    return [[NSURL URLWithString:[self.instance.delegate getURL:path] relativeToURL:self.instance.baseURL] absoluteString];
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
    NSURL *url = [NSURL URLWithString:req relativeToURL:self.instance.baseURL];
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
    path = [self.instance.delegate getURL:path];
    NSDictionary *headers = [BKjs sign:path method:method params:params contentType:nil expires:0 checksum:nil];
    [BKjs sendRequest:path method:method params:params headers:headers body:nil success:success failure:failure];
}

+ (void)sendJSON:(NSString*)path method:(NSString*)method params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    path = [self.instance.delegate getURL:path];
    NSDictionary *headers = [BKjs sign:path method:method params:nil contentType:@"application/json; charset=UTF-8" expires:0 checksum:nil];
    NSData *body = [self toJSON:params];
    if (!body) {
        if (failure) failure(-1, @"invalid params for JSON");
        return;
    }
    [BKjs sendRequest:path method:method params:nil headers:headers body:body success:success failure:failure];
}

+ (void)uploadImage:(NSString*)path name:(NSString*)name image:(UIImage*)image params:(NSDictionary*)params headers:(NSDictionary*)headers success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSData *jpeg = image ? UIImageJPEGRepresentation(image, 1.0) : nil;
    if (!jpeg) {
        if (failure) failure(-1, @"invalid image");
        return;
    }
    [self uploadData:path name:name data:jpeg mime:@"image/jpeg" params:params headers:headers success:success failure:failure];
}

+ (void)uploadData:(NSString*)path name:(NSString*)name data:(NSData*)data mime:(NSString*)mime params:(NSDictionary*)params headers:(NSDictionary*)headers success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSMutableURLRequest *request = [self.instance
                                    multipartFormRequestWithMethod:@"POST"
                                    path:path
                                    parameters:params
                                    constructingBodyWithBlock:^(id <AFMultipartFormData>formData) {
                                        if (data) [formData appendPartWithFileData:data name:name fileName:name mimeType:mime];
                                    }];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    [BKjs sendRequest:request success:success failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        if (failure) failure(response.statusCode, error.description);
    }];
}

+ (void)sendRequest:(NSString*)path method:(NSString*)method params:(NSDictionary*)params headers:(NSDictionary*)headers body:(NSData*)body success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSMutableURLRequest *request = [BKjs makeRequest:method path:path params:params headers:headers body:body];
   
    [self sendRequest:request success:success failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        NSString *reason = [BKjs toString:json name:@"message"];
        if (reason.length == 0) reason = error.description;
        if (failure) failure(response.statusCode, reason);
    }];
}

+ (void)sendRequest:(NSURLRequest*)request success:(SuccessBlock)success failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure
{
    Logger(@"%@: %@", request.HTTPMethod, request.URL);
    
    AFJSONRequestOperation *op = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id json) {
        [self parseServerVersion:response];
        if (success) success(json);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id json) {
        Logger(@"url=%@, status=%ld, response: %@", request.URL, (long)response.statusCode, json ? json : error);
        [self parseServerVersion:response];
        if (failure) failure(request, response, error, json);
    }];
    [self.instance.operationQueue addOperation:op];
}

#pragma mark Image requests

- (UIImage*)getCachedImage:(NSString*)url
{
    return url ? [BKjs.cache objectForKey:url] : nil;
}

- (void)cacheImage:(NSString*)url image:(UIImage*)image
{
    // Store approximate image size for cost
    if (url && image) [BKjs.cache setObject:image forKey:url cost:image.size.width * image.size.height * 4];
}

- (void)uncacheImage:(NSString*)url
{
    if (url) [BKjs.cache removeObjectForKey:url];
}

+ (void)getImage:(NSString*)url options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    if (url == nil || url.length == 0) {
        if (failure) failure(0, @"no url provided");
        return;
    }
    [self sendImageRequest:[self.instance requestWithMethod:@"GET" path:url parameters:nil] options:options success:success failure:failure];
}

+ (void)sendImageRequest:(NSURLRequest*)request options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
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
    
    if (options & (BKCacheModeFlush|BKCacheModeFresh)) {
        [self.instance.delegate uncacheImage:url];
    }
    if (options & BKCacheModeCache) {
        UIImage *cached = [self.instance.delegate getCachedImage:url];
        if (cached) {
            if (success) success(cached, request.URL.absoluteString);
            return;
        }
    }
        
    Logger(@"%@", request);
    
    AFImageRequestOperation *op = [AFImageRequestOperation
                                   imageRequestOperationWithRequest:request
                                   imageProcessingBlock:nil
                                   success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                       if (options & (BKCacheModeCache|BKCacheModeFresh)) {
                                           [self.instance.delegate cacheImage:request.URL.absoluteString image:image];
                                       }
                                       [self parseServerVersion:response];
                                       if (success) success(image, request.URL.absoluteString);
                                   }
                                   failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                       [self parseServerVersion:response];
                                       Logger(@"%@: error: %ld: %@", request.URL, (long)response.statusCode, error);
                                       if (failure) failure(response.statusCode, error.description);
                                   }];
    [self.instance.operationQueue addOperation:op];
}

# pragma Icon API

+ (void)getIcon:(NSString*)path params:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    path = [self.instance.delegate getURL:path];
    NSDictionary *headers = [BKjs sign:path method:@"GET" params:params contentType:nil expires:0 checksum:nil];
    NSMutableURLRequest *request = [BKjs makeRequest:@"GET" path:[self.instance.delegate getURL:path] params:params type:nil];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    [self sendImageRequest:request options:options success:success failure:failure];
}

+ (void)getIcon:(NSString*)url options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url relativeToURL:self.instance.baseURL]];
    [request setTimeoutInterval:30];
    NSDictionary *headers = [BKjs sign:request.URL.absoluteString method:@"GET" params:nil contentType:nil expires:0 checksum:nil];
    for (NSString* key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    [self sendImageRequest:request options:options success:success failure:failure];
}

+ (void)getIconByPrefix:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    BKQueryParams *query = [[BKQueryParams alloc]
                            init:@"/image/@prefix@/@id@/@type@"
                            params:params
                            defaults:@{ @"prefix": @"account" }];

    [self getIcon:query.path params:query.params options:options success:success failure:failure];
}

#pragma mark Account Icon API

+ (void)getAccountIcons:(NSDictionary*)params success:(ListBlock)success failure:(GenericBlock)failure
{
    [BKjs sendQuery:@"/account/select/icon"
             method:@"POST"
             params:params
            success:^(NSArray *json) {
                if (success) success([json isKindOfClass:[NSArray class]] ? json : @[]);
            }
            failure:failure];
}

+ (void)getAccountIcon:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    [self getIcon:@"/account/get/icon" params:params options:options success:success failure:failure];
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
              // Current account save locally
              if ([self isEmpty:params name:@"id"] && [json isKindOfClass:[NSDictionary class]]) {
                  for (NSString *key in json) self.account[key] = json[key];
                  
                  // Update push notifications device token
                  if (_deviceToken && ![_deviceToken isEqual:[self.account str:@"device_id"]]) {
                      [self updateAccount:@{ @"device_id": _deviceToken } success:success failure:failure];
                  }
                  if (success) success(self.account);
              } else {
                  if (success) success(json);
              }
          } failure:^(NSInteger code, NSString *reason) {
              if ([self isEmpty:params name:@"id"]) [self.account removeAllObjects];
              if (failure) failure(code, reason);
          }];
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
            success:^(id obj) {
                [self logout];
                if (success) success();
            } failure:failure];
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

+ (void)updateDevice:(NSData*)device success:(GenericBlock)success failure:(FailureBlock)failure
{
    if (!device) return;
    const char* data = device.bytes;
    NSMutableString* token = [NSMutableString string];
    for (int i = 0; i < device.length; i++) {
        [token appendFormat:@"%02.2hhX", data[i]];
    }
    Logger(@"device token: %@", token);
    _deviceToken = token;

    // Update push notifications device token
    if (self.account[@"id"] && ![_deviceToken isEqual:[self.account str:@"device_id"]]) {
        [self updateAccount:@{ @"device_id": _deviceToken } success:success failure:failure];
    }
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
    [BKjs sendQuery:@"/reference/select"
             method:@"POST"
             params:params
            success:^(NSDictionary *json) {
                if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
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

+ (void)delConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [BKjs sendQuery:@"/connection/del"
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
                if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
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
    [BKjs getSentMessages:params success:^(int count, NSArray *list, NSString *token1) {
        [BKjs getArchivedMessages:params success:^(int count, NSArray *list2, NSString *token2) {
            NSArray* rc = [list arrayByAddingObjectsFromArray:list2];
            rc = [rc sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                double m1 = [BKjs toNumber:a name:@"mtime"];
                double m2 = [BKjs toNumber:b name:@"mtime"];
                return m1 < m2 ? NSOrderedAscending : m1 > m2 ? NSOrderedDescending : NSOrderedSame;
            }];
            if (success) success((int)rc.count, rc, nil);
        } failure:failure];
    } failure:failure];
}

+ (void)getMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [BKjs getNewMessages:params success:^(int count, NSArray *list1, NSString *token1) {
        [BKjs getArchivedMessages:params success:^(int count, NSArray *list2, NSString *token2) {
            NSArray* rc = [params isEmpty:@"_archive"] ? [list1 arrayByAddingObjectsFromArray:list2] : list2;
            rc = [rc sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                double m1 = [BKjs toNumber:a name:@"mtime"];
                double m2 = [BKjs toNumber:b name:@"mtime"];
                return m1 < m2 ? NSOrderedAscending : m1 > m2 ? NSOrderedDescending : NSOrderedSame;
            }];
            if (success) success((int)rc.count, rc, nil);
        } failure:failure];
    } failure:failure];
}

+ (void)getNewMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
          }
          failure:failure];
}

+ (void)getSentMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get/sent"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
          }
          failure:failure];
}

+ (void)getArchivedMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/get/archive"
           method:@"POST"
           params:params
          success:^(NSDictionary *json) {
              if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
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

+ (void)archiveMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/archive"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delArchivedMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del/archive"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)delSentMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendQuery:@"/message/del/sent"
             method:@"POST"
             params:params
            success:success
            failure:failure];
}

+ (void)getMessageIcon:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure
{
    [self getIcon:@"/message/image"
             params:params
            options:options
            success:success
            failure:failure];
}

#pragma mark - Location API

+ (CLLocationManager*)locationManager
{
    static dispatch_once_t _bkOnce;
    dispatch_once(&_bkOnce, ^{
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self.instance;
    });
    return _locationManager;
}

+ (CLLocation*)location;
{
    return _location ? _location : [[CLLocation alloc] initWithLatitude:0 longitude:0];
}

+ (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    _location = [locations lastObject];
    if (!_location) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BKLocationChangedNotification" object:self userInfo:@{ @"location": _location }];
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
            success:^(NSDictionary *json) {
                if (success) success([BKjs toNumber:json name:@"count"], [BKjs toArray:json name:@"data"], [BKjs toString:json name:@"next_token"]);
            } failure:failure];
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

#pragma mark BKQueryParams

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
