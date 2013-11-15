//
//  Note.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
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
