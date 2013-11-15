//
//  IAMFilesystemSyncController.h
//  Janus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
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
