//
//  IAMCryptPasswordWC.h
//  Janus
//
//  Created by Giacomo Tufano on 15/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMCryptPasswordWC : NSWindowController

@property NSString *validPassword;
@property BOOL passwordToBeCheckedAgaintFilesystem;

@end
