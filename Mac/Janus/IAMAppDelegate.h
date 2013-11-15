//
//  IAMAppDelegate.h
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
