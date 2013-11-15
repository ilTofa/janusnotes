//
//  IAMCryptPasswordWC.m
//  Janus
//
//  Created by Giacomo Tufano on 15/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMCryptPasswordWC.h"

#import "IAMFilesystemSyncController.h"

@interface IAMCryptPasswordWC ()

- (IBAction)cancelAction:(id)sender;
- (IBAction)cryptAction:(id)sender;

@end

@implementation IAMCryptPasswordWC

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.validPassword = [[IAMFilesystemSyncController sharedInstance] cryptPassword];
}

- (IBAction)cancelAction:(id)sender {
    self.validPassword = nil;
    [[NSApplication sharedApplication] endSheet:self.window];
}

- (IBAction)cryptAction:(id)sender {
    if (!self.validPassword || [self.validPassword isEqualToString:@""]) {
        return;
    }
    if(!self.passwordToBeCheckedAgaintFilesystem) {
        [[NSApplication sharedApplication] endSheet:self.window];
    }
}

@end
