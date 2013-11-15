//
//  GTTransientMessage.h
//
//  Created by Giacomo Tufano on 24/08/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GTTransientMessage : NSObject

+ (void)showWithTitle:(NSString *)title andSubTitle:(NSString *)subTitle forSeconds:(double)secondsDelay;

@end
