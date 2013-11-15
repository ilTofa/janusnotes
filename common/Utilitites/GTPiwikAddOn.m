//
//  GTPiwikAddOn.m
//  iJanus
//
//  Created by Giacomo Tufano on 10/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTPiwikAddOn.h"

#import "PiwikTracker.h"

@implementation GTPiwikAddOn

+ (void)trackEvent:(NSString *)event {
    [[PiwikTracker sharedTracker] trackPageview:event completionBlock:^(NSError *error) {
        if (error != nil) {
            ALog(@"Track event %@ failed with error message %@", event, [error description]);
        }
    }];
}

@end
