//
//  IAMNoteEditTextView.m
//  Janus Notes
//
//  Created by Giacomo Tufano on 23/10/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEditTextView.h"

@interface IAMNoteEditTextView ()

@property NSString *cacheDirectory;

@end

@implementation IAMNoteEditTextView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        NSError *error;
        _cacheDirectory = [[[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] absoluteString];
    }
    return self;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = [sender draggingPasteboard];
    // Intercept file URLS and cut the cache directory
    if ( [[pb types] containsObject:@"public.file-url"] ) {
        NSString *urlString = [pb propertyListForType:@"public.file-url"];
        NSString *retVal = [urlString stringByReplacingOccurrencesOfString:self.cacheDirectory withString:@"$attachment$!"];
        [pb setString:retVal forType:NSPasteboardTypeString];
    }
    return [super performDragOperation:sender];
}

@end
