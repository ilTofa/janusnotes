//
//  IAMDataSyncController.h
//  iJanus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Dropbox/Dropbox.h>

#define kIAMDataSyncControllerReady @"IAMDataSyncControllerReady"
#define kIAMDataSyncControllerStopped @"IAMDataSyncControllerStopped"
#define kIAMDataSyncRefreshTerminated @"IAMDataSyncRefreshTerminated"
#define kIAMDataSyncNeedsAPasswordNow @"kIAMDataSyncNeedsAPasswordNow"
#define kIAMDataSyncStillPendingChanges @"kIAMDataSyncStillPendingChanges"

@interface IAMDataSyncController : NSObject

@property BOOL syncControllerReady;
@property BOOL syncControllerInited;
@property BOOL needsSyncPassword;
@property (nonatomic, readonly) NSManagedObjectContext *dataSyncThreadContext;
@property (nonatomic) NSString *cryptPassword;

@property BOOL notesAreEncrypted;

+ (IAMDataSyncController *)sharedInstance;

- (void)refreshContentFromRemote;
- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename;

- (void)cryptNotesWithPassword:(NSString *)password andCompletionBlock:(void (^)(void))block;
- (void)decryptNotesWithCompletionBlock:(void (^)(void))block;
- (BOOL)checkCryptPassword:(NSString *)password error:(DBError **)errorPtr;

@end
