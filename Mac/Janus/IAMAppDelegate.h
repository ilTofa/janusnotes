//
//  IAMAppDelegate.h
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

#import "CoreDataController.h"
#import "IAMTableUIWindowController.h"

@interface IAMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (strong, nonatomic) IAMTableUIWindowController *collectionController;

#if DEMO
@property (readonly, nonatomic) NSInteger lifeline;
@property (nonatomic, getter = isTampered) BOOL tampered;
#endif
@property (weak) IBOutlet NSMenuItem *buyFullVersionMenu;

// CoreData helper
@property (nonatomic, strong, readonly) CoreDataController *coreDataController;

- (IBAction)saveAction:(id)sender;
- (IBAction)preferencesAction:(id)sender;
- (void)preferencesForDirectory;
- (IBAction)notesWindowAction:(id)sender;
- (IBAction)newNoteAction:(id)sender;
- (IBAction)editNoteAction:(id)sender;
- (IBAction)closeNoteAction:(id)sender;
- (IBAction)deleteNoteAction:(id)sender;
- (IBAction)refreshNotesAction:(id)sender;
- (IBAction)showInFinderAction:(id)sender;

- (IBAction)saveNoteAndContinueAction:(id)sender;
- (IBAction)saveNoteAndCloseAction:(id)sender;
- (IBAction)closeNote:(id)sender;
- (IBAction)addAttachmentToNoteAction:(id)sender;
- (IBAction)removeAttachmentFromNoteAction:(id)sender;

- (IBAction)getIOSApp:(id)sender;
- (IBAction)getFullVersion:(id)sender;

@end
