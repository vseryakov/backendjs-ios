//
//  BKjs
//  Backendjs API support class
//
//  Created by Vlad Seryakov on 7/1/14.
//  Copyright (c) 2014. All rights reserved.
//

#include <math.h>
#include <asl.h>
#include <zlib.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CoreImage/CIDetector.h>
#import <CoreImage/CoreImage.h>
#import <CoreData/CoreData.h>
#import <ImageIO/CGImageProperties.h>
#import <QuartzCore/QuartzCore.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Availability.h>
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"

#define XSTRINGIFY(n)       #n
#define STRINGIFY(n)        XSTRINGIFY(n)

#ifndef Logger
#define Logger(fmt, ...)    NSLog((@"%s:%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#endif

#ifdef BK_DEBUG
#define Debug(fmt, ...)     NSLog((@"%s:%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define Debug(fmt,...)
#endif

#define BKLogger(fmt, ...)  BKLog((@"%s:%d " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#define BKScreenWidth       [UIScreen mainScreen].bounds.size.width
#define BKScreenHeight      [UIScreen mainScreen].bounds.size.height
#define BKapp               ((AppDelegate*)BKjs.appDelegate)

// Logger that periodically flushes log lines to the backend using /log API call (it must be registered in the app)
void BKLog(NSString *format, ...);

// Block types for the callbacks
typedef void (^GenericBlock)();
typedef void (^SuccessBlock)(id obj);
typedef void (^DictionaryBlock)(NSDictionary *obj);
typedef void (^ListBlock)(NSArray *list);
typedef void (^ItemsBlock)(NSMutableArray *items, id data);
typedef void (^ArrayBlock)(int count, NSArray *list, NSString *next);
typedef void (^ErrorBlock)(NSError *error);
typedef void (^StringBlock)(NSString *str);
typedef void (^FinishBlock)(BOOL finished);
typedef void (^StatusBlock)(id obj, NSInteger code, NSString *reason);
typedef void (^FailureBlock)(NSInteger code, NSString *reason);
typedef void (^ImageSuccessBlock)(UIImage *image, NSString *url);
typedef UIImage* (^ImageProcessBlock)(UIImage *image, NSString *url);
typedef void (^AlertBlock)(NSString *action);
typedef void (^ControllerBlock)(UIViewController *controller, NSDictionary *item);

typedef NS_OPTIONS(NSUInteger, BKOptions) {
    BKCacheModeCache = 1,
    BKCacheModeFresh = 2,
    BKCacheModeFlush = 4,
    BKNoSignature = 8,
};

// Preprocess path and query with defaults, replace all placeholders in the format @name@ with the actual values
// from the params dictionary by name. All properties which are present in the path will be removed from the params.
@interface BKQueryParams: NSObject
@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSMutableDictionary* params;

- (instancetype)init:(NSString*)path params:(NSDictionary*)params defaults:(NSDictionary*)defaults;
- (void)format:(NSDictionary*)defaults;
@end;

// A delegate to implement custom or different way of default functionality
@protocol BKjsDelegate <NSObject>
@optional
// This method should return fully qualified URL to be retrieved, by default path is unchanged and passed as it it but by
// overriding this method it is possible to use custom url endpoints on the fly.
- (NSString*)getURL:(NSString*)path;

// Image cache implementation, default is using NSCache
- (UIImage*)getCachedImage:(NSString*)url;
- (void)cacheImage:(NSString*)url image:(UIImage*)image;
- (void)uncacheImage:(NSString*)url;
@end

// Global API object, the singleton, can be extened with delegate only
// If the base Url is not specified then the base url is constructed from one the following:
//  - BKBaseURL property string from the app plist
//  - CFBundleIdentifier domain, only first 2 parts are used in reverse order: com.app.name will be http://app.com
//
@interface BKjs: AFHTTPClient <CLLocationManagerDelegate,UIAlertViewDelegate,BKjsDelegate>

// Delegate with customized functionality
@property (nonatomic, weak) id <BKjsDelegate> delegate;

// Return global instance
+ (BKjs*)instance;

// Set credentials for API calls, takes effect immediately
+ (void)setCredentials:(NSString*)name secret:(NSString*)secret;

// Clear credentials and account
+ (void)logout;

+ (id<UIApplicationDelegate>)appDelegate;
+ (NSString*)documentsDirectory;
+ (NSString*)appName;
+ (NSString*)appVersion;
+ (NSString*)appDomain;
+ (NSString*)serverVersion;
+ (NSString*)iOSVersion;
+ (NSString*)iOSPlatform;
+ (NSString*)iOSModel;

// Location updates are enamed by default, this is the location manager which was created and assigned by the BKjs instance
+ (CLLocationManager*)locationManager;

// Last updated location
+ (CLLocation*)location;

// Currently logged in account
+ (NSMutableDictionary*)account;

// Account images
+ (NSMutableDictionary*)images;

// Generic properties
+ (NSMutableDictionary*)params;

// Image cache
+ (NSCache*)cache;

// Returns defaults object
+ (NSUserDefaults*)defaults;

// Returns YES if defaults key has been already set or sets it and returns NO
+ (BOOL)checkDefaults:(NSString*)key;

#pragma mark Keychain methods

+ (NSString *)passwordForService:(NSString *)service account:(NSString *)account error:(NSError **)error;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)service account:(NSString *)account error:(NSError **)error;
+ (BOOL)deletePasswordForService:(NSString *)service account:(NSString *)account error:(NSError **)error;

#pragma mark HTTP requests

+ (NSString*)getErrorMessage:(NSError*)error;
+ (NSString*)getAbsoluteURL:(NSString*)path;
+ (NSString*)makeQuery:(NSDictionary*)params;
+ (NSMutableURLRequest *)makeRequest:(NSString *)method path:(NSString *)path params:(NSDictionary *)params type:(NSString*)type;
+ (NSMutableURLRequest*)makeRequest:(NSString*)method path:(NSString*)path params:(NSDictionary*)params headers:(NSDictionary*)headers body:(NSData*)body;
+ (void)sendRequest:(NSString *)path method:(NSString*)method params:(NSDictionary*)params headers:(NSDictionary*)headers body:(NSData*)body success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)sendRequest:(NSURLRequest*)request success:(SuccessBlock)success failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON))failure;

#pragma mark Multipart uploads

+ (void)uploadImage:(NSString*)path name:(NSString*)name image:(UIImage*)image params:(NSDictionary*)params headers:(NSDictionary*)headers success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)uploadData:(NSString*)path name:(NSString*)name data:(NSData*)data mime:(NSString*)mime params:(NSDictionary*)params headers:(NSDictionary*)headers success:(SuccessBlock)success failure:(FailureBlock)failure;

#pragma mark Image requests

+ (void)sendImageRequest:(NSURLRequest*)request options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;
+ (void)getImage:(NSString*)url options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;

#pragma mark API requests

+ (void)sendQuery:(NSString *)path method:(NSString*)method params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)sendJSON:(NSString *)path method:(NSString*)method params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (NSDictionary*)sign:(NSString*)path method:(NSString*)method params:(NSDictionary*)params contentType:(NSString*)contentType expires:(NSTimeInterval)expires checksum:(NSString*)checksum;

#pragma mark Account API

+ (void)getAccount:(NSDictionary*)params success:(DictionaryBlock)success failure:(FailureBlock)failure;
+ (void)delAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)updateAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)updateDevice:(NSData*)device success:(SuccessBlock)success failure:(FailureBlock)failure;

#pragma mark Account icons API

+ (void)getAccountIcon:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;
+ (void)putAccountIcon:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)delAccountIcon:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)getAccountIcons:(NSDictionary*)params success:(ListBlock)success failure:(FailureBlock)failure;

#pragma mark Icon API

+ (void)getIcon:(NSString*)path params:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;
+ (void)getIcon:(NSString*)url options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;
+ (void)getIconByPrefix:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;
+ (void)putIcon:(NSString*)path params:(NSDictionary*)params image:(UIImage*)image success:(SuccessBlock)success failure:(FailureBlock)failure;

#pragma mark Location API

+ (void)putLocation:(CLLocation*)location params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)getLocation:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;

#pragma mark Connection API

+ (void)selectConnection:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)selectReference:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)getConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)getReference:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)addConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)updateConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)incrConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)delConnection:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;

#pragma mark Message API

+ (void)getMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)getArchivedMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)getSentMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)getNewMessages:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)getConversation:(NSDictionary*)params success:(ArrayBlock)success failure:(FailureBlock)failure;
+ (void)addMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)archiveMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)delMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)delArchivedMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)delSentMessage:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
+ (void)getMessageIcon:(NSDictionary*)params options:(BKOptions)options success:(ImageSuccessBlock)success failure:(FailureBlock)failure;

#pragma mark Dictionary properties, never return nil

+ (double)toNumber:(id)obj;
+ (double)toNumber:(id)obj name:(NSString*)name;
+ (NSString*)toString:(id)obj;
+ (NSDictionary*)toDictionary:(id)obj name:(NSString*)name;
+ (NSDictionary*)toDictionary:(id)obj name:(NSString*)name dflt:(id)dflt;
+ (NSMutableDictionary*)toDictionary:(id)obj params:(NSDictionary*)params;
+ (NSArray*)toArray:(id)obj name:(NSString*)name;
+ (NSArray*)toArray:(id)obj name:(NSString*)name dflt:(id)dflt;
+ (NSString*)toString:(id)obj name:(NSString*)name;
+ (NSArray*)toDictionaryArray:(id)obj name:(NSString*)name field:(NSString*)field;
+ (NSString*)toDictionaryString:(id)obj name:(NSString*)name field:(NSString*)field;
+ (BOOL)isEmpty:(id)obj name:(NSString*)name;
+ (BOOL)isEmpty:(id)obj;
+ (NSString*)toString:(id)obj names:(NSArray*)names dflt:(NSString*)dflt;
+ (double)toNumber:(id)obj names:(NSArray*)names dflt:(double)dflt;
+ (NSData*)toJSON:(id)obj;
+ (NSString*)toJSONString:(id)obj;
+ (id)toJSONObject:(NSString*)json;

#pragma mark Generic utilities

// Return current timestamp in seconds since the Epoch.
+ (long long)now;

// Generate a random number for the given range
+ (double)rand:(double)from to:(double)to;

// Regexp matching, YES if matched
+ (BOOL)matchString:(NSString *)pattern string:(NSString*)string;

// Replace all occurences of @..@ placeholders in text with corresponding values from the params
+ (NSString*)processTemplate:(NSString*)text params:(NSDictionary*)params;

// Return new unique UUID 
+ (NSString*)getUUID;

// Return formatted date/time from the seconds since Unix epoch
+ (NSString*)strftime:(long long)seconds format:(NSString*)format;
+ (NSString*)toDuration:(double)seconds format:(NSString*)format;
+ (NSString*)toAge:(double)seconds format:(NSString*)fmt;

// Return system log records for the current application starting the given seconds ago
+ (NSData*)getSystemLog:(long)secondsAgo;

// Return an invocation instance for the given selector
+ (NSInvocation*)getInvocation:(id)target name:(NSString*)name;

// Execute a method in the target by name with optional argument
+ (void)invoke:(id)target name:(NSString*)name arg:(id)arg;

// Merge params into the item, only non existent propertis are merged, the item properties are preserved
+ (NSMutableDictionary*)mergeParams:(NSDictionary*)item params:(NSDictionary*)params;

// Run a block with a delay
+ (void)scheduleBlock:(double)seconds block:(SuccessBlock)block params:(id)params;

#pragma mark String conversions

+ (NSString*)escapeString:(NSString *)string;
+ (NSMutableDictionary *)parseQueryString:(NSString *)query;
+ (NSData*)fromBase64:(NSString*)string;
+ (NSString*)toBase64:(NSData*)rawBytes;
+ (NSString*)toHmacSHA1:(NSData*)data secret:(NSString*)secret;

@end

#pragma mark NSDictionary util

@interface NSDictionary (util)
- (BOOL)isEmpty:(NSString*)name;
- (NSDictionary*)dict:(NSString*)name;
- (NSArray*)list:(NSString*)name;
- (NSString*)str:(NSString*)name;
- (double)num:(NSString*)name;
- (long long)llong:(NSString*)name;
- (BOOL)bool:(NSString*)name;
- (NSString*)str:(NSArray*)names dflt:(NSString*)dflt;
- (double)num:(NSArray*)names dflt:(double)dflt;
@end

