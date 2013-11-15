//
//  NSDate+GTStringsHelpers.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 01/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (GTStringsHelpers)

-(NSString *)gt_timePassed;

- (NSString *)toRFC3339String;
+ (NSDate *)dateFromRFC3339String:(NSString *)rfc339String;

@end
