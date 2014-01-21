//
//  IAMAppDelegate.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
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

#import "IAMAppDelegate.h"

#include <sys/sysctl.h>
#import "IAMFilesystemSyncController.h"
#import "IAMPrefsWindowController.h"
#import "iRate.h"
#import "STKeychain.h"

@interface IAMAppDelegate ()

@property (strong) IAMPrefsWindowController *prefsController;

- (IBAction)showFAQs:(id)sender;
- (IBAction)showMarkdownHelp:(id)sender;
- (IBAction)sendAComment:(id)sender;

@end

@implementation IAMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectContext = _managedObjectContext;

+ (void)initialize {
    // Init iRate
    [iRate sharedInstance].daysUntilPrompt = 5;
    [iRate sharedInstance].usesUntilPrompt = 15;
    [iRate sharedInstance].appStoreID = 651141191;
    [iRate sharedInstance].appStoreGenreID = 0;
    [iRate sharedInstance].onlyPromptIfMainWindowIsAvailable = NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DLog(@"Starting application init");
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    if(!fontName) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Lucida Grande" forKey:@"fontName"];
        [[NSUserDefaults standardUserDefaults] setDouble:13.0 forKey:@"fontSize"];
    }
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
        [self.collectionController showWindow:self];
    }
    [self deleteCache];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    DLog(@"App called to open %@", filename);
    BOOL retValue = NO;
    if (filename && [filename hasSuffix:@"janus"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            [self openFile:filename];
        });
        retValue = YES;
    }
    return retValue;
}

- (void)openFile:(NSString *)filename {
    // Decode URI from path.
    NSURL *objectURI = [[NSPersistentStoreCoordinator elementsDerivedFromExternalRecordURL:[NSURL fileURLWithPath:filename]] objectForKey:NSObjectURIKey];
    if (objectURI) {
        NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:objectURI];
        if (moid) {
            NSManagedObject *mo = [[self managedObjectContext] objectWithID:moid];
            if(!self.collectionController) {
                ALog(@"Bad news. Init is *really* slow today, aborting open");
                return;
            }
            NSURL *uri = [[mo objectID] URIRepresentation];
            DLog(@"Send note URL to the main UI for opening: %@", uri);
            [self.collectionController openNoteAtURI:uri];
        } else {
            ALog(@"Error: no NSManagedObjectID for %@", objectURI);
        }
    } else {
        ALog(@"Error: no objectURI for %@", filename);
    }
}

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "it.iltofa.Janus" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"it.iltofa.Janus"];
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    return self.coreDataController.psc;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
    return self.coreDataController.mainThreadContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (void)preferencesForDirectory {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    // sender is nil, this is called because we need a password now...
    self.prefsController.directoryNeeded = YES;
    [self.prefsController showWindow:self];
}

- (IBAction)preferencesAction:(id)sender {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    // sender is nil, this is called because we need a password now...
    if(!sender) {
        self.prefsController.aPasswordIsNeededASAP = YES;
    }
    [self.prefsController showWindow:self];
}

- (IBAction)notesWindowAction:(id)sender {
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
    }
    [self.collectionController showUIWindow:self];
}

- (IBAction)getIOSApp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id651150600"]];
}

- (IBAction)getFullVersion:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstore://itunes.apple.com/app/id651141191?mt=12"]];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    return NSTerminateNow;
}

#pragma mark - cache management

- (void)deleteCache {
    // Async load, please (so don't use defaultManager, not thread safe)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [[NSFileManager alloc] init];
        NSError *error;
        NSString *directory = [[fileMgr URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] path];
        NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
        for (NSString *filename in fileArray)  {
            [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
        }
        fileMgr = nil;
    });
}

- (IBAction)showFAQs:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/faq.html"]];
}

- (IBAction)showMarkdownHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet"]];
}

- (IBAction)sendAComment:(id)sender {
    NSString *model;
    size_t length = 0;
    sysctlbyname("hw.model", NULL, &length, NULL, 0);
    if (length) {
        char *m = malloc(length * sizeof(char));
        sysctlbyname("hw.model", m, &length, NULL, 0);
        model = [NSString stringWithUTF8String:m];
        free(m);
    } else {
        model = @"Unknown";
    }
    NSString *subject = [NSString stringWithFormat:@"Feedback on Janus Notes OS X app version %@ (%@) on a %@/%@", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"], model, [[NSProcessInfo processInfo] operatingSystemVersionString]];
    NSString *urlString = [[NSString stringWithFormat:@"mailto:support@janusnotes.com?subject=%@", subject] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}
@end
