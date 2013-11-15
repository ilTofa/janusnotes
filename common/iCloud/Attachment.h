//
//  Attachment.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Note;

@interface Attachment : NSManagedObject

@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSString * primitiveType;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSString * uti;
@property (nonatomic, retain) NSString * primitiveUti;
@property (nonatomic, retain) NSString * extension;
@property (nonatomic, retain) NSString * primitiveExtension;
@property (nonatomic, retain) NSString * filename;
@property (nonatomic, retain) NSString * primitiveFilename;
@property (nonatomic, retain) Note *note;

- (NSURL *)generateFile;

@end
