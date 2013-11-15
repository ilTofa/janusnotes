//
//  NSDate+GTStringsHelpers.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 01/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "NSDate+GTStringsHelpers.h"

@implementation NSDate (GTStringsHelpers)

-(NSString *)gt_timePassed
{
    NSTimeInterval timeDifference = [[NSDate date] timeIntervalSinceDate:self];
    int iminutes = timeDifference / 60;
    int ihours = iminutes / 60;
    int idays = iminutes / 1440;
    iminutes = iminutes - ihours * 60;
    ihours = ihours - idays * 24;
    NSString *timePassed;
    if(idays > 1)
        timePassed = [NSString stringWithFormat:@"%dd ago", idays];
    else if(idays == 1)
        timePassed = @"yesterday";
    else if(ihours == 0 && iminutes == 0)
        timePassed = @"now";
    else if(ihours == 0)
        timePassed = [NSString stringWithFormat:@"%dm ago", iminutes];
    else
        timePassed = [NSString stringWithFormat:@"%dh %dm ago", ihours, iminutes];
    return timePassed;
}

+ (NSDateFormatter *)getFormatterForRFC339 {
    static NSDateFormatter *sRFC3339DateFormatter;
    if (sRFC3339DateFormatter == nil) {
        NSLocale *                  enUSPOSIXLocale;
        
        sRFC3339DateFormatter = [[NSDateFormatter alloc] init];
        assert(sRFC3339DateFormatter != nil);
        
        enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        assert(enUSPOSIXLocale != nil);
        
        [sRFC3339DateFormatter setLocale:enUSPOSIXLocale];
        [sRFC3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];  // ie: 2013-06-27T12:02:34Z
        [sRFC3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    return sRFC3339DateFormatter;
}

- (NSString *)toRFC3339String {
    return [[NSDate getFormatterForRFC339] stringFromDate:self];
}

+ (NSDate *)dateFromRFC3339String:(NSString *)rfc339String {
    return [[NSDate getFormatterForRFC339] dateFromString:rfc339String];
}

@end
