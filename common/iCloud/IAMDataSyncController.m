//
//  IAMDataSyncController.m
//  iJanus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMDataSyncController.h"

#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "Note.h"
#import "Attachment.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "STKeychain.h"
#import "NSDate+GTStringsHelpers.h"

#import "DropboxKeys.h"

#define kNotesExtension @"jnote"
#define kAttachmentDirectory @"Attachments"
#define kMagicCryptFilename @".crypted"
#define kMagicString @"This is definitely a rncrypted string. Whatever that means."

#pragma mark - filename helpers

NSString * convertToValidDropboxFilenames(NSString * originalString) {
    NSMutableString * temp = [originalString mutableCopy];
    
    [temp replaceOccurrencesOfString:@"%" withString:@"%25" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"/" withString:@"%2f" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"\\" withString:@"%5c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"<" withString:@"%3c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@">" withString:@"%3e" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@":" withString:@"%3a" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"\"" withString:@"%22" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"|" withString:@"%7c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"?" withString:@"%3f" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"*" withString:@"%2a" options:0 range:NSMakeRange(0, [temp length])];
    return temp;
}

NSString * convertFromValidDropboxFilenames(NSString * originalString) {
    NSMutableString * temp = [originalString mutableCopy];
    
    [temp replaceOccurrencesOfString:@"%2f" withString:@"/" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%5c" withString:@"\\" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3c" withString:@"<" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3e" withString:@">" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3a" withString:@":" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%22" withString:@"\"" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%7c" withString:@"|" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3f" withString:@"?" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%2a" withString:@"*" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%25" withString:@"%" options:0 range:NSMakeRange(0, [temp length])];
    return temp;
}

@interface IAMDataSyncController() {
    dispatch_queue_t _syncQueue;
    BOOL _isResettingDataFromDropbox;
}

@property (weak) CoreDataController *coreDataController;

@end

@implementation IAMDataSyncController

+ (IAMDataSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMDataSyncController *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - Dropbox init

// Init is called on first usage. Calls gotNewDropboxUser just in case, and register for account changes to call gotNewDropboxUser
- (id)init
{
    self = [super init];
    if (self) {
        // check if the data controller is ready
        self.coreDataController = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).coreDataController;
        NSAssert(self.coreDataController.psc, @"DataSyncController inited when CoreDataController Persistent Storage is still invalid");
        _syncQueue = dispatch_queue_create("dataSyncControllerQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_syncQueue, ^{
            _dataSyncThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_dataSyncThreadContext setPersistentStoreCoordinator:self.coreDataController.psc];
        });
        _isResettingDataFromDropbox = NO;
        // Init dropbox sync API
        DBAccountManager* accountMgr = [[DBAccountManager alloc] initWithAppKey:DROPBOX_APP_KEY secret:DROPBOX_SECRET];
        [DBAccountManager setSharedManager:accountMgr];
        DBAccount *account = accountMgr.linkedAccount;
        // Listen to ourself, so to sync changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localContextSaved:) name:NSManagedObjectContextDidSaveNotification object:_dataSyncThreadContext];
        [self gotNewDropboxUser:account];
        // Observe account changes and reset the shared filesystem just in case.
        [accountMgr addObserver:self block:^(DBAccount *account) {
            [self gotNewDropboxUser:account];
        }];
        [self addReadmeIfNeeded];
    }
    return self;
}

- (void)migrateToDropboxSyncV112 {
    // Change email with displayname
    if([[NSUserDefaults standardUserDefaults] stringForKey:@"currentDropboxAccount"]) {
        DLog(@"Migrating dropbox user from %@ to %@", [[NSUserDefaults standardUserDefaults] stringForKey:@"currentDropboxAccount"], [DBAccountManager sharedManager].linkedAccount.userId);
        [[NSUserDefaults standardUserDefaults] setValue:[DBAccountManager sharedManager].linkedAccount.userId forKey:@"currentDropboxAccount"];
    }
}

// This is called at startup and everytime a new account is linked (or unlinked). The real engine readiness is in checkFirstSync.
- (void)gotNewDropboxUser:(DBAccount *)account {
    DBAccount *currentAccount = [DBAccountManager sharedManager].linkedAccount;
    if(currentAccount) {
        // Migrate dropbox identifier if needed
        if ([[NSUserDefaults standardUserDefaults] integerForKey:@"dropBoxMigratedTo1.1.12"] == 0) {
            [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"dropBoxMigratedTo1.1.12"];
            [self migrateToDropboxSyncV112];
        }
        self.syncControllerInited = YES;
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:currentAccount];
        [DBFilesystem setSharedFilesystem:filesystem];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self checkFirstSync:nil];
    } else {
        // Stop the sync engine
        dispatch_async(dispatch_get_main_queue(), ^{
            self.syncControllerInited = NO;
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"currentDropboxAccount"];
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerStopped object:self]];
            self.syncControllerReady = NO;
            DLog(@"IAMDataSyncController is stopped.");
        });
    }
}

// This check if first sync is completed every second. When ready:
// If this is a new account copy coredata db to dropbox,
// in any case, copy all data from dropbox to CoreData db.
- (void)checkFirstSync:(NSTimer*)theTimer {
    if([DBFilesystem sharedFilesystem].completedFirstSync) {
        // Copy current notes (if new account) to dropbox and notify
        if(![[[NSUserDefaults standardUserDefaults] stringForKey:@"currentDropboxAccount"] isEqualToString:[DBAccountManager sharedManager].linkedAccount.userId])
            [self copyCurrentDataToDropboxWithCompletionBlock:nil];
        // Notify interested parties that the sync engine is ready to be used (and set the flag)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshContentFromRemote];
            DLog(@"IAMDataSyncController is ready.");
            self.syncControllerReady = YES;
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
        });
    } else {
        DLog(@"Still waiting for first sync completion");
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkFirstSync:) userInfo:nil repeats:NO];
        });
    }
}

#pragma mark - Crypt support

- (void)setCryptPassword:(NSString *)password {
    // In case of error, the password is not changed.
    NSError *error;
    DBPath *magicFile = [[DBPath root] childPath:kMagicCryptFilename];
    if(password) {
        DLog(@"Setting crypt password to %@", password);
        NSData *magicContent = [kMagicString dataUsingEncoding:NSUTF8StringEncoding];
        NSData *encryptedData = [RNEncryptor encryptData:magicContent withSettings:kRNCryptorAES256Settings password:password error:&error];
        DBFile *magicTextFile = [[DBFilesystem sharedFilesystem] openFile:magicFile error:&error];
        if(!magicTextFile) {
            // tring to create it.
            magicTextFile = [[DBFilesystem sharedFilesystem] createFile:magicFile error:&error];
            if(!magicTextFile) {
                ALog(@"Error creating magic file: %d.", [error code]);
                return;
            }
        }
        if(![magicTextFile writeData:encryptedData error:&error]) {
            ALog(@"Error writing to magic file: %d.", [error code]);
            return;
        }
        [magicTextFile close];
        [STKeychain storeUsername:@"crypt" andPassword:password forServiceName:@"it.iltofa.janus" updateExisting:YES error:&error];
    } else {
        DLog(@"Deleting crypt password (setting to nil)");
        [STKeychain deleteItemForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:&error];
        [[DBFilesystem sharedFilesystem] deletePath:magicFile error:&error];
    }
}

- (void)cryptNotesWithPassword:(NSString *)password andCompletionBlock:(void (^)(void))block {
    [self setCryptPassword:password];
    self.notesAreEncrypted = YES;
    [self copyCurrentDataToDropboxWithCompletionBlock:block];
}

- (void)decryptNotesWithCompletionBlock:(void (^)(void))block {
    [self setCryptPassword:nil];
    self.notesAreEncrypted = NO;
    [self copyCurrentDataToDropboxWithCompletionBlock:block];
}

- (BOOL)filesystemIsCrypted {
    NSError *error;
    DBPath *magicFile = [[DBPath root] childPath:kMagicCryptFilename];
    DBFile *magicTextFile = [[DBFilesystem sharedFilesystem] openFile:magicFile error:&error];
    BOOL retValue = YES;
    if(!magicTextFile) {
        retValue = NO;
    }
    [magicTextFile close];
    return retValue;
}

- (NSString *)cryptPassword {
    NSError *error;
    return [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:&error];
}

- (BOOL)isCryptOKWithError:(DBError **)errorPtr {
    NSString *cryptKey = [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:errorPtr];
    if(!cryptKey) {
        ALog(@"Error reading crypt key on cryptd note directory: %@", [*errorPtr description]);
        return NO;
    }
    return [self checkCryptPassword:cryptKey error:errorPtr];
}

- (BOOL)checkCryptPassword:(NSString *)password error:(DBError **)errorPtr {
    DBPath *magicFile = [[DBPath root] childPath:kMagicCryptFilename];
    DBFile *magicTextFile = [[DBFilesystem sharedFilesystem] openFile:magicFile error:errorPtr];
    if(!magicTextFile) {
        DLog(@"No magic file (%@). No crypt. (%@)", magicFile, [*errorPtr description]);
        return NO;
    }
    NSData *magicContent = [magicTextFile readData:errorPtr];
    [magicTextFile close];
    if(!magicContent) {
        DLog(@"No data in magic file (%@). No crypt. (%@)", magicFile, [*errorPtr description]);
        return NO;
    }
    NSData *decryptedData = [RNDecryptor decryptData:magicContent withPassword:password error:errorPtr];
    if(!decryptedData) {
        ALog(@"Error decrypting magic file on cryptd note directory: %@", [*errorPtr description]);
        return NO;
    }
    NSString *magicString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    if([magicString isEqualToString:kMagicString]) {
        return YES;
    }
    *errorPtr = [NSError errorWithDomain:@"it.iltofa.janus" code:1 userInfo:nil];
    return NO;
}

- (BOOL)writeString:(NSString *)text cryptedToDBFile:(DBFile *)file withError:(DBError **)errorPtr {
    if (self.notesAreEncrypted) {
        return [file writeData:[RNEncryptor encryptData:[text dataUsingEncoding:NSUTF8StringEncoding]
                                           withSettings:kRNCryptorAES256Settings
                                               password:self.cryptPassword
                                                  error:errorPtr] error:errorPtr];
        
    } else {
        return [file writeData:[text dataUsingEncoding:NSUTF8StringEncoding] error:errorPtr];
    }
}

- (NSString *)newStringDecryptedFromDBFile:(DBFile *)file withError:(DBError **)errorPtr {
    NSData *decryptedData = [file readData:errorPtr];
    if (self.notesAreEncrypted) {
        decryptedData = [RNDecryptor decryptData:decryptedData withPassword:self.cryptPassword error:errorPtr];
        if(!decryptedData) {
            DLog(@"A file content is corrupted or not encrypted, retrying read without encryption and resave crypted.");
            decryptedData = [file readData:errorPtr];
            [self writeString:[[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding] cryptedToDBFile:file withError:errorPtr];
        }
    }
    return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
}

#pragma mark - RefreshContent from dropbox

- (void)refreshContentFromRemote {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self syncAllFromDropbox];
}

#pragma mark - Readme file

-(void)addReadmeIfNeeded {
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"readmeAdded"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"readmeAdded"];
        dispatch_async(_syncQueue, ^{
            DLog(@"Adding readme note.");
            NSError *error;
            NSString *filePath = [[NSBundle mainBundle] pathForResource:@"readme" ofType:@"txt"];
            NSString *readmeText = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
            if (readmeText) {
                Note *readmeNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
                readmeNote.title = @"Read me!";
                readmeNote.text = readmeText;
                if(![self.dataSyncThreadContext save:&error]) {
                    ALog(@"Error saving readme note: %@,", [error description]);
                }
            } else {
                ALog(@"Error reading readme text from bundle: %@", [error description]);
            }
        });
    }
}

#pragma mark - handler propagating new (and updated) notes from coredata to dropbox

- (void)localContextSaved:(NSNotification *)notification {
    // Any change to our context will be reflected here.
    // Reflect them to the dropbox store UNLESS we're init loading from it (or we're not using dropbox)
    if(!_isResettingDataFromDropbox && self.syncControllerInited) {
        DLog(@"Propagating moc changes to dropbox");
        NSSet *deletedObjects = [notification.userInfo objectForKey:NSDeletedObjectsKey];
        NSMutableSet *changedObjects = [[NSMutableSet alloc] initWithSet:[notification.userInfo objectForKey:NSInsertedObjectsKey]];
        [changedObjects unionSet:[notification.userInfo objectForKey:NSUpdatedObjectsKey]];
        for(NSManagedObject *obj in deletedObjects){
            DLog(@"Deleted objects");
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"D - An attachment %@ from note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                [self deleteAttachmentInDropbox:(Attachment *)obj];
            } else {
                DLog(@"D - A note %@", ((Note *)obj).title);
                [self deleteNoteInDropbox:(Note *)obj];
            }
        }
        for(NSManagedObject *obj in changedObjects){
            DLog(@"changed objects");
            // If attachment get the corresponding note to insert
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                if(!((Attachment *)obj).note.title) {
                    DLog(@"* - An attachment (%@) with nil note", ((Attachment *)obj).filename);
                } else {
                    DLog(@"C - An attachment %@ for note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                    [self attachAttachment:(Attachment *)obj toNoteInDropbox:((Attachment *)obj).note];
                }
            } else {
                DLog(@"C - A note %@", ((Note *)obj).title);
                [self saveNoteToDropbox:(Note *)obj];
            }
        }
    }
    // In any case, merge back to mainview moc
//    DLog(@"propagating save to main UI moc");
    [self.coreDataController.mainThreadContext performBlock:^{
        [self.coreDataController.mainThreadContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

#pragma mark - from CoreData to Dropbox (first sync AND user changes to data)

// Copy all coredata db to dropbox (this is only if we have a new account)
- (void)copyCurrentDataToDropboxWithCompletionBlock:(void (^)(void))block; {
    dispatch_async(_syncQueue, ^{
        DLog(@"Started copy of coredata db to dropbox (new user here).");
        NSError *error;
        // Loop on the data set and dump to dropbox
        NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"Note"];
        [fr setIncludesPendingChanges:NO];
        NSSortDescriptor *sortKey = [NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES];
        [fr setSortDescriptors:@[sortKey]];
        NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fr error:&error];
        for (Note *note in notes) {
            [self saveNoteToDropbox:note];
        }
        [[NSUserDefaults standardUserDefaults] setValue:[DBAccountManager sharedManager].linkedAccount.userId forKey:@"currentDropboxAccount"];
        DLog(@"End copy of coredata db to dropbox. Executing block");
        if (block) {
            block();
        }
    });
}

// Save the passed note to dropbox
- (void)saveNoteToDropbox:(Note *)note {
    dispatch_async(_syncQueue, ^{
        DLog(@"Copying note %@ (%d attachments) to dropbox.", note.title, [note.attachment count]);
        DBError *error;
        DBPath *notePath = [[DBPath root] childPath:note.uuid];
        // Check if folder exists
        if(![[DBFilesystem sharedFilesystem] fileInfoForPath:notePath error:&error]) {
            // Create folder (named after uuid)
            if(![[DBFilesystem sharedFilesystem] createFolder:notePath error:&error]) {
                DLog(@"Creating folder to save note. Error %d creating folder at %@.", [error code], [notePath stringValue]);
            }
        }
        // write note
        NSString *encodedTitle = convertToValidDropboxFilenames(note.title);
        if(![[encodedTitle pathExtension] isEqualToString:kNotesExtension])
            encodedTitle = [encodedTitle stringByAppendingFormat:@".%@", kNotesExtension];
        DBPath *noteTextPath = [notePath childPath:encodedTitle];
        DBFile *noteTextFile;
        if(![[DBFilesystem sharedFilesystem] fileInfoForPath:noteTextPath error:&error]) {
            // tring to create it.
            noteTextFile = [[DBFilesystem sharedFilesystem] createFile:noteTextPath error:&error];
            if(!noteTextFile) {
                DLog(@"Creating file to save a new note to dropbox. Error %d creating file at %@.", [error code], [noteTextPath stringValue]);
            }
        } else {
            noteTextFile = [[DBFilesystem sharedFilesystem] openFile:noteTextPath error:&error];
        }
        // Mark the date in text at the start of the note..
        NSString *noteText = [NSString stringWithFormat:@"⏰%@\n☃%@\n%@", [note.timeStamp toRFC3339String], [note.creationDate toRFC3339String], note.text];
        if(![self writeString:noteText cryptedToDBFile:noteTextFile withError:&error]) {
            DLog(@"Error %d writing note text saving to dropbox at %@.", [error code], [noteTextPath stringValue]);
        }
        [noteTextFile close];
        // Now write all the attachments
        DBPath *attachmentPath = [notePath childPath:kAttachmentDirectory];
        if(![[DBFilesystem sharedFilesystem] fileInfoForPath:attachmentPath error:&error]) {
            if(![[DBFilesystem sharedFilesystem] createFolder:attachmentPath error:&error]) {
                DLog(@"Error creating attachment folder. Error %d creating folder at %@.", [error code], [attachmentPath stringValue]);
            }
        }
        for (Attachment *attachment in note.attachment) {
            // write attachment
            NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
            DBPath *attachmentDataPath = [attachmentPath childPath:encodedAttachmentName];
            DBFile *attachmentDataFile;
            if(![[DBFilesystem sharedFilesystem] fileInfoForPath:attachmentDataPath error:&error]) {
                [[DBFilesystem sharedFilesystem] createFile:attachmentDataPath error:&error];
                if(!attachmentDataFile) {
                    DLog(@"Error %d saving attachment file at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
                }
            } else {
                attachmentDataFile = [[DBFilesystem sharedFilesystem] openFile:attachmentDataPath error:&error];
            }
            if(![attachmentDataFile writeData:attachment.data error:&error]) {
                DLog(@"Error %d writing attachment data at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
            }
            [attachmentDataFile close];
        }
        NSArray *attachmentFiles = [[DBFilesystem sharedFilesystem] listFolder:attachmentPath error:&error];
        if(!attachmentFiles || [attachmentFiles count] == 0) {
            DLog(@"note %@ copied to dropbox, no attachments.", note.title);
            return;
        }
        for (DBFileInfo *fileInfo in attachmentFiles) {
            BOOL found = NO;
            for (Attachment *attachments in note.attachment) {
                if([attachments.filename isEqualToString:fileInfo.path.name]) {
                    found = YES;
                }
            }
            if(!found) {
                // Delete attachment file
                [[DBFilesystem sharedFilesystem] deletePath:fileInfo.path error:&error];
            }
        }
        DLog(@"note %@ copied to dropbox. %d attachments.", note.title, [attachmentFiles count]);
    });
}

- (void)attachAttachment:(Attachment *)attachment toNoteInDropbox:(Note *)note {
    dispatch_async(_syncQueue, ^{
        DLog(@"Attach attachment %@ to note %@.", attachment.filename, note.title);
        NSError *error;
        DBPath *notePath = [[DBPath root] childPath:note.uuid];
        DBPath *attachmentPath = [notePath childPath:kAttachmentDirectory];
        NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
        DBPath *attachmentDataPath = [attachmentPath childPath:encodedAttachmentName];
        DBFile *attachmentDataFile;
        if(![[DBFilesystem sharedFilesystem] fileInfoForPath:attachmentDataPath error:&error]) {
            attachmentDataFile = [[DBFilesystem sharedFilesystem] createFile:attachmentDataPath error:&error];
            if(!attachmentDataFile) {
                DLog(@"Error %d saving attachment file at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
            }
        } else {
            attachmentDataFile = [[DBFilesystem sharedFilesystem] openFile:attachmentDataPath error:&error];
        }
        if(![attachmentDataFile writeData:attachment.data error:&error]) {
            DLog(@"Error %d writing attachment data at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
        }
        [attachmentDataFile close];
    });
}

- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename {
    DLog(@"Delete note %@ in dropbox folder after change in filename from %@", uuid, oldFilename);
    DBError *error;
    NSString *encodedFilename = convertToValidDropboxFilenames(oldFilename);
    encodedFilename = [encodedFilename stringByAppendingFormat:@".%@", kNotesExtension];
    DBPath *noteTextPath = [[[DBPath root] childPath:uuid] childPath:encodedFilename];
    if(![[DBFilesystem sharedFilesystem] deletePath:noteTextPath error:&error]) {
        ALog(@"*** Error %d deleting note text after filename change at %@.", [error code], [noteTextPath stringValue]);
    } else {
        DLog(@"Note deleted.");
    }
}

- (void)deleteNoteInDropbox:(Note *)note {
    DLog(@"Delete note in dropbox folder");
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] deletePath:notePath error:&error]) {
        ALog(@"*** Error %d deleting note at %@.", [error code], [notePath stringValue]);
    }
}

- (void)deleteAttachmentInDropbox:(Attachment *)attachment {
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:attachment.note.uuid];
    DBPath *attachmentPath = [[notePath childPath:kAttachmentDirectory] childPath:attachment.filename];
    if(![[DBFilesystem sharedFilesystem] deletePath:attachmentPath error:&error]) {
        ALog(@"*** Error %d deleting attachment at %@.", [error code], [attachmentPath stringValue]);
    }
}

#pragma mark - from dropbox to core data

- (BOOL)isNoteExistingOnFile:(NSString *)uuid {
    NSError *error;
    NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
    if(!filesAtRoot) {
        ALog(@"Aborting. Error reading note on file: %d (%@)", [error code], [error description]);
        // Returning NO will delete the note on coredata (and then hopefully reload from dropbox)
        return NO;
    }
    BOOL retValue = NO;
    for (DBFileInfo *fileInfo in filesAtRoot) {
        if(fileInfo.isFolder) {
            if([fileInfo.path.name isEqualToString:uuid]) {
                retValue = YES;
                break;
            }
        }
    }
    return retValue;
}

- (void)syncAllFromDropbox {
    // Loop on the coredata existing data and delete whatever is not present on filesystem
    dispatch_async(_syncQueue, ^{
        DLog(@"Full sync start.");
        // Check crypt status.
        NSError *error;
        if(![self filesystemIsCrypted]) {
            self.notesAreEncrypted = NO;
            [self setCryptPassword:nil];
        } else {
            if([self isCryptOKWithError:&error]) {
                self.notesAreEncrypted = YES;
            } else {
                self.notesAreEncrypted = YES;
                self.needsSyncPassword = YES;
                DLog(@"Notes are crypted, password is wrong. Sending a notification now.");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncNeedsAPasswordNow object:self]];
                });
                return;
            }
        }
        _isResettingDataFromDropbox = YES;
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
        [fetchRequest setEntity:entity];
        [fetchRequest setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO]]];
        NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fetchRequest error:&error];
        for (Note *note in notes) {
            if(![self isNoteExistingOnFile:note.uuid]) {
                [self.dataSyncThreadContext deleteObject:note];
            }
        }
        // Save deleting (if any)
        if (![self.dataSyncThreadContext save:&error]) {
            ALog(@"Aborting. Error deleting all notes from dropbox to core data, error: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            _isResettingDataFromDropbox = NO;
            return;
        }
        // Loop on filesystem notes, look the id in coredata db and refresh coredata content if needed
        // Get notes ids
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            [self.dataSyncThreadContext rollback];
            _isResettingDataFromDropbox = NO;
            return;
        }
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                BOOL found = NO;
                for (Note *note in notes) {
                    if([fileInfo.path.name isEqualToString:note.uuid]) {
                        found = YES;
                        if([self saveDropboxNoteAt:fileInfo.path toExistingCoreDataNote:note]) {
                            if (![self.dataSyncThreadContext save:&error]) {
                                ALog(@"Error copying note %@ from dropbox to core data, error: %@", fileInfo.path.stringValue, [error description]);
                            }
                        }
                        break;
                    }
                }
                if(!found) {
                    // This is a new note
                    if([self saveDropboxNoteAt:fileInfo.path toExistingCoreDataNote:nil]) {
                        if (![self.dataSyncThreadContext save:&error]) {
                            ALog(@"Error copying note %@ from dropbox to core data, error: %@", fileInfo.path.stringValue, [error description]);
                        }
                    }
                }
            } else {
                if(![fileInfo.path.name isEqualToString:kMagicCryptFilename]) {
                    DLog(@"Deleting spurious file at notes dropbox root: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
                    [[DBFilesystem sharedFilesystem] deletePath:fileInfo.path error:&error];
                }
            }
        }
        DLog(@"Full sync end.");
        _isResettingDataFromDropbox = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncRefreshTerminated object:self]];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
    });
}

// Save the note from dropbox folder to CoreData
- (BOOL)saveDropboxNoteAt:(DBPath *)pathToNoteDir toExistingCoreDataNote:(Note *)note {
    // BEWARE that this code needs to be called in the _syncqueue dispatch_queue beacuse it's using dataSyncThreadContext
    Note *newNote = nil;
    DBError *error;
    NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
    if(!filesInNoteDir) {
        ALog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
        return NO;
    }
    for (DBFileInfo *fileInfo in filesInNoteDir) {
        if(!fileInfo.isFolder) {
            // if note is nil
            if(!note) {
                newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            } else {
                // Kill existing attachments (eventually reloaded later)
                [note removeAttachment:note.attachment];
                newNote = note;
            }
            newNote.uuid = pathToNoteDir.name;
            NSString *titolo = convertFromValidDropboxFilenames(fileInfo.path.name);
            if([titolo hasSuffix:kNotesExtension]) {
                titolo = [titolo substringToIndex:([titolo length] - ([kNotesExtension length] + 1))];
            }
            newNote.title = titolo;
            newNote.creationDate = newNote.timeStamp = fileInfo.modifiedTime;
            DBFile *noteOnDropbox = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
            if(!noteOnDropbox) {
                ALog(@"Aborting note copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                [self.dataSyncThreadContext rollback];
                return NO;
            }
            if(!noteOnDropbox.status.state == DBFileStateIdle || !noteOnDropbox.status.cached) {
                // If the file is not stable, abort copy
                DLog(@"Note %@ still pending sync.", fileInfo.path.stringValue);
                [noteOnDropbox close];
                [self.dataSyncThreadContext rollback];
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncStillPendingChanges object:self]];
                return NO;
            }
            NSString *noteText = [self newStringDecryptedFromDBFile:noteOnDropbox withError:&error];
            if(!noteText) {
                DLog(@"Serious error reading note %@: %d (%@)", fileInfo.path.stringValue, [error code], [error description]);
            }
            // Now get "real" date from file (if any)
            if([noteText length] > 22 && [noteText characterAtIndex:0] == 0x23f0) { // ⏰ ALARM CLOCK Unicode: U+23F0, UTF-8: E2 8F B0
                // Date is embedded in the first row of text as '⏰2013-06-27T12:02:34Z\n'
                NSString *dateString = [noteText substringWithRange:NSMakeRange(1, 20)];
                newNote.timeStamp = [NSDate dateFromRFC3339String:dateString];
                noteText = [noteText substringFromIndex:22];
                if([noteText length] > 22 && [noteText characterAtIndex:0] == 0x2603) { // ☃ SNOWMAN Unicode: U+2603, UTF-8: e2 98 83
                    // Creation date is embedded in the second row of text as '☃2013-06-27T12:02:34Z\n'
                    NSString *dateString = [noteText substringWithRange:NSMakeRange(1, 20)];
                    newNote.creationDate = [NSDate dateFromRFC3339String:dateString];
                    noteText = [noteText substringFromIndex:22];
                }
            }
            newNote.text = noteText;
            [noteOnDropbox close];
            break;
        }
    }
    // Now copy attachment(s) (if note exists)
    if(newNote) {
        DBPath *attachmentsPath = [pathToNoteDir childPath:kAttachmentDirectory];
        if(![[DBFilesystem sharedFilesystem] fileInfoForPath:attachmentsPath error:&error]) {
            // No attachments directory -> No attachments
            DLog(@"Attachment directory for note %@ not existing.", newNote.title);
            if(![[DBFilesystem sharedFilesystem] createFolder:attachmentsPath error:&error]) {
                DLog(@"Error creating attachment folder. Error %d creating folder at %@.", [error code], [attachmentsPath stringValue]);
            }
            return YES;
        }
        NSArray *filesInAttachmentDir = [[DBFilesystem sharedFilesystem] listFolder:attachmentsPath error:&error];
        if(!filesInAttachmentDir) {
            // No attachments directory -> No attachments
            DLog(@"Error: cannot list files in attachment directory for note %@, no attachments then.", newNote.title);
            return YES;
        }
        for (DBFileInfo *attachmentInfo in filesInAttachmentDir) {
            DBFile *attachmentOnDropbox = [[DBFilesystem sharedFilesystem] openFile:attachmentInfo.path error:&error];
            if(!attachmentOnDropbox) {
                ALog(@"Aborting attachment copy to coredata. Error %d opening attachment %@", [error code], attachmentInfo.path.stringValue);
                continue;
            }
            if(!attachmentOnDropbox.status.state == DBFileStateIdle || !attachmentOnDropbox.status.cached) {
                // If the file is not stable, abort copy
                DLog(@"Attachment file %@ is still in sync.", attachmentInfo.path.stringValue);
                [self.dataSyncThreadContext rollback];
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncStillPendingChanges object:self]];
                [attachmentOnDropbox close];
                return NO;
            }
            DLog(@"Copying attachment: %@ to CoreData note %@", attachmentInfo.path.name, newNote.title);
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.dataSyncThreadContext];
            newAttachment.filename = attachmentInfo.path.name;
            newAttachment.extension = [attachmentInfo.path.stringValue pathExtension];
            newAttachment.data = [attachmentOnDropbox readData:&error];
            if(!newAttachment.data) {
                DLog(@"Serious error (data loss?) reading attachment %@: %d", attachmentInfo.path.stringValue, [error code]);
            }
            // Now link attachment to the note
            newAttachment.note = newNote;
            [newNote addAttachmentObject:newAttachment];
            [attachmentOnDropbox close];
        }
    }
    filesInNoteDir = nil;
    return YES;
}

@end
