//
//  Note.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Note : NSManagedObject

@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) NSDate * primitiveCreationDate;
@property (nonatomic, retain) NSString * sectionIdentifier;
@property (nonatomic, retain) NSString *primitiveSectionIdentifier;
@property (nonatomic, retain) NSString *creationIdentifier;
@property (nonatomic, retain) NSString *primitiveCreationIdentifier;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSDate *primitiveTimeStamp;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSSet *attachment;
@end

@interface Note (CoreDataGeneratedAccessors)

- (void)addAttachmentObject:(NSManagedObject *)value;
- (void)removeAttachmentObject:(NSManagedObject *)value;
- (void)addAttachment:(NSSet *)values;
- (void)removeAttachment:(NSSet *)values;

@end
