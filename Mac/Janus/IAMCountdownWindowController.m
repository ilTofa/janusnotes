//
//  IAMCountdownWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 27/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
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