//
//  UserAgentReader.m
//  PiwikTestApp
//
//  Created by Mattias Levin on 5/14/12.
//  Copyright (c) 2012 Mattias Levin. All rights reserved.
//

#import "PTUserAgentReader.h"

// Private stuff
@interface PTUserAgentReader ()
#if TARGET_OS_IPHONE
@property (nonatomic, strong) UIWebView *webWiew;
#else
@property (nonatomic, strong) WebView *webWiew;
#endif
@property (nonatomic, copy) void (^callbackBlock)(NSString*);
@end


// Class implementation
@implementation PTUserAgentReader

#if TARGET_OS_IPHONE

// Get the user agent profile string
- (void)userAgentStringWithCallbackBlock:(void (^)(NSString*))block {
  dispatch_async(dispatch_get_main_queue(), ^{
    self.callbackBlock = block;
    
    self.webWiew = [[UIWebView alloc] init];
    self.webWiew.delegate = self;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]];
    [self.webWiew loadRequest:request];
  });
}


// Webview delegate, called just before starting to load the request
- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
  //NSLog(@"All headers: %@", [request allHTTPHeaderFields]);
  NSLog(@"UA: %@", [request valueForHTTPHeaderField:@"User-Agent"]);

  self.callbackBlock([request valueForHTTPHeaderField:@"User-Agent"]);
  
  return NO;
}

#else

// Get the user agent profile string
- (void)userAgentStringWithCallbackBlock:(void (^)(NSString*))block {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.callbackBlock = block;
        
        self.webWiew = [[WebView alloc] init];
        self.webWiew.policyDelegate = self;
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]];
        [self.webWiew.mainFrame loadRequest:request];
    });
}

-(void)webView:(WebView *)webView
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
       request:(NSURLRequest *)request
         frame:(WebFrame *)frame
decisionListener:(id < WebPolicyDecisionListener >)listener
{
    NSLog(@"UA: %@", [request valueForHTTPHeaderField:@"User-Agent"]);
    self.callbackBlock([request valueForHTTPHeaderField:@"User-Agent"]);
    [listener ignore];
}

#endif

@end
