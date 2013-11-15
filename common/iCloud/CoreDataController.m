
/*
     File: CoreDataController.m
 Abstract: 
 
  Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 
 WWDC 2012 License
 
 NOTE: This Apple Software was supplied by Apple as part of a WWDC 2012
 Session. Please refer to the applicable WWDC 2012 Session for further
 information.
 
 IMPORTANT: This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a non-exclusive license, under
 Apple's copyrights in this original Apple software (the "Apple
 Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "CoreDataController.h"

#import "Note.h"
#import "Attachment.h"

#import "NSString+UUID.h"

NSString * kiCloudPersistentStoreFilename = @"iCloudStore.sqlite";
NSString * kFallbackPersistentStoreFilename = @"fallbackStore.sqlite"; //used when iCloud is not available
NSString * kSeedStoreFilename = @"seedStore.sqlite"; //holds the seed person records
NSString * kLocalStoreFilename = @"localStore.sqlite"; //holds the states information

#define SEED_ICLOUD_STORE NO
#define FORCE_FALLBACK_STORE

static NSOperationQueue *_presentedItemOperationQueue;

@interface CoreDataController (Private)

- (BOOL)iCloudAvailable;

- (BOOL)loadLocalPersistentStore:(NSError *__autoreleasing *)error;
- (BOOL)loadFallbackStore:(NSError * __autoreleasing *)error;
- (BOOL)loadiCloudStore:(NSError * __autoreleasing *)error;
- (void)asyncLoadPersistentStores;
- (void)dropStores;
- (void)reLoadiCloudStore:(NSPersistentStore *)store readOnly:(BOOL)readOnly;

- (void)deDupe:(NSNotification *)importNotification;

- (void)addNote:(Note *)hexagram toStore:(NSPersistentStore *)store withContext:(NSManagedObjectContext *)moc;
- (BOOL)seedStore:(NSPersistentStore *)store withPersistentStoreAtURL:(NSURL *)seedStoreURL error:(NSError * __autoreleasing *)error;

- (void)copyContainerToSandbox;
- (void)nukeAndPave;

- (NSURL *)iCloudStoreURL;
- (NSURL *)seedStoreURL;
- (NSURL *)fallbackStoreURL;
- (NSURL *)applicationSandboxStoresDirectory;
- (NSString *)applicationDocumentsDirectory;

@end

@implementation CoreDataController
{
    NSLock *_loadingLock;
    NSURL *_presentedItemURL;
}

+ (void)initialize {
    if (self == [CoreDataController class]) {
        _presentedItemOperationQueue = [[NSOperationQueue alloc] init];
    }
}

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _loadingLock = [[NSLock alloc] init];
    _ubiquityURL = nil;
    _currentUbiquityToken = nil;
    _presentedItemURL = nil;
    _coreDataIsReady = NO;
    
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:nil];
    _psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    _mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_mainThreadContext setPersistentStoreCoordinator:_psc];
    if([NSFileManager instancesRespondToSelector:@selector(ubiquityIdentityToken)])
    {
        DLog(@"iOS6+/OSX10.8+");
        _currentUbiquityToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
        //subscribe to the account change notification
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(iCloudAccountChanged:)
                                                     name:NSUbiquityIdentityDidChangeNotification
                                                   object:nil];
    }
    else
    {
        NSURL *iCloudContainer = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        if(iCloudContainer)
        {
            DLog(@"iOS5+/OSX10.7+");
            _currentUbiquityToken = iCloudContainer;
        }
        else // iCloud not available
        {
            DLog(@"Legacy OS");
            _currentUbiquityToken = nil;
        }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(persistentStoreChanged:)
                                                 name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                               object:_psc];
    return self;
}


- (void)persistentStoreChanged:(NSNotification *)notification
{
    DLog(@"*** this is NSPersistentStoreDidImportUbiquitousContentChangesNotification called with: %@", notification);
    [CoreDataController mergeiCloudChangeNotification:notification withManagedObjectContext:self.mainThreadContext];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)iCloudAvailable {
#ifdef FORCE_FALLBACK_STORE
    BOOL available = NO;
#else
    BOOL available = (_currentUbiquityToken != nil);
#endif
    return available;
}

- (void)applicationResumed {
    id token = [[NSFileManager defaultManager] ubiquityIdentityToken];
    if (self.currentUbiquityToken != token) {
        if (NO == [self.currentUbiquityToken isEqual:token]) {
            [self iCloudAccountChanged:nil];
        }
    }
}

- (void)iCloudAccountChanged:(NSNotification *)notification {
    //tell the UI to clean up while we re-add the store
    [self dropStores];
    
    // update the current ubiquity token
    id token = [[NSFileManager defaultManager] ubiquityIdentityToken];
    _currentUbiquityToken = token;
    
    //reload persistent store
    [self loadPersistentStores];
}

#pragma mark Managing the Persistent Stores
- (void)loadPersistentStores {
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(globalQueue, ^{
        BOOL locked = NO;
        @try {
            [_loadingLock lock];
            locked = YES;
            [self asyncLoadPersistentStores];
        } @finally {
            if (locked) {
                [_loadingLock unlock];
                locked = NO;
            }
        }
    });
}

- (BOOL)loadLocalPersistentStore:(NSError *__autoreleasing *)error {
    BOOL success = YES;
    NSError *localError = nil;
    
    if (_localStore) {
        return success;
    }
    
    NSURL *storeURL = [[self applicationSandboxStoresDirectory] URLByAppendingPathComponent:kLocalStoreFilename];
    //add the store, use the "LocalConfiguration" to make sure state entities all end up in this store and that no iCloud entities end up in it
    // ~/Library/Caches/Metadata/CoreData or ~/Library/CoreData
    NSURL *cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSLibraryDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&localError];
    cacheDirectory = [cacheDirectory URLByAppendingPathComponent:@"CoreData/ExternalRecords" isDirectory:YES];
    if(![[NSFileManager defaultManager] createDirectoryAtURL:cacheDirectory withIntermediateDirectories:YES attributes:nil error:&localError]) {
        ALog(@"Error creating %@: %@", cacheDirectory, [localError description]);
        assert(NO);
    }
#if TARGET_OS_IPHONE
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES,
                              };
#else
    NSString *externalRecordsSupportFolder = [cacheDirectory path];
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES,
                              NSExternalRecordExtensionOption: @"janus",
                              NSExternalRecordsDirectoryOption: externalRecordsSupportFolder,
                              NSExternalRecordsFileFormatOption: NSBinaryExternalRecordType
                              };
#endif
    _localStore = [_psc addPersistentStoreWithType:NSSQLiteStoreType
                                     configuration:@"LocalConfig"
                                               URL:storeURL
                                           options:options
                                             error:&localError];
    success = (_localStore != nil);
    if (success == NO) {
        //ruh roh
        if (localError && (error != NULL)) {
            *error = localError;
        }
    }
    
    return success;
}

- (BOOL)loadFallbackStore:(NSError * __autoreleasing *)error {
    BOOL success = YES;
    NSError *localError = nil;
    
    if (_fallbackStore) {
        return YES;
    }
    NSURL *storeURL = [self fallbackStoreURL];
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES};
    _fallbackStore = [_psc addPersistentStoreWithType:NSSQLiteStoreType
                                        configuration:@"CloudConfig"
                                                  URL:storeURL
                                              options:options
                                                error:&localError];
    success = (_fallbackStore != nil);
    if (NO == success) {
        if (localError  && (error != NULL)) {
            *error = localError;
        }
    }
    
    return success;
}

- (BOOL)loadiCloudStore:(NSError * __autoreleasing *)error {
    BOOL success = YES;
    NSError *localError = nil;
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    _ubiquityURL = [fm URLForUbiquityContainerIdentifier:nil];
    
    NSURL *iCloudStoreURL = [self iCloudStoreURL];
    NSURL *iCloudDataURL = [self.ubiquityURL URLByAppendingPathComponent:@"iCloudData"];
    NSDictionary *options = @{ NSPersistentStoreUbiquitousContentNameKey : @"iCloudStore",
                               NSPersistentStoreUbiquitousContentURLKey : iCloudDataURL,
                               NSMigratePersistentStoresAutomaticallyOption: @YES,
                               NSInferMappingModelAutomaticallyOption: @YES };
    _iCloudStore = [self.psc addPersistentStoreWithType:NSSQLiteStoreType
                                          configuration:@"CloudConfig"
                                                    URL:iCloudStoreURL
                                                options:options
                                                  error:&localError];
    success = (_iCloudStore != nil);
    if (success) {
        //set up the file presenter
        _presentedItemURL = iCloudDataURL;
        [NSFileCoordinator addFilePresenter:self];
    } else {
        if (localError  && (error != NULL)) {
            *error = localError;
        }
    }
    
    return success;
}

- (void)asyncLoadPersistentStores {
    NSError *error = nil;

    if (![self loadLocalPersistentStore:&error])
    {
        NSLog(@"Unable to add local persistent store: %@", error);
    }
    
    //if iCloud is available, add the persistent store
    //if iCloud is not available, or the add call fails, fallback to local storage
    BOOL useFallbackStore = NO;
    if ([self iCloudAvailable]) {
        if ([self loadiCloudStore:&error]) {
            DLog(@"Added iCloud Store");
            //check to see if we need to seed data from the seed store
            if (SEED_ICLOUD_STORE) {
                //do this synchronously
                if ([self seedStore:_iCloudStore withPersistentStoreAtURL:[self seedStoreURL] error:&error]) {
                    [self deDupe:nil];
                } else {
                    NSLog(@"Error seeding iCloud Store: %@", error);
                    abort();
                }
            }
            
            //check to see if we need to seed or migrate data from the fallback store
            NSFileManager *fm = [[NSFileManager alloc] init];
            if ([fm fileExistsAtPath:[[self fallbackStoreURL] path]])
            {
                //migrate data from the fallback store to the iCloud store
                //there is no reason to do this synchronously since no other peer should have this data
                dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(globalQueue, ^{
                    NSError *blockError = nil;
                    BOOL seedSuccess = [self seedStore:_iCloudStore
                              withPersistentStoreAtURL:[self fallbackStoreURL]
                                                 error:&blockError];
                    if (seedSuccess) {
                        DLog(@"Successfully seeded iCloud Store from Fallback Store");
                        NSFileManager *fm = [[NSFileManager alloc] init];
                        if(![fm removeItemAtPath:[[self fallbackStoreURL] path] error:&blockError])
                            DLog(@"Fallback Store @ %@ deleted after seeding", [self fallbackStoreURL]);
                        else
                            NSLog(@"Error deleting fallback store @ %@: %@", [self fallbackStoreURL], blockError);
                    } else {
                        NSLog(@"Error seeding iCloud Store from fallback store: %@", blockError);
                        abort();
                    }
                });
            }
        } else {
            NSLog(@"Unable to add iCloud store: %@", error);
            useFallbackStore = YES;
        }
    } else {
        useFallbackStore = YES;
    }
    
    if (useFallbackStore) {
        if ([self loadFallbackStore:&error]) {
//            DLog(@"Added fallback store: (%@) at %@", self.fallbackStore, [self.fallbackStoreURL absoluteString]);
            
            //you can seed the fallback store if you want to examine seeding performance without iCloud enabled
            //check to see if we need to seed data from the seed store
            if (SEED_ICLOUD_STORE) {
                //do this synchronously
                BOOL seedSuccess = [self seedStore:_fallbackStore
                          withPersistentStoreAtURL:[self seedStoreURL]
                                             error:&error];
                if (seedSuccess) {
                    //delete the fallback store
                    seedSuccess = [_psc removePersistentStore:_fallbackStore error:&error];
                    if (seedSuccess) {
                        NSFileManager *fm = [NSFileManager defaultManager];
                        seedSuccess = [fm removeItemAtURL:[self fallbackStoreURL] error:&error];
                        if (NO == seedSuccess) {
                            NSLog(@"Error deleting fallback store: %@", error);
                        }
                    } else {
                        NSLog(@"Error removing fallback store after seed: %@", error);
                    }
                    
                    [self deDupe:nil];
                } else {
                    NSLog(@"Error seeding iCloud Store: %@", error);
                    abort();
                }
            }
        } else {
            NSLog(@"Unable to add fallback store: %@", error);
            abort();
        }
    }
    // Notify interested parties that the db are ready to be used (and set the flag)
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:GTCoreDataReady object:self]];
    });
    self.coreDataIsReady = YES;
    DLog(@"Core Data is ready");
    // DEBUG: nukeAndPave
//    [self nukeAndPave];
}

- (void)dropStores {
    NSError *error = nil;
    
    if (_fallbackStore) {
        if ([_psc removePersistentStore:_fallbackStore error:&error]) {
            DLog(@"Removed fallback store");
            _fallbackStore = nil;
        } else {
            NSLog(@"Error removing fallback store: %@", error);
        }
    }
    
    if (_iCloudStore) {
        _presentedItemURL = nil;
        [NSFileCoordinator removeFilePresenter:self];
        if ([_psc removePersistentStore:_iCloudStore error:&error]) {
            DLog(@"Removed iCloud Store");
            _iCloudStore = nil;
        } else {
            NSLog(@"Error removing iCloud Store: %@", error);
        }
    }
}

- (void)reLoadiCloudStore:(NSPersistentStore *)store readOnly:(BOOL)readOnly {
    NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithDictionary:[store options]];
    if (readOnly) {
        options[NSReadOnlyPersistentStoreOption] = @YES;
    }
    
    NSError *error = nil;
    NSURL *storeURL = [store URL];
    NSString *storeType = [store type];
    NSString *configurationName = [store configurationName];
    _iCloudStore = [_psc addPersistentStoreWithType:storeType configuration:configurationName URL:storeURL options:options error:&error];
    if (_iCloudStore) {
        DLog(@"Added store back as read only: %@", store);
    } else {
        NSLog(@"Error adding read only store: %@", error);
    }
}

#pragma mark -
#pragma mark Application Lifecycle - Uniquing
- (void)deDupe:(NSNotification *)importNotification
{
    //if importNotification, scope dedupe by inserted records
    //else no search scope, prey for efficiency.
    @autoreleasepool {
        NSError *error = nil;
        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] init];
        [moc setPersistentStoreCoordinator:_psc];
        
        NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"Note"];
        [fr setIncludesPendingChanges:NO]; //distinct has to go down to the db, not implemented for in memory filtering
        [fr setFetchBatchSize:1000]; //protect thy memory
        
        NSExpression *countExpr = [NSExpression expressionWithFormat:@"count:(uuid)"];
        NSExpressionDescription *countExprDesc = [[NSExpressionDescription alloc] init];
        [countExprDesc setName:@"count"];
        [countExprDesc setExpression:countExpr];
        [countExprDesc setExpressionResultType:NSInteger64AttributeType];
        
        NSAttributeDescription *hexagramUUID = [[[_psc managedObjectModel] entitiesByName][@"Hexagram"] propertiesByName][@"uuid"];
        [fr setPropertiesToFetch:@[hexagramUUID, countExprDesc]];
        [fr setPropertiesToGroupBy:@[hexagramUUID]];
        
        [fr setResultType:NSDictionaryResultType];
        
        NSArray *countDictionaries = [moc executeFetchRequest:fr error:&error];
        NSMutableArray *dupedNotes = [[NSMutableArray alloc] init];
        for (NSDictionary *dict in countDictionaries) {
            NSNumber *count = dict[@"count"];
            if ([count integerValue] > 1) {
                [dupedNotes addObject:dict[@"uuid"]];
            }
        }
        
        DLog(@"Notes duped: %@", dupedNotes);
        
        //fetch out all the duplicate records
        fr = [NSFetchRequest fetchRequestWithEntityName:@"Note"];
        [fr setIncludesPendingChanges:NO];
        
        NSPredicate *p = [NSPredicate predicateWithFormat:@"uuid IN (%@)", dupedNotes];
        [fr setPredicate:p];
    
        NSSortDescriptor *emailSort = [NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES];
        [fr setSortDescriptors:@[emailSort]];
        
        NSUInteger batchSize = 500; //can be set 100-10000 objects depending on individual object size and available device memory
        [fr setFetchBatchSize:batchSize];
        NSArray *dupes = [moc executeFetchRequest:fr error:&error];
        
        Note *prevNote = nil;
        
        NSUInteger i = 1;
        for (Note *note in dupes)
        {
            if (prevNote)
            {
                if ([note.uuid isEqualToString:prevNote.uuid])
                {
                    if ([note.creationDate compare:prevNote.creationDate] == NSOrderedAscending)
                    {
                        [moc deleteObject:note];
                    }
                    else
                    {
                        [moc deleteObject:prevNote];
                        prevNote = note;
                    }
                }
                else
                {
                    prevNote = note;
                }
            }
            else
            {
                prevNote = note;
            }            
            if (0 == (i % batchSize))
            {
                //save the changes after each batch, this helps control memory pressure by turning previously examined objects back in to faults
                if ([moc save:&error])
                {
                    DLog(@"Saved successfully after uniquing");
                }
                else
                {
                    NSLog(@"Error saving unique results: %@", error);
                }
            }
            i++;
        }
        
        if ([moc save:&error])
        {
            DLog(@"Saved successfully after uniquing");
        }
        else
        {
            NSLog(@"Error saving unique results: %@", error);
        }
    }
}

#pragma mark -
#pragma mark Application Lifecycle - Seeding

- (void)addNote:(Note *)note toStore:(NSPersistentStore *)store withContext:(NSManagedObjectContext *)moc
{
    // Clone note (relationships included) and assign it to store.
    //create new object in data store
    Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:moc];
    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription entityForName:@"Note" inManagedObjectContext:moc] attributesByName];
    for (NSString *attr in attributes) {
        [newNote setValue:[note valueForKey:attr] forKey:attr];
    }
    //Loop through attachments, and clone them.
    for (Attachment *attachment in note.attachment) {
        Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:moc];
        NSDictionary *attributes = [[NSEntityDescription entityForName:@"Attachment" inManagedObjectContext:moc] attributesByName];
        for (NSString *attr in attributes) {
            [newAttachment setValue:[attachment valueForKey:attr] forKey:attr];
        }
        [moc assignObject:newAttachment toPersistentStore:store];
    }
    [moc assignObject:newNote toPersistentStore:store];
}

- (BOOL)seedStore:(NSPersistentStore *)store withPersistentStoreAtURL:(NSURL *)seedStoreURL error:(NSError * __autoreleasing *)error
{
    BOOL success = YES;
    NSError *localError = nil;
    
    NSManagedObjectModel *model = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSPersistentStoreCoordinator *seedPSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSDictionary *seedStoreOptions = @{ NSReadOnlyPersistentStoreOption : @YES };
    NSPersistentStore *seedStore = [seedPSC addPersistentStoreWithType:NSSQLiteStoreType
                                                         configuration:nil
                                                                   URL:seedStoreURL
                                                               options:seedStoreOptions
                                                                 error:&localError];
    if (seedStore)
    {
        NSManagedObjectContext *seedMOC = [[NSManagedObjectContext alloc] init];
        [seedMOC setPersistentStoreCoordinator:seedPSC];
        
        //fetch all the person objects, use a batched fetch request to control memory usage
        NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:@"Note"];
        NSUInteger batchSize = 5000;
        [fr setFetchBatchSize:batchSize];
        
        NSArray *notes = [seedMOC executeFetchRequest:fr error:&localError];
        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [moc setPersistentStoreCoordinator:_psc];
        NSUInteger i = 1;
        for (Note *note in notes)
        {
            [self addNote:note toStore:store withContext:moc];
            if (0 == (i % batchSize)) {
                success = [moc save:&localError];
                if (success)
                {
                    /*
                     Reset the managed object context to free the memory for the inserted objects
                     The faulting array used for the fetch request will automatically free objects
                     with each batch, but inserted objects remain in the managed object context for
                     the lifecycle of the context
                     */
                    [moc reset];
                } else
                {
                    NSLog(@"Error saving during seed: %@", localError);
                    break;
                }
            }
            
            i++;
        }
        
        //one last save
        if ([moc hasChanges])
        {
            success = [moc save:&localError];
            [moc reset];
        }
    }
    else
    {
        success = NO;
        NSLog(@"Error adding seed store: %@", localError);
    }
    
    if (NO == success)
    {
        if (localError  && (error != NULL))
        {
            *error = localError;
        }
    }
    
    return success;
}

#pragma mark -
#pragma mark Merging Changes
+ (void)mergeiCloudChangeNotification:(NSNotification *)note withManagedObjectContext:(NSManagedObjectContext *)moc {
    [moc performBlock:^{
        [moc mergeChangesFromContextDidSaveNotification:note];
    }];
}

#pragma mark -
#pragma mark Debugging Helpers
- (void)copyContainerToSandbox {
    @autoreleasepool {
        NSFileCoordinator __unused *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        NSError *error = nil;
        NSFileManager *fm = [[NSFileManager alloc] init];
        NSString *path = [self.ubiquityURL path];
        NSString *sandboxPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:[self.ubiquityURL lastPathComponent]];
        
        if ([fm createDirectoryAtPath:sandboxPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            DLog(@"Created container directory in sandbox: %@", sandboxPath);
        } else {
            if ([[error domain] isEqualToString:NSCocoaErrorDomain]) {
                if ([error code] == NSFileWriteFileExistsError) {
                    //delete the existing directory
                    error = nil;
                    if ([fm removeItemAtPath:sandboxPath error:&error]) {
                        DLog(@"Removed old sandbox container copy");
                    } else {
                        NSLog(@"Error trying to remove old sandbox container copy: %@", error);
                    }
                }
            } else {
                NSLog(@"Error attempting to create sandbox container copy: %@", error);
                return;
            }
        }
        
        
        NSArray *subPaths = [fm subpathsAtPath:path];
        for (NSString *subPath in subPaths) {
            NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, subPath];
            NSString *fullSandboxPath = [NSString stringWithFormat:@"%@/%@", sandboxPath, subPath];
            BOOL isDirectory = NO;
            if ([fm fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
                if (isDirectory) {
                    //create the directory
                    BOOL createSuccess = [fm createDirectoryAtPath:fullSandboxPath
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error];
                    if (createSuccess) {
                        //yay
                    } else {
                        NSLog(@"Error creating directory in sandbox: %@", error);
                    }
                } else {
                    //simply copy the file over
                    BOOL copySuccess = [fm copyItemAtPath:fullPath
                                                   toPath:fullSandboxPath
                                                    error:&error];
                    if (copySuccess) {
                        //yay
                    } else {
                        NSLog(@"Error copying item at path: %@\nTo path: %@\nError: %@", fullPath, fullSandboxPath, error);
                    }
                }
            } else {
                DLog(@"Got subpath but there is no file at the full path: %@", fullPath);
            }
        }
        
        fc = nil;
    }
}

- (void)nukeAndPave {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self asyncNukeAndPave];
    });
}

- (void)asyncNukeAndPave {
    //disconnect from the various stores
    [self dropStores];
    
    NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self.ubiquityURL path];
    NSArray *subPaths = [fm subpathsAtPath:path];
    for (NSString *subPath in subPaths) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, subPath];
        [fc coordinateWritingItemAtURL:[NSURL fileURLWithPath:fullPath]
                               options:NSFileCoordinatorWritingForDeleting
                                 error:&error
                            byAccessor:^(NSURL *newURL) {
            NSError *blockError = nil;
            if ([fm removeItemAtURL:newURL error:&blockError]) {
                NSLog(@"Deleted file: %@", newURL);
            } else {
                NSLog(@"Error deleting file: %@\nError: %@", newURL, blockError);
            }

        }];
    }

    fc = nil;
}

#pragma mark -
#pragma mark Misc.

- (NSString *)folderForUbiquityToken:(id)token {
    NSURL *tokenURL = [[self applicationSandboxStoresDirectory] URLByAppendingPathComponent:@"TokenFoldersData"];
    NSData *tokenData = [NSData dataWithContentsOfURL:tokenURL];
    NSMutableDictionary *foldersByToken = nil;
    if (tokenData) {
        foldersByToken = [NSKeyedUnarchiver unarchiveObjectWithData:tokenData];
    } else {
        foldersByToken = [NSMutableDictionary dictionary];
    }
    NSString *storeDirectoryUUID = foldersByToken[token];
    if (storeDirectoryUUID == nil)
    {
        if([NSUUID class])
            storeDirectoryUUID = [[NSUUID UUID] UUIDString];
        else
            storeDirectoryUUID = [NSString uuid];
        foldersByToken[token] = storeDirectoryUUID;
        tokenData = [NSKeyedArchiver archivedDataWithRootObject:foldersByToken];
        [tokenData writeToFile:[tokenURL path] atomically:YES];
    }
    return storeDirectoryUUID;
}

- (NSURL *)iCloudStoreURL {
    NSURL *iCloudStoreURL = [self applicationSandboxStoresDirectory];
    NSAssert1(self.currentUbiquityToken, @"No ubiquity token? Why you no use fallback store? %@", self);
    
    NSString *storeDirectoryUUID = [self folderForUbiquityToken:self.currentUbiquityToken];
    
    iCloudStoreURL = [iCloudStoreURL URLByAppendingPathComponent:storeDirectoryUUID];
    NSFileManager *fm = [[NSFileManager alloc] init];
    if (NO == [fm fileExistsAtPath:[iCloudStoreURL path]]) {
        NSError *error = nil;
        BOOL createSuccess = [fm createDirectoryAtURL:iCloudStoreURL withIntermediateDirectories:YES attributes:nil error:&error];
        if (NO == createSuccess) {
            NSLog(@"Unable to create iCloud store directory: %@", error);
        }
    }
    
    iCloudStoreURL = [iCloudStoreURL URLByAppendingPathComponent:kiCloudPersistentStoreFilename];
    return iCloudStoreURL;
}

- (NSURL *)seedStoreURL {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSURL *bundleURL = [mainBundle URLForResource:@"seedStore" withExtension:@"sqlite"];
    return bundleURL;
}

- (NSURL *)fallbackStoreURL {
    NSURL *storeURL = [[self applicationSandboxStoresDirectory] URLByAppendingPathComponent:kFallbackPersistentStoreFilename];
    return storeURL;
}

- (NSURL *)applicationSandboxStoresDirectory {
    NSURL *storesDirectory = [NSURL fileURLWithPath:[self applicationDocumentsDirectory]];
    storesDirectory = [storesDirectory URLByAppendingPathComponent:@"SharedCoreDataStores"];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    if (NO == [fm fileExistsAtPath:[storesDirectory path]]) {
        //create it
        NSError *error = nil;
        BOOL createSuccess = [fm createDirectoryAtURL:storesDirectory
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:&error];
        if (createSuccess == NO) {
            NSLog(@"Unable to create application sandbox stores directory: %@\n\tError: %@", storesDirectory, error);
        }
    }
    return storesDirectory;
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

#pragma mark -
#pragma mark NSFilePresenter

- (NSURL *)presentedItemURL {
    return _presentedItemURL;
}

- (NSOperationQueue *)presentedItemOperationQueue {
    return _presentedItemOperationQueue;
}

- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError *))completionHandler {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        [self iCloudAccountChanged:nil];
    });
    completionHandler(NULL);
}

#pragma mark -

@end
