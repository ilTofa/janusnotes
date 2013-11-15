//
//  UserAgentReader.h
//  PiwikTestApp
//
//  Created by Mattias Levin on 5/14/12.
//  Copyright (c) 2012 Mattias Levin. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
@interface PTUserAgentReader : NSObject <UIWebViewDelegate>
#else
#import <WebKit/WebKit.h>
@interface PTUserAgentReader : NSObject // <WebPolicyDelegate>
#endif

- (void)userAgentStringWithCallbackBlock:(void (^)(NSString*))block;

@end
