//
//  BKWebViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013 Inc. All rights reserved.
//

@interface BKWebViewController ()
@end;

@implementation BKWebViewController

+ (BKWebViewController*)initWithDelegate:(id<UIWebViewDelegate>)delegate completionHandler:(WebViewCompletionBlock)completionHandler
{
    BKWebViewController *view = [[BKWebViewController alloc] init];
    view.webview.delegate = delegate;
    view.completionHandler = completionHandler;
    return view;
}

+ (BKWebViewController*)showURL:(NSString*)url completionHandler:(WebViewCompletionBlock)completionHandler
{
    BKWebViewController *web = [BKWebViewController initWithDelegate:nil completionHandler:completionHandler];
    [web start:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    [web show];
    return web;
}

-(id)init
{
    self = [super init];
    self.view = [[UIView alloc] initWithFrame:[[[UIApplication sharedApplication] delegate] window].bounds];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.contentMode = UIViewContentModeRedraw;
    
    self.webview = [[UIWebView alloc] initWithFrame:CGRectInset(self.view.frame, 0, 0)];
    self.webview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webview.layer.masksToBounds = YES;
    self.webview.layer.cornerRadius = 0;
    self.webview.scrollView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    [self.view addSubview:self.webview];
    
    self.close = [UIButton buttonWithType:UIButtonTypeCustom];
    self.close.frame = CGRectMake(5, 20, 32, 32);
    [self.close setImage:[UIImage imageNamed:@"black_close"] forState:UIControlStateNormal];
    [self.close addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    self.close.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.close];
    
    return self;
}

- (void)start:(id)request
{
    [self start:request completionHandler:self.completionHandler];
}

- (void)start:(id)request completionHandler:(WebViewCompletionBlock)completionHandler
{
    NSURLRequest *req = nil;
    if ([request isKindOfClass:[NSString class]]) {
        req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:request]];
    } else
    if ([request isKindOfClass:[NSURLRequest class]]) {
        req = request;
    }
    if (!req) return;
    self.completionHandler = completionHandler;
    [self.webview loadRequest:request];
    [self showActivity];
}

- (void)finish:(NSURLRequest*)request error:(NSError*)error
{
    Logger(@"%@: %@", [request URL], error);
    [self hideActivity];
    
    WebViewCompletionBlock handler = self.completionHandler;
    self.completionHandler = nil;
    
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:^{
            if (handler) handler(request, error);
        }];
    } else {
        if (handler) handler(request, error);
    }
}

- (void)cancel
{
    [self finish:nil error:nil];
}

- (void)show
{
    if (self.presentingViewController) return;
    self.root = [BKui rootViewController];
    [self.root presentViewController:self animated:YES completion:nil];
}

- (void)hide
{
    [self hideActivity];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showActivity
{
    [BKui showActivityInView:self.view];
}

- (void)hideActivity
{
    [BKui hideActivity];
}
@end
