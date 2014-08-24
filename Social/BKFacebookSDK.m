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
    self.scope = @"email,user_friends";
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

- (void)login:(ErrorBlock)finished
{
    if ([FBSession activeSession].isOpen) {
        finished(nil);
    } else {
        [FBSession openActiveSessionWithReadPermissions:[self.scope componentsSeparatedByString:@","]
                                           allowLoginUI:YES
                                      completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
                                          if (error) Logger(@"%@", error);
                                          finished(error);
                                      }];
    }
}

- (void)getAccount:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        [FBRequestConnection startWithGraphPath:@"/me"
                                     parameters:@{ @"fields": @"picture.type(large),id,email,name,birthday,gender" }
                                     HTTPMethod:@"GET"
                              completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                  if (!error) {
                                      NSDictionary *user = [result isKindOfClass:[NSDictionary class]] ? result : @{};
                                      for (id key in user) self.account[key] = user[key];
                                      self.account[@"alias"] = [user str:@"name"];
                                      self.account[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:user name:@"picture"] name:@"data" field:@"url"];
                                      if (success) success(self.account);
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
        [FBRequestConnection startWithGraphPath:@"/me"
                                     parameters:@{ @"fields": @"albums.fields(name,photos.limit(1).fields(picture),count)" }
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
                                  Logger(@"%@: %@", error, result);
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

- (void)getContacts:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
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
                rec[@"alias"] = item[@"name"];
                rec[@"icon"] = [NSString stringWithFormat:@"https://graph.facebook.com/%@/picture?type=small", rec[@"id"]];
                [items addObject:rec];
            }
        };
        
        [FBRequestConnection startWithGraphPath:@"/me/friends"
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

-(void)getMutualFriends:(NSString*)name params:(NSDictionary*)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self login:^(NSError *error) {
        if (error) {
            if (failure) failure(error.code, error.description);
            return;
        }
        ItemsBlock block = ^(NSMutableArray *items, id result) {
            for (NSMutableDictionary *item in result[@"data"]) {
                item[@"type"] = self.name;
                item[@"alias"] = item[@"name"];
                item[@"icon"] = [BKjs toDictionaryString:[BKjs toDictionary:item name:@"picture"] name:@"data" field:@"url"];
                [items addObject:item];
            }
        };
        
        [FBRequestConnection startWithGraphPath:[NSString stringWithFormat:@"/me/mutualfriends/%@",name]
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
