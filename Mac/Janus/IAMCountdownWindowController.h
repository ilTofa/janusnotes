//
//  IAMCountdownWindowController.h
//  Janus
//
//  Created by Giacomo Tufano on 27/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#if DEMO

#import <Cocoa/Cocoa.h>

@interface IAMCountdownWindowController : NSWindowController

@property (weak) IBOutlet NSTextField *remainingLabel;
@property (weak) IBOutlet NSButton *closeButton;

- (IBAction)closeSheet:(id)sender;
- (IBAction)selected:(id)sender;

@end

#endif