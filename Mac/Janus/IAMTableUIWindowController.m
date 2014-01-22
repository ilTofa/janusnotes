//
//  IAMTableUIWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 22/04/13.
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

#import "IAMTableUIWindowController.h"

#import "IAMNoteEditorWC.h"
#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "IAMFilesystemSyncController.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"
#import "NSManagedObject+Serialization.h"
#import "Attachment.h"

@interface IAMTableUIWindowController () <IAMNoteEditorWCDelegate, NSWindowDelegate>

@property (weak) IBOutlet NSSearchFieldCell *searchField;
@property (copy) NSArray *sortDescriptors;

@property NSTimer *syncStatusTimer;

@end

@implementation IAMTableUIWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _noteWindowControllers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setExcludedFromWindowsMenu:YES];
    [self.notesWindowMenuItem setState:NSOnState];
    [self.theTable setTarget:self];
    [self.theTable setDoubleAction:@selector(tableItemDoubleClick:)];
    self.noteEditorIsShown = @(NO);
    self.sharedManagedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.mainThreadContext;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSyncNeedsThePassword:) name:kIAMDataSyncNeedsAPasswordNow object:nil];
    // If db is still to be loaded, register to be notified else go directly
    if(!((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.coreDataIsReady)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coreDataIsReady:) name:GTCoreDataReady object:nil];
    else
        [self coreDataIsReady:nil];
}

- (IBAction)showUIWindow:(id)sender {
    DLog(@"called.");
    [self.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    [self.notesWindowMenuItem setState:NSOnState];
}

- (BOOL)windowShouldClose:(id)sender {
    DLog(@"Hiding main UI");
    [self.window orderOut:self];
    return NO;
}

- (void)windowWillClose:(NSNotification *)notification {
    DLog(@"Main UI closing");
    [self.notesWindowMenuItem setState:NSOffState];
}

- (void)dataSyncNeedsThePassword:(NSNotification *)notification {
    DLog(@"Notification caught for password need");
    [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] preferencesAction:nil];
}

- (void)coreDataIsReady:(NSNotification *)notification {
    if(notification)
        DLog(@"called with notification %@", notification);
    else
        DLog(@"called directly from init");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GTCoreDataReady object:nil];
    // Init sync mamagement
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(defaultDirectorySelected:) name:kIAMDataSyncSelectedDefaulDir object:nil];
    [IAMFilesystemSyncController sharedInstance];
    [self.arrayController setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO]]];
}

- (void)defaultDirectorySelected:(NSNotification *)notification {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Welcome to Janus Notes, press OK to open the preference panel and select the path to the Notes directory. The path can be changed later at any time using the preference panel. If you're unsure about what to do you can safely accept the default location by pressing cancel on the select path box.", nil)];
    [alert setMessageText:NSLocalizedString(@"Notes Directory Selection", @"")];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:(__bridge void *)(self)];
}

- (IBAction)refresh:(id)sender {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSyncNotificationHandler:) name:kIAMDataSyncRefreshTerminated object:nil];
    [[IAMFilesystemSyncController sharedInstance] refreshContentFromRemote];
}

- (void)endSyncNotificationHandler:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kIAMDataSyncRefreshTerminated object:nil];
}

#pragma mark - Notes Editing management

- (void)openNoteAtURI:(NSURL *)uri {
    Note *aprenda = (Note *)[self.sharedManagedObjectContext objectWithURI:uri];
    if(!aprenda) {
        ALog(@"*** Note is nil while trying to open it!");
        return;
    }
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setIdForTheNoteToBeEdited:[aprenda objectID]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

// This event comes from the collection item view subclass
- (IBAction)tableItemDoubleClick:(id)sender {
    if([[self.arrayController selectedObjects] count] != 0) {
        DLog(@"Double click detected in table view, sending event to editNote:");
        [self editNote:sender];
    } else {
        ALog(@"Double click detected in table view, but no row is selected. This should not happen");
    }
}

- (IBAction)addNote:(id)sender {
    DLog(@"This is addNote handler in MainWindowController");
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

- (IBAction)editNote:(id)sender {
//    DLog(@"Selected note for editing is: %@", [self.arrayController selectedObjects][0]);
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setIdForTheNoteToBeEdited:[[self.arrayController selectedObjects][0] objectID]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    self.noteEditorIsShown = @(YES);
    [noteEditor showWindow:self];
}

- (IBAction)showInFinder:(id)sender {
    Note *toBeShown = [self.arrayController selectedObjects][0];
    NSURL *pathToBeShown = [[IAMFilesystemSyncController sharedInstance] urlForNote:toBeShown];
    DLog(@"Show in finder requested for note: %@", pathToBeShown);
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[pathToBeShown]];
}

- (IBAction)deleteNote:(id)sender {
//    DLog(@"Selected note for deleting is: %@", [self.arrayController selectedObjects][0]);
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the note?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)actionPreferences:(id)sender {
    [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] preferencesAction:sender];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    // If called from firstdirectory selection contextInfo will be not nil
    if (contextInfo) {
        [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] preferencesForDirectory];
    } else {
        if(returnCode == NSAlertSecondButtonReturn)
        {
            // Create a local moc, children of the sync moc and delete there.
            DLog(@"User confirmed delete, now really deleting note.");
            NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
            [moc setParentContext:[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext];
            NSURL *uri = [[[self.arrayController selectedObjects][0] objectID] URIRepresentation];
            Note *delenda = (Note *)[moc objectWithURI:uri];
            if(!delenda) {
                ALog(@"*** Note is nil while deleting note!");
                return;
            }
            DLog(@"About to delete note: %@", delenda);
            [moc deleteObject:delenda];
            NSError *error;
            if(![moc save:&error])
                ALog(@"Unresolved error %@, %@", error, [error userInfo]);
            // Save on parent context
            [[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext performBlock:^{
                NSError *localError;
                if(![[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext save:&localError])
                    ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
            }];
        }
    }
}

- (IBAction)searched:(id)sender {
    NSString *queryString = nil;
    if(![[self.searchField stringValue] isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        NSArray *terms = [[self.searchField stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        for(NSString *term in terms)
        {
            if([term length] == 0)
                continue;
            if(queryString == nil)
                queryString = [NSString stringWithFormat:@"(text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND (text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
        }
    }
    else
        queryString = @"text  like[c] \"*\"";
//    DLog(@"Filtering on: '%@'", queryString);
    [self.arrayController setFilterPredicate:[NSPredicate predicateWithFormat:queryString]];
}

-(void)IAMNoteEditorWCDidCloseWindow:(IAMNoteEditorWC *)windowController
{
    // Note editor closed, now find and delete it from our controller array (so to allow ARC dealloc it)
    for (IAMNoteEditorWC *storedController in self.noteWindowControllers) {
        if(storedController == windowController) {
            [self.noteWindowControllers removeObject:storedController];
        }
    }
    if([self.noteWindowControllers count])
        self.noteEditorIsShown = @(YES);
    else
        self.noteEditorIsShown = @(NO);
}

// Note editor actions

- (IAMNoteEditorWC *)keyNoteEditor {
    IAMNoteEditorWC *foundController = nil;
    for (IAMNoteEditorWC *noteEditorController in self.noteWindowControllers) {
        if([noteEditorController.window isKeyWindow]) {
            foundController = noteEditorController;
            break;
        }
    }
    return foundController;
}

- (IBAction)backupNotesArchive:(id)sender {
    DLog(@"called.");
    NSArray *notes = [self.arrayController arrangedObjects];
    NSMutableArray *notesToBeSerialized = [[NSMutableArray alloc] initWithCapacity:[notes count]];
    for (Note *note in notes) {
        NSDictionary *noteDict = [note toDictionary];
        [notesToBeSerialized addObject:noteDict];
    }
    NSUInteger savedNotesCount = [notesToBeSerialized count];
    if (savedNotesCount == 0) {
        return;
    }
    NSData *data=[NSKeyedArchiver archivedDataWithRootObject:notesToBeSerialized];
    DLog(@"Should save to a file %lu bytes of data", (unsigned long)[data length]);
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowedFileTypes:@[@"it.iltofa.janusarchive"]];
    savePanel.allowsOtherFileTypes = NO;
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now saving.", savePanel.URL);
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message;
            NSError *error;
            if (![data writeToURL:savePanel.URL options:NSDataWritingAtomic error:&error]) {
                message = [NSString stringWithFormat:@"Error saving data: %@", [error description]];
            } else {
                message = [NSString stringWithFormat:@"%lu notes saved in the archive. Archive is unencrypted, please store it in a secure place.", savedNotesCount];
            }
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Backup Operation", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }
    }];
}

- (void)saveNoteFromDictionary:(NSDictionary *)potentialNote inManagedObjectContext:(NSManagedObjectContext *)moc {
    NSError *error;
    [NSManagedObject createManagedObjectFromDictionary:potentialNote inContext:moc];
    if(![moc save:&error])
        ALog(@"Unresolved error %@, %@", error, [error userInfo]);
    // Save on parent context
    [[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext performBlock:^{
        NSError *localError;
        if(![[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext save:&localError])
            ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
    }];
}

- (IBAction)restoreNotesArchive:(id)sender {
    DLog(@"called.");
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    [openPanel setAllowedFileTypes:@[@"it.iltofa.janusarchive"]];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@, now loading.", openPanel.URL);
            NSData *data = [NSData dataWithContentsOfURL:openPanel.URL];
            NSArray *notesRead = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            NSUInteger notesInArchive, skippedNotes, savedNotes;
            notesInArchive = skippedNotes = savedNotes = 0;
            notesInArchive = [notesRead count];
            DLog(@"Read %lu objects.", (unsigned long)notesInArchive);
            NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
            [moc setParentContext:[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext];
            NSError *error;
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            [request setEntity:[NSEntityDescription entityForName:@"Note" inManagedObjectContext:moc]];
            for (NSDictionary *potentialNote in notesRead) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", potentialNote[@"uuid"]];
                [request setPredicate:predicate];
                NSArray *results = [moc executeFetchRequest:request error:&error];
                if (results && [results count] > 0) {
                    NSDate *potentialNoteTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:[potentialNote[@"dAtEaTtr:timeStamp"] doubleValue]];
                    if ([potentialNoteTimestamp compare:((Note *)results[0]).timeStamp] == NSOrderedDescending) {
                        DLog(@"%@ should be saved %@ > %@.", ((Note *)results[0]).title, potentialNoteTimestamp, ((Note *)results[0]).timeStamp);
                        [self saveNoteFromDictionary:potentialNote inManagedObjectContext:moc];
                        savedNotes++;
                    } else {
                        skippedNotes++;
                    }
                } else {
                    DLog(@"%@ should be saved because not existing on current db.", ((Note *)results[0]).title);
                    [self saveNoteFromDictionary:potentialNote inManagedObjectContext:moc];
                    savedNotes++;
                }
            }
            NSAlert *alert = [[NSAlert alloc] init];
            NSString *message = [NSString stringWithFormat:@"%lu notes in archive. %lu notes imported. %lu notes skipped because already existing in an identical or newer version.", notesInArchive, savedNotes, skippedNotes];
            [alert setInformativeText:message];
            [alert setMessageText:NSLocalizedString(@"Restore Operation", @"")];
            [alert addButtonWithTitle:@"OK"];
            [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
        }
    }];
}

@end
