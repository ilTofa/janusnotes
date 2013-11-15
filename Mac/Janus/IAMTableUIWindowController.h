//
//  IAMTableUIWindowController.h
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

#import <Cocoa/Cocoa.h>

@interface IAMTableUIWindowController : NSWindowController

@property (weak, atomic) NSManagedObjectContext *sharedManagedObjectContext;
@property (assign) IBOutlet NSArrayController *arrayController;
@property (assign) IBOutlet NSTableView *theTable;

- (IBAction)showUIWindow:(id)sender;
@property (weak) IBOutlet NSMenuItem *notesWindowMenuItem;

@property (strong, nonatomic) NSMutableArray *noteWindowControllers;
@property IBOutlet NSNumber *noteEditorIsShown;

- (IBAction)addNote:(id)sender;
- (IBAction)editNote:(id)sender;
- (IBAction)searched:(id)sender;
- (IBAction)deleteNote:(id)sender;
- (IBAction)actionPreferences:(id)sender;
- (IBAction)refresh:(id)sender;
- (IBAction)showInFinder:(id)sender;

// Note editor actions from main menu
- (IBAction)saveNoteAndContinueAction:(id)sender;
- (IBAction)saveNoteAndCloseAction:(id)sender;
- (IBAction)closeNote:(id)sender;
- (IBAction)addAttachmentToNoteAction:(id)sender;
- (IBAction)removeAttachmentFromNoteAction:(id)sender;

// called from openFile in apdelegate
- (void)openNoteAtURI:(NSURL *)uri;

@end
