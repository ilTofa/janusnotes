//
//  IAMCollectionItemView.m
//  Janus
//
//  Created by Giacomo Tufano on 22/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMCollectionItemView.h"

@implementation IAMCollectionItemView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (NSView *)hitTest:(NSPoint)aPoint
{
    // don't allow any mouse clicks for subviews in this view
	if(NSPointInRect(aPoint,[self convertRect:[self bounds] toView:[self superview]])) {
		return self;
	} else {
		return nil;
	}
}

-(void)mouseDown:(NSEvent *)theEvent {
	[super mouseDown:theEvent];
	
	// check for click count above one, which we assume means it's a double click
	if([theEvent clickCount] > 1) {
		DLog(@"double click!");
        // NSApplication will find the doubleClick method in the NSWindowController automatically since the controller is in the responder chain
        [NSApp sendAction:@selector(collectionItemViewDoubleClick:) to:nil from:self];
	}
}

@end
