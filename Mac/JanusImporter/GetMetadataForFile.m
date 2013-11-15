//
//  GetMetadataForFile.m
//  JanusImporter
//
//  Created by Giacomo Tufano on 18/03/13.
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

#include <CoreFoundation/CoreFoundation.h>
#import <CoreData/CoreData.h>
#import "MySpotlightImporter.h"

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);

//==============================================================================
//
//	Get metadata attributes from document files
//
//	The purpose of this function is to extract useful information from the
//	file formats for your document, and set the values into the attribute
//  dictionary for Spotlight to include.
//
//==============================================================================

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
    // Pull any available metadata from the file at the specified path
    // Return the attribute keys and attribute values in the dict
    // Return TRUE if successful, FALSE if there was no data provided
	// The path could point to either a Core Data store file in which
	// case we import the store's metadata, or it could point to a Core
	// Data external record file for a specific record instances

    Boolean ok = FALSE;
    @autoreleasepool {
        NSError *error = nil;
        
        if ([(__bridge NSString *)contentTypeUTI isEqualToString:@"store_uti"]) {
            // import from store file metadata
            
            // Create the URL, then attempt to get the meta-data from the store
            NSURL *url = [NSURL fileURLWithPath:(__bridge NSString *)pathToFile];
            NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil URL:url error:&error];
            
            // If there is no error, add the info
            if (error == NULL) {
                // Get the information you are interested in from the dictionary
                // "YOUR_INFO" should be replaced by key(s) you are interested in
                
                NSObject *contentToIndex = metadata[@"YOUR_INFO"];
                if (contentToIndex != nil) {
                    // Add the metadata to the text content for indexing
                    ((__bridge NSMutableDictionary *)attributes)[(NSString *)kMDItemTextContent] = contentToIndex;
                    ok = TRUE;
                }
            }
            
        } else if ([(__bridge NSString *)contentTypeUTI isEqualToString:@"it.iltofa.janus"]) {
            // import from an external record file
            
            MySpotlightImporter *importer = [[MySpotlightImporter alloc] init];
            ok = [importer importFileAtPath:(__bridge NSString *)pathToFile attributes:(__bridge NSMutableDictionary *)attributes error:&error];
        }
    }
    
	// Return the status
    return ok;
}
