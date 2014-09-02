//
//  BKFacebook.m
//
//  Created by Vlad Seryakov on 9/17/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKFacebookSDK.h"

@implementation BKFacebookSDK

- (id)init:(NSString*)name clientId:(NSString*)clientId
{
    self = [super init:name clientId:clientId];
    self.scope = @"email,user_photos,publish_actions";
    self.baseURL = @"https://graph.facebook.com";
    self.launchURLs = @[ @{ @"url": @"fb://profile/%@", @"param": @"id" },
                         @{ @"url": @"https://www.facebook.com/%@", @"param": @"username" } ];
    
    [FBSettings setDefaultAppID:self.clientId];
    return self;
}

- (void)getNext:(NSString*)url items:(NSMutableArray*)items block:(void (^)(id result, NSMutableArray *list))block success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [FBRequestConnection
     startWithGraphPath:url
     completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
         if (!error) {
             block(result, items);
             if (result[@"paging"] && result[@"paging"][@"next"]) {
                 [self getNext:result[@"paging"][@"next"] items:items block:block success:success failure:failure];
             } else {
                 if (success) success(items);
             }
         } else {
             Logger(@"getPages: %@", error);
             if (failure) failure(error.code, error.description);
         }
     }];
}

- (BOOL)isValid
{
    return [[FBSession activeSession] isOpen];
}

- (void)login:(ErrorBlock)finished
{
    if (FBSession.activeSession.isOpen) {
        finished(nil);
    } else {
        [FBSession openActiveSessionWithReadPermissions:[self.scope componentsSeparatedByString:@","]
                                           allowLoginUI:YES
                                      completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                          if (!error) {
                                              if (FBSession.activeSession.accessTokenData.accessToken) {
                                                  self.accessToken[@"access_token"] = FBSession.activeSession.accessTokenData.accessToken;
                                              }
                                              [self saveToken];
                                          } else {
                                              Logger(@"%@", error);
                                          }
                                          finished(error);
                                      }];
    }
}

- (void)logout
{
    [super logout];
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        BKQueryParams *query = [[BKQueryParams alloc]
                                init:@"/@id@"
                                params:params
                                defaults:@{ @"id": @"me",
                                            @"fields": @"picture.type(large),id,email,name,birthday,gender" }];

        [FBRequestConnection startWithGraphPath:query.path
                                     parameters:query.params
                                     HTTPMethod:@"GET"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      NSMutableDictionary *account = [[result isKindOfClass:[NSDictionary class]] ? result : @{} mutableCopy];
                                      if (!params || !params[@"id"]) self.account = account;
                                      account[@"type"] = self.name;
                                      account[@"facebook_id"] = [account str:@"id"];
                                      account[@"alias"] = [account str:@"name"];
                                      account[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:account name:@"picture"] name:@"data" field:@"url"];
                                      if (success) success(account);
                                  } else {
                                      Logger(@"%@", error);
                                      if (failure) failure(error.code, error.description);
                                  }
                              }];
    }];
}

- (void)getAlbums:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        BKQueryParams *query = [[BKQueryParams alloc]
                                init:@"/@id@"
                                params:params
                                defaults:@{ @"id": @"me",
                                            @"fields": @"albums.fields(name,photos.limit(1).fields(picture),count)" }];
        
        [FBRequestConnection startWithGraphPath:query.path
                                     parameters:query.params
                                     HTTPMethod:@"GET"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      NSMutableArray *list = [@[] mutableCopy];
                                      for (NSDictionary *album in [BKjs toArray:result[@"albums"] name:@"data"]) {
                                          for (NSDictionary *icon in [BKjs toArray:album[@"photos"] name:@"data"]) {
                                              [list addObject:@{ @"type": self.name,
                                                                 @"id": [album str:@"id"],
                                                                 @"name": [album str:@"name"],
                                                                 @"icon": [icon str:@"picture"],
                                                                 @"count": [album str:@"count"] }];
                                          }
                                      }
                                      if (success) success(list);
                                  } else {
                                      if (failure) failure(error.code, error.description);
                                  }
                              }];
    }];
}

- (void)getPhotos:(NSDictionary*)album params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        
        ItemsBlock block = ^(NSMutableArray *items, id result) {
            for (NSDictionary *item in result[@"data"]) {
                [items addObject:@{ @"type": self.name,
                                    @"icon": [item str:@"picture"],
                                    @"image": [item str:@"source"] }];
            }
        };
        
        [FBRequestConnection startWithGraphPath:[NSString stringWithFormat:@"/%@/photos", album[@"id"]]
                                     parameters:params
                                     HTTPMethod:@"GET"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      NSMutableArray *items = [@[] mutableCopy];
                                      block(items, result);
                                      if (result[@"paging"] && result[@"paging"][@"next"]) {
                                          [self getNext:result[@"paging"][@"next"] items:items block:block success:success failure:failure];
                                      } else {
                                          if (success) success(items);
                                      }
                                  } else {
                                      Logger(@"%@", error);
                                      if (failure) failure(error.code, error.description);
                                  }
                              }];
    }];
}

- (void)getFriends:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        ItemsBlock block = ^(NSMutableArray *items, id result) {
            for (NSDictionary *item in result[@"data"]) {
                NSMutableDictionary *rec = [item mutableCopy];
                rec[@"type"] = self.name;
                rec[@"facebook_id"] = [item str:@"id"];
                rec[@"alias"] = [item str:@"name"];
                rec[@"icon"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=small", rec[@"id"]];
                [items addObject:rec];
            }
        };
        
        BKQueryParams *query = [[BKQueryParams alloc]
                                init:@"/@id@/friends"
                                params:params
                                defaults:@{ @"id": @"me" }];

        [FBRequestConnection startWithGraphPath:query.path
                                     parameters:query.params
                                     HTTPMethod:@"GET"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      NSMutableArray *items = [@[] mutableCopy];
                                      block(items, result);
                                      if (result[@"paging"] && result[@"paging"][@"next"]) {
                                          [self getNext:result[@"paging"][@"next"] items:items block:block success:success failure:failure];
                                      } else {
                                          if (success) success(items);
                                      }
                                  } else {
                                      Logger(@"%@", error);
                                      if (failure) failure(error.code, error.description);
                                  }
                              }];
    }];
}

- (void)postMessage:(NSString*)msg image:(UIImage*)image params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure;
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }

        [FBRequestConnection startForPostStatusUpdate:msg ? msg : @""
                                    completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                        if (!error) {
                                            if (success) success(result);
                                        } else {
                                            Logger(@"%@", error);
                                            if (failure) failure(error.code, error.description);
                                        }
                                    }];
    }];
}

@end
