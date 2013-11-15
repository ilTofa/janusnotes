//
//  IAMFilesystemSyncController.m
//  Janus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMFilesystemSyncController.h"

#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "Note.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "STKeychain.h"
#import "NSDate+GTStringsHelpers.h"

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

@interface IAMFilesystemSyncController() {
    dispatch_queue_t _syncQueue;
    BOOL _isResettingDataFromDropbox;
}

@property (weak) CoreDataController *coreDataController;

@property NSData *secureBookmarkToData;
@property NSURL *syncDirectory;

@end

@implementation IAMFilesystemSyncController

+ (IAMFilesystemSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMFilesystemSyncController *_sharedObject = nil;
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
        self.coreDataController = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController;
        NSAssert(self.coreDataController.psc, @"DataSyncController inited when CoreDataController Persistent Storage is still invalid");
        _syncQueue = dispatch_queue_create("dataSyncControllerQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_syncQueue, ^{
            _dataSyncThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_dataSyncThreadContext setPersistentStoreCoordinator:self.coreDataController.psc];
        });
        _isResettingDataFromDropbox = NO;
        // Init security bookmark
        NSError *error;
        _secureBookmarkToData = [[NSUserDefaults standardUserDefaults] dataForKey:@"syncDirectory"];
        if(!_secureBookmarkToData) {
            _notesAreEncrypted = NO;
            NSURL *cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
            _syncDirectory = [cacheDirectory URLByAppendingPathComponent:@"Janus-Notes" isDirectory:YES];
            [[NSFileManager defaultManager] createDirectoryAtURL:_syncDirectory withIntermediateDirectories:YES attributes:nil error:&error];
            [self modifySyncDirectory:_syncDirectory];
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncSelectedDefaulDir object:self]];
        } else {
            BOOL staleData;
            _syncDirectory = [NSURL URLByResolvingBookmarkData:_secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:&staleData error:&error];
            [_syncDirectory startAccessingSecurityScopedResource];
            [self firstAccessToData];
        }
        // Listen to ourself, so to sync changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localContextSaved:) name:NSManagedObjectContextDidSaveNotification object:_dataSyncThreadContext];
    }
    return self;
}

- (BOOL)modifySyncDirectory:(NSURL *)newSyncDirectory {
    NSError *error;
    BOOL alreadySyncingToPrivilegedDir = NO;
    // Remove security access if any before
    if(self.secureBookmarkToData)
        alreadySyncingToPrivilegedDir = YES;
    self.secureBookmarkToData = [newSyncDirectory bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if(!self.secureBookmarkToData) {
        DLog(@"Error creating secure bookmark!");
        return FALSE;
    }
    [[NSUserDefaults standardUserDefaults] setObject:self.secureBookmarkToData forKey:@"syncDirectory"];
    if(alreadySyncingToPrivilegedDir)
        [self.syncDirectory stopAccessingSecurityScopedResource];
    BOOL staleData;
    self.syncDirectory = [NSURL URLByResolvingBookmarkData:self.secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:&staleData error:&error];
    [self.syncDirectory startAccessingSecurityScopedResource];
    [self copyCurrentDataToDropboxWithCompletionBlock:^{
        [self firstAccessToData];        
    }];
    return YES;
}

- (void)firstAccessToData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self syncAllFromDropbox];
        DLog(@"IAMDataSyncController is ready.");
        self.syncControllerReady = YES;
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
    });
}

#pragma mark - RefreshContent from dropbox

- (void)refreshContentFromRemote {
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

#pragma mark - Crypt support

- (void)setCryptPassword:(NSString *)password {
    NSError *error;
    NSURL *magicFile = [self.syncDirectory URLByAppendingPathComponent:kMagicCryptFilename isDirectory:NO];
    if(password) {
        [STKeychain storeUsername:@"crypt" andPassword:password forServiceName:@"it.iltofa.janus" updateExisting:YES error:&error];
        NSData *magicContent = [kMagicString dataUsingEncoding:NSUTF8StringEncoding];
        NSData *encryptedData = [RNEncryptor encryptData:magicContent withSettings:kRNCryptorAES256Settings password:password error:&error];
        [encryptedData writeToURL:magicFile atomically:YES];
    } else {
        [STKeychain deleteItemForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:&error];
        [[NSFileManager defaultManager] removeItemAtURL:magicFile error:&error];
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
    NSURL *magicFile = [self.syncDirectory URLByAppendingPathComponent:kMagicCryptFilename isDirectory:NO];
    NSData *magicContent = [NSData dataWithContentsOfURL:magicFile options:NSDataReadingMappedIfSafe error:&error];
    if(!magicContent) {
        return NO;
    }
    return YES;
}

- (NSString *)cryptPassword {
    NSError *error;
    return [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:&error];
}

- (BOOL)isCryptOKWithError:(NSError **)errorPtr {
    NSString *cryptKey = [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.janus" error:errorPtr];
    if(!cryptKey) {
        ALog(@"Error reading crypt key on cryptd note directory: %@", [*errorPtr description]);
        return NO;
    }
    return [self checkCryptPassword:cryptKey error:errorPtr];
}

- (BOOL)checkCryptPassword:(NSString *)password error:(NSError **)errorPtr {
    NSURL *magicFile = [self.syncDirectory URLByAppendingPathComponent:kMagicCryptFilename isDirectory:NO];
    NSData *magicContent = [NSData dataWithContentsOfURL:magicFile options:NSDataReadingMappedIfSafe error:errorPtr];
    if(!magicContent) {
        DLog(@"No data in magic file (%@) or no magic file. No crypt. (%@)", magicFile, [*errorPtr description]);
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

- (BOOL)writeString:(NSString *)text cryptedToURL:(NSURL *)url withError:(NSError **)errorPtr {
    if (self.notesAreEncrypted) {
        return [[RNEncryptor encryptData:[text dataUsingEncoding:NSUTF8StringEncoding]
                            withSettings:kRNCryptorAES256Settings
                                password:self.cryptPassword
                                   error:errorPtr] writeToURL:url atomically:YES];

    } else {
        return [[text dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES];
    }
}

- (NSString *)newStringDecryptedFromURL:(NSURL *)url withError:(NSError **)errorPtr {
    if (self.notesAreEncrypted) {
        NSData *decryptedData = [RNDecryptor decryptData:[NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:errorPtr]
                                            withPassword:self.cryptPassword
                                                   error:errorPtr];
        if(!decryptedData) {
            DLog(@"A file content is corrupted or not encrypted, retrying read without encryption and resave crypted.");
            decryptedData = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:errorPtr];
            [self writeString:[[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding] cryptedToURL:url withError:errorPtr];
        }
        return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    } else {
        return [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:errorPtr];
    }
}

#pragma mark - handler propagating new (and updated) notes from coredata to dropbox

- (void)localContextSaved:(NSNotification *)notification {
    // Any change to our context will be reflected here.
    // Propagate them also to the dropbox store UNLESS we're init loading from it
    if(!_isResettingDataFromDropbox) {
//        DLog(@"Propagating moc changes to dropbox");
        NSSet *deletedObjects = [notification.userInfo objectForKey:NSDeletedObjectsKey];
        NSMutableSet *changedObjects = [[NSMutableSet alloc] initWithSet:[notification.userInfo objectForKey:NSInsertedObjectsKey]];
        [changedObjects unionSet:[notification.userInfo objectForKey:NSUpdatedObjectsKey]];
        for(NSManagedObject *obj in deletedObjects){
//            DLog(@"Deleted objects");
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                if(!((Attachment *)obj).note) {
                    ALog(@"Deleted attachment belongs to a nil note, don't delete!");
                } else {
                    DLog(@"D - An attachment %@ from note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                    [self deleteAttachmentInDropbox:(Attachment *)obj];
                }
            } else {
                DLog(@"D - A note %@", ((Note *)obj).title);
                [self deleteNoteInDropbox:(Note *)obj];
            }
        }
        for(NSManagedObject *obj in changedObjects){
//            DLog(@"changed objects");
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
    [self.coreDataController.mainThreadContext performBlock:^{
        [self.coreDataController.mainThreadContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

#pragma mark - from CoreData to Dropbox (first sync AND user changes to data)

// Copy all coredata db to dropbox (this is when we move to a new directory for syncing or when we change sync password)
- (void)copyCurrentDataToDropboxWithCompletionBlock:(void (^)(void))block; {
    dispatch_async(_syncQueue, ^{
        DLog(@"Started copy of coredata db to dropbox (new directory here).");
        // Loop on the data set and dump to dropbox
        NSError *error;
        NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"Note"];
        [fr setIncludesPendingChanges:NO];
        NSSortDescriptor *sortKey = [NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES];
        [fr setSortDescriptors:@[sortKey]];
        NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fr error:&error];
        for (Note *note in notes) {
            [self saveNoteToDropbox:note];
        }
        self.syncControllerReady = YES;
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
        DLog(@"End copy of coredata db to dropbox. Executing block");
        if (block) {
            block();
        }
    });
}

// Save the passed note to dropbox
- (void)saveNoteToDropbox:(Note *)note {
//    DLog(@"Copying note %@ (%ld attachments) to dropbox.", note.title, (unsigned long)[note.attachment count]);
    NSError *error;
    // Create folder (named after uuid)
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    if(![[NSFileManager defaultManager] createDirectoryAtURL:notePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        DLog(@"Creating folder to save note. Error could be 'normal'. Error creating folder at %@: %@.", notePath, [error description]);
    }
    // write note
    NSString *encodedTitle = convertToValidDropboxFilenames(note.title);
    if(![[encodedTitle pathExtension] isEqualToString:kNotesExtension])
        encodedTitle = [encodedTitle stringByAppendingFormat:@".%@", kNotesExtension];
    NSURL *noteTextPath = [notePath URLByAppendingPathComponent:encodedTitle isDirectory:NO];
    // Mark the date in text at the start of the note..
    NSString *noteText = [NSString stringWithFormat:@"⏰%@\n☃%@\n%@", [note.timeStamp toRFC3339String], [note.creationDate toRFC3339String], note.text];
    if(![self writeString:noteText cryptedToURL:noteTextPath withError:&error]) {
        DLog(@"Error writing note text saving to dropbox at %@: %@.", noteTextPath, [error description]);
    }
    // Now write all the attachments
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    // Check Attachment directory
    if(![[NSFileManager defaultManager] createDirectoryAtURL:attachmentPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        DLog(@"Error creating attachment directory, probably it's OK. %@", [error description]);
    }
    for (Attachment *attachment in note.attachment) {
        // write attachment
        NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
        NSURL *attachmentDataPath = [attachmentPath URLByAppendingPathComponent:encodedAttachmentName isDirectory:NO];
        if(![attachment.data writeToURL:attachmentDataPath atomically:YES]) {
            DLog(@"Error writing attachment data at %@ for note %@: %@", attachmentDataPath, note.title, [error description]);
        }
    }
    // Now ensure that no stale attachments are still in the dropbox
    NSURL *attachmentsPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    NSArray *attachmentFiles =  [[NSFileManager defaultManager] contentsOfDirectoryAtURL:attachmentsPath
                                                              includingPropertiesForKeys:@[NSURLNameKey]
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    if(!attachmentFiles || [attachmentFiles count] == 0) {
        // No attachments directory -> No attachments
        DLog(@"note %@ copied to dropbox.", note.title);
        return;
    }

    for (NSURL *fileInfo in attachmentFiles) {
        BOOL found = NO;
        NSString *name;
        if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ALog(@"error looking for filename: %@", [error localizedDescription]);
            error = nil;
        }
        for (Attachment *attachments in note.attachment) {
            if([attachments.filename isEqualToString:name]) {
                found = YES;
            }
        }
        if(!found) {
            // Delete attachment file
            [[NSFileManager defaultManager] removeItemAtURL:fileInfo error:&error];
        }
    }
    DLog(@"note %@ copied to dropbox.", note.title);
}

- (void)attachAttachment:(Attachment *)attachment toNoteInDropbox:(Note *)note {
    DLog(@"Attach attachment %@ to note %@.", attachment.filename, note.title);
    NSError *error;
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    // Check Attachment directory
    if(![[NSFileManager defaultManager] createDirectoryAtURL:attachmentPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        DLog(@"Error creating attachment directory, probably it's OK. %@", [error description]);
    }
    NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
    NSURL *attachmentDataPath = [attachmentPath URLByAppendingPathComponent:encodedAttachmentName isDirectory:NO];
    if(![attachment.data writeToURL:attachmentDataPath atomically:YES]) {
        DLog(@"Error writing attachment data at %@ for note %@: %@", attachmentDataPath, note.title, [error description]);
    }
}

- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename {
    DLog(@"Delete note %@ in dropbox folder after change in filename from %@", uuid, oldFilename);
    NSError *error;
    NSString *encodedFilename = convertToValidDropboxFilenames(oldFilename);
    encodedFilename = [encodedFilename stringByAppendingFormat:@".%@", kNotesExtension];
    NSURL *noteTextPath = [[self.syncDirectory URLByAppendingPathComponent:uuid isDirectory:YES] URLByAppendingPathComponent:encodedFilename isDirectory:NO];
    if(![[NSFileManager defaultManager] removeItemAtURL:noteTextPath error:&error]) {
        ALog(@"*** Error deleting note text after filename change at %@: %@", noteTextPath, [error description]);
    } else {
        DLog(@"Note deleted.");
    }
}

- (void)deleteNoteInDropbox:(Note *)note {
    DLog(@"Delete note in dropbox folder");
    NSError *error;
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    if(![[NSFileManager defaultManager] removeItemAtURL:notePath error:&error]) {
        ALog(@"*** Error deleting note at %@: %@", notePath, [error description]);
    }
}

- (NSURL *)urlForNote:(Note *)note {
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    NSString *encodedTitle = convertToValidDropboxFilenames(note.title);
    if(![[encodedTitle pathExtension] isEqualToString:kNotesExtension])
        encodedTitle = [encodedTitle stringByAppendingFormat:@".%@", kNotesExtension];
    NSURL *noteTextPath = [notePath URLByAppendingPathComponent:encodedTitle isDirectory:NO];
    return noteTextPath;
}

- (void)deleteAttachmentInDropbox:(Attachment *)attachment {
    NSError *error;
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:attachment.note.uuid isDirectory:YES];
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    attachmentPath = [attachmentPath URLByAppendingPathComponent:attachment.filename isDirectory:NO];
    if(![[NSFileManager defaultManager] removeItemAtURL:attachmentPath error:&error]) {
        ALog(@"*** Error deleting attachment at %@: %@",attachmentPath, [error description]);
    }
}

- (NSURL *)urlForAttachment:(Attachment *)attachment {
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:attachment.note.uuid isDirectory:YES];
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    attachmentPath = [attachmentPath URLByAppendingPathComponent:attachment.filename isDirectory:NO];
    return attachmentPath;
}

#pragma mark - from dropbox to core data

- (BOOL)isNoteExistingOnFile:(NSString *)uuid {
    NSError *error;
    NSArray *filesAtRoot = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.syncDirectory
                                                         includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                            options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    if(!filesAtRoot) {
        ALog(@"Aborting. Error reading notes: %@", [error description]);
        // Returning NO will delete the note on coredata (and then hopefully reload from dropbox)
        return NO;
    }
    BOOL retValue = NO;
    for (NSURL *fileInfo in filesAtRoot) {
        NSNumber *isDirectory;
        NSString *name;
        if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ALog(@"error looking for filename: %@", [error localizedDescription]);
            error = nil;
        }
        if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            ALog(@"Error looking for directory type: %@", [error localizedDescription]);
            error = nil;
        }
        if(isDirectory) {
            if([name isEqualToString:uuid]) {
                retValue = YES;
                break;
            }
        }
    }
    return retValue;
}

- (void)syncAllFromDropbox {
    dispatch_async(_syncQueue, ^{
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
                DLog(@"Notes are crypted, password is wrong. Sending a notification now.");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncNeedsAPasswordNow object:self]];
                });
                return;
            }
        }
        _isResettingDataFromDropbox = YES;
        DLog(@"Massaging current coreData db init");
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
        // Save deleting
        if (![self.dataSyncThreadContext save:&error]) {
            ALog(@"Aborting. Error deleting all notes from dropbox to core data, error: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            _isResettingDataFromDropbox = NO;
            return;
        }
        // Get notes ids
        NSArray *filesAtRoot = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.syncDirectory
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            _isResettingDataFromDropbox = NO;
            return;
        }
        for (NSURL *fileInfo in filesAtRoot) {
            NSNumber *isDirectory;
            NSString *name;
            if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                ALog(@"error looking for filename: %@", [error localizedDescription]);
                error = nil;
            }
            if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
                ALog(@"Error looking for directory type: %@", [error localizedDescription]);
                error = nil;
            }
            if(isDirectory) {
                BOOL found = NO;
                for (Note *note in notes) {
                    if([name isEqualToString:note.uuid]) {
                        found = YES;
                        if([self saveDropboxNoteAt:fileInfo toExistingCoreDataNote:note]) {
                            if (![self.dataSyncThreadContext save:&error]) {
                                ALog(@"Error copying note %@ from dropbox to core data, error: %@", name, [error description]);
                            }
                        }
                        break;
                    }
                }
                if(!found) {
                    if([self saveDropboxNoteAt:fileInfo toExistingCoreDataNote:nil]) {
                        if (![self.dataSyncThreadContext save:&error]) {
                            ALog(@"Error copying note %@ from dropbox to core data, error: %@", name, [error description]);
                        }
                    }                    
                }
                
            } else {
                if(![name isEqualToString:kMagicCryptFilename]) {
                    DLog(@"Deleting spurious file at notes root: %@.", name);
                    [[NSFileManager defaultManager] removeItemAtURL:fileInfo error:&error];
                }
            }
        }
        DLog(@"Syncronization end");
        _isResettingDataFromDropbox = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self addReadmeIfNeeded];
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncRefreshTerminated object:self]];
        });
    });
}

// Save the note from dropbox folder to CoreData
- (BOOL)saveDropboxNoteAt:(NSURL *)pathToNoteDir toExistingCoreDataNote:(Note *)note {
    // BEWARE that this code needs to be called in the _syncqueue dispatch_queue beacuse it's using dataSyncThreadContext
    Note *newNote = nil;
    NSError *error;
    NSMutableArray *filesInNoteDir = [[[NSFileManager defaultManager] contentsOfDirectoryAtURL:pathToNoteDir
                                                                    includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey, NSURLContentModificationDateKey]
                                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles error:&error] mutableCopy];
    if(!filesInNoteDir) {
        ALog(@"Aborting. Error reading notes: %@", [error description]);
        return NO;
    }
    for (NSURL *fileInfo in filesInNoteDir) {
        NSNumber *isDirectory;
        NSString *name;
        NSDate *modificationDate;
        if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ALog(@"error looking for filename: %@", [error localizedDescription]);
            error = nil;
        }
        if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            ALog(@"Error looking for directory type: %@", [error localizedDescription]);
            error = nil;
        }
        if (![fileInfo getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:&error]) {
            ALog(@"Error looking for modificationDate: %@", [error localizedDescription]);
            error = nil;
        }
        if(![isDirectory boolValue]) {
            // This is the note
//            DLog(@"Copying note %@ to CoreData", name);
            // if note is nil
            if(!note) {
                newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            } else {
                newNote = note;
                // Kill existing attachments and reload.
                [newNote removeAttachment:newNote.attachment];
            }
            newNote.uuid = [[pathToNoteDir path] lastPathComponent];
            NSString *titolo = convertFromValidDropboxFilenames([[fileInfo path] lastPathComponent]);
            if([titolo hasSuffix:kNotesExtension]) {
                titolo = [titolo substringToIndex:([titolo length] - ([kNotesExtension length] + 1))];
            }
            newNote.title = titolo;
            newNote.creationDate = newNote.timeStamp = modificationDate;
            NSString *noteText = [self newStringDecryptedFromURL:fileInfo withError:&error];
            if(!noteText) {
                ALog(@"Serious error reading note %@: %@", fileInfo, [error description]);
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
            break;
        }
    }
    // Now copy attachment(s) (if note exists)
    if(newNote) {
        NSURL *attachmentsPath = [pathToNoteDir URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
        NSArray *filesInAttachmentDir =  [[NSFileManager defaultManager] contentsOfDirectoryAtURL:attachmentsPath
                                                                       includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesInAttachmentDir || [filesInAttachmentDir count] == 0) {
            // No attachments directory -> No attachments
            return YES;
        }
        for (NSURL *attachmentInfo in filesInAttachmentDir) {
            NSNumber *isDirectory;
            NSString *name;
            if (![attachmentInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                ALog(@"error looking for filename: %@", [error localizedDescription]);
                error = nil;
            }
            if (![attachmentInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
                ALog(@"Error looking for directory type: %@", [error localizedDescription]);
                error = nil;
            }
            DLog(@"Copying attachment %@ to CoreData note %@", name, newNote.title);
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.dataSyncThreadContext];
            newAttachment.filename = [[attachmentInfo path] lastPathComponent];
            newAttachment.extension = attachmentInfo.path.pathExtension;
            newAttachment.data = [NSData dataWithContentsOfURL:attachmentInfo options:NSDataReadingMappedIfSafe error:&error];
            if(!newAttachment.data) {
                ALog(@"Serious error (data loss?) reading attachment %@: %@", attachmentInfo, [error description]);
            }
            // Now link attachment to the note
            newAttachment.note = newNote;
            [newNote addAttachmentObject:newAttachment];
        }        
    }
    filesInNoteDir = nil;
    return YES;
}

@end
