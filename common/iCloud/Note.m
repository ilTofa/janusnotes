//
//  Note.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "Note.h"

#import "NSString+UUID.h"

@implementation Note

@dynamic creationDate;
@dynamic primitiveCreationDate;
@dynamic sectionIdentifier;
@dynamic primitiveSectionIdentifier;
@dynamic creationIdentifier;
@dynamic primitiveCreationIdentifier;
@dynamic text;
@dynamic timeStamp;
@dynamic primitiveTimeStamp;
@dynamic title;
@dynamic uuid;
@dynamic attachment;


#pragma mark - awakeFromInsert: setup initial values

- (void) awakeFromInsert
{
    [super awakeFromInsert];
    [self setText:@""];
    [self setTitle:@""];
    if([NSUUID class])
        [self setUuid:[[NSUUID UUID] UUIDString]];
    else
        [self setUuid:[NSString uuid]];
    [self setTimeStamp:[NSDate date]];
    [self setCreationDate:[NSDate date]];
    [self setAttachment:nil];
}

#pragma mark - Transient properties

- (NSString *)sectionIdentifier
{
    // Create and cache the section identifier on demand.
    [self willAccessValueForKey:@"sectionIdentifier"];
    NSString *tmp = [self primitiveSectionIdentifier];
    [self didAccessValueForKey:@"sectionIdentifier"];
    if (!tmp) {
        // Sections are organized by month and year. Create the section identifier as a string representing the number (year * 1000) + month; this way they will be correctly ordered chronologically regardless of the actual name of the month.
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit) fromDate:[self timeStamp]];
        tmp = [NSString stringWithFormat:@"%d", (int)(([components year] * 1000) + [components month])];
        [self setPrimitiveSectionIdentifier:tmp];
    }
    return tmp;
}

- (NSString *)creationIdentifier
{
    // Create and cache the section identifier on demand.
    [self willAccessValueForKey:@"creationIdentifier"];
    NSString *tmp = [self primitiveCreationIdentifier];
    [self didAccessValueForKey:@"creationIdentifier"];
    if (!tmp) {
        // Sections are organized by month and year. Create the section identifier as a string representing the number (year * 1000) + month; this way they will be correctly ordered chronologically regardless of the actual name of the month.
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSYearCalendarUnit | NSMonthCalendarUnit) fromDate:[self creationDate]];
        tmp = [NSString stringWithFormat:@"%d", (int)(([components year] * 1000) + [components month])];
        [self setPrimitiveCreationIdentifier:tmp];
    }
    return tmp;
}

#pragma mark - Time stamp setter

- (void)setTimeStamp:(NSDate *)newDate {
    // If the time stamp changes, the section identifier become invalid.
    [self willChangeValueForKey:@"timeStamp"];
    [self setPrimitiveTimeStamp:newDate];
    [self didChangeValueForKey:@"timeStamp"];
    [self setPrimitiveSectionIdentifier:nil];
}

- (void)setCreationDate:(NSDate *)newDate {
    // If the creation date changes, the creation identifier become invalid.
    [self willChangeValueForKey:@"creationDate"];
    [self setPrimitiveCreationDate:newDate];
    [self didChangeValueForKey:@"creationDate"];
    [self setPrimitiveCreationIdentifier:nil];
}


#pragma mark - Key path dependencies

+ (NSSet *)keyPathsForValuesAffectingSectionIdentifier {
    // If the value of timeStamp changes, the section identifier may change as well.
    return [NSSet setWithObject:@"timeStamp"];
}

+ (NSSet *)keyPathsForValuesAffectingCreationIdentifier {
    // If the value of creationDate changes, the creation identifier may change as well.
    return [NSSet setWithObject:@"creationDate"];
}

@end
