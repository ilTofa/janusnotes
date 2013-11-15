//
//  IAMFilesystemSyncController.h
//  Janus
//
//  Created by Giacomo Tufano on 12/04/13.
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
#import "Attachment.h"

#define kIAMDataSyncControllerReady @"IAMDataSyncControllerReady"
#define kIAMDataSyncControllerStopped @"IAMDataSyncControllerStopped"
#define kIAMDataSyncRefreshTerminated @"IAMDataSyncRefreshTerminated"
#define kIAMDataSyncNeedsAPasswordNow @"kIAMDataSyncNeedsAPasswordNow"
#define kIAMDataSyncSelectedDefaulDir @"kIAMDataSyncSelectedDefaulDir"

@interface IAMFilesystemSyncController : NSObject

@property BOOL syncControllerReady;
@property BOOL syncControllerInited;
@property (nonatomic, readonly) NSManagedObjectContext *dataSyncThreadContext;

@property BOOL notesAreEncrypted;

@property (nonatomic) NSString *cryptPassword;

+ (IAMFilesystemSyncController *)sharedInstance;

- (BOOL)modifySyncDirectory:(NSURL *)newSyncDirectory;
- (void)refreshContentFromRemote;
- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename;
- (NSURL *)urlForAttachment:(Attachment *)attachment;
- (NSURL *)urlForNote:(Note *)note;

- (void)cryptNotesWithPassword:(NSString *)password andCompletionBlock:(void (^)(void))block;
- (void)decryptNotesWithCompletionBlock:(void (^)(void))block;
- (BOOL)checkCryptPassword:(NSString *)password error:(NSError **)errorPtr;

@end
