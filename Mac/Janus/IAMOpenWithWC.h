//
//  IAMOpenWithWC.h
//  Janus
//
//  Created by Giacomo Tufano on 10/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMOpenWithWC : NSWindowController

@property IBOutlet NSArray *appArray;
@property NSInteger selectedAppId;

- (IBAction)closeSheet:(id)sender;
- (IBAction)selected:(id)sender;

@end
