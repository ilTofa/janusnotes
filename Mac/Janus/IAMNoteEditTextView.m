//
//  IAMNoteEditTextView.m
//  Janus Notes
//
//  Created by Giacomo Tufano on 23/10/13.
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
