//
//  IAMTableUIWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 22/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMTableUIWindowController.h"

#import "IAMNoteEditorWC.h"
#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "IAMFilesystemSyncController.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"
#import "Attachment.h"
#if DEMO
#import "IAMCountdownWindowController.h"
#endif

@interface IAMTableUIWindowController () <IAMNoteEditorWCDelegate, NSWindowDelegate>

@property (weak) IBOutlet NSSearchFieldCell *searchField;
@property (copy) NSArray *sortDescriptors;

@property NSTimer *syncStatusTimer;

#if DEMO
@property IAMCountdownWindowController *countdownController;
#endif

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
#if DEMO
    [self showRemainingDaysBox];
#endif
}

- (void)defaultDirectorySelected:(NSNotification *)notification {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Welcome to Janus Notes, press OK to open the preference panel and select the path to the Notes directory. The path can be changed later at any time using the preference panel. If you're unsure about what to do you can safely accept the default location by pressing cancel on the select path box.", nil)];
    [alert setMessageText:NSLocalizedString(@"Notes Directory Selection", @"")];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:(__bridge void *)(self)];
}

- (IBAction)refresh:(id)sender {
#if DEMO
    if(((IAMAppDelegate *)[NSApplication sharedApplication].delegate).lifeline < 1 || ((IAMAppDelegate *)[NSApplication sharedApplication].delegate).isTampered) {
        [self showRemainingDaysBox];
    }
#endif
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
#if DEMO
    if(((IAMAppDelegate *)[NSApplication sharedApplication].delegate).lifeline < 1 || ((IAMAppDelegate *)[NSApplication sharedApplication].delegate).isTampered) {
        [self showRemainingDaysBox];
    }
#endif
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
#if DEMO
    if(((IAMAppDelegate *)[NSApplication sharedApplication].delegate).lifeline < 1 || ((IAMAppDelegate *)[NSApplication sharedApplication].delegate).isTampered) {
        [self showRemainingDaysBox];
    }
#endif
//    DLog(@"Selected note for deleting is: %@", [self.arrayController selectedObjects][0]);
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the note?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)actionPreferences:(id)sender {
#if DEMO
    if(((IAMAppDelegate *)[NSApplication sharedApplication].delegate).lifeline < 1 || ((IAMAppDelegate *)[NSApplication sharedApplication].delegate).isTampered) {
        [self showRemainingDaysBox];
    }
#endif
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

- (IBAction)saveNoteAndContinueAction:(id)sender {
    [[self keyNoteEditor] saveAndContinue:sender];
}

- (IBAction)saveNoteAndCloseAction:(id)sender {
    [[self keyNoteEditor] saveAndClose:sender];
}

- (IBAction)closeNote:(id)sender {
    [[self keyNoteEditor].window performClose:sender];
}

- (IBAction)addAttachmentToNoteAction:(id)sender {
    [[self keyNoteEditor] addAttachment:sender];
}

- (IBAction)removeAttachmentFromNoteAction:(id)sender {
    [[self keyNoteEditor] deleteAttachment:sender];
}

#if DEMO

#pragma mark - Demo Management

- (void)showRemainingDaysBox {
    if(!self.countdownController) {
        self.countdownController = [[IAMCountdownWindowController alloc] initWithWindowNibName:@"IAMCountdownWindowController"];
    }
    [[NSApplication sharedApplication] beginSheet:self.countdownController.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    [self.countdownController.window orderOut:self];
    self.countdownController = nil;
}

#endif

@end
