//
//  BKWebViewController.h
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

typedef void (^WebViewCompletionBlock)(NSURLRequest *req, NSError *err);

@interface BKWebViewController: UIViewController
@property (nonatomic, strong) UIWebView *webview;
@property (nonatomic, strong) UIViewController *root;
@property (nonatomic, strong) UIButton *close;
@property (nonatomic, strong) WebViewCompletionBlock completionHandler;

+ (BKWebViewController*)initWithDelegate:(id<UIWebViewDelegate>)delegate completionHandler:(WebViewCompletionBlock)completionHandler;
- (void)start:(id)request completionHandler:(WebViewCompletionBlock)completionHandler;
- (void)start:(id)request;
- (void)show;
- (void)hide;
- (void)finish:(NSURLRequest*)request error:(NSError*)error;
- (void)showActivity;
- (void)hideActivity;
@end
