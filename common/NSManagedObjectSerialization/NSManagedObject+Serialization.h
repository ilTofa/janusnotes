//
//  NSManagedObject+Serialization.h
//  Janus Notes
//
//  Created by Giacomo Tufano on 21/01/14.
//  Copyright (c) 2014 Giacomo Tufano. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (Serialization)

- (NSDictionary*) toDictionary;
- (void) populateFromDictionary:(NSDictionary*)dict;
+ (NSManagedObject*) createManagedObjectFromDictionary:(NSDictionary*)dict inContext:(NSManagedObjectContext*)context;

@end
