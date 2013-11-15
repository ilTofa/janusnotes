//
//  NSManagedObjectContext+FetchedObjectFromURI.h
//  Janus
//
//  Created by Giacomo Tufano on 27/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (FetchedObjectFromURI)

- (NSManagedObject *)objectWithURI:(NSURL *)uri;

@end
