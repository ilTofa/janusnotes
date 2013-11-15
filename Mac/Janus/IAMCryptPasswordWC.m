//
//  IAMCryptPasswordWC.m
//  Janus
//
//  Created by Giacomo Tufano on 15/05/13.
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
