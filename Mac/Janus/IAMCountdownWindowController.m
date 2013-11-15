//
//  IAMCountdownWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 27/05/13.
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

#if DEMO

#import "IAMCountdownWindowController.h"
#import "IAMAppDelegate.h"

@interface IAMCountdownWindowController ()

@property BOOL toBeTerminated;

@end

@implementation IAMCountdownWindowController

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
    NSInteger days = ((IAMAppDelegate *)[NSApplication sharedApplication].delegate).lifeline;
    if(days > 0) {
        self.remainingLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Currently you have %d remaining days for evaluation.", nil), days];
        self.toBeTerminated = NO;
    } else {
        self.remainingLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Evaluation period has ended. Please buy the app.", nil), days];
        self.remainingLabel.textColor = [NSColor redColor];
        self.closeButton.title = NSLocalizedString(@"Exit Application", nil);
        self.toBeTerminated = YES;
    }
}

- (IBAction)closeSheet:(id)sender {
    [[NSApplication sharedApplication] endSheet:self.window];
    if(self.toBeTerminated) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (IBAction)selected:(id)sender {
    [[NSApplication sharedApplication] endSheet:self.window]; // 
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstore://itunes.apple.com/app/id651141191?mt=12"]];
    if(self.toBeTerminated) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

@end

#endif