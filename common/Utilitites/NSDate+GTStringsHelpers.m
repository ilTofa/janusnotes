//
//  NSDate+GTStringsHelpers.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 01/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
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
