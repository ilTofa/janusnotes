//
//  GTThemer.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 08/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GTThemer : NSObject

+ (GTThemer *)sharedInstance;

// Applies colors, font and tinting to the passed view
- (void)applyColorsToView:(UIView *)view;
- (void)applyColorsToLabel:(UILabel *)label withFontSize:(int)fontSize;

// Get id (for user choose UI)
- (NSInteger)getStandardColorsID;
- (NSInteger)getStandardFontFaceID;
- (NSInteger)getStandardFontSize;

// Save colors (or font) from ID.
- (void)saveStandardColors:(NSInteger)colorMix;
- (void)saveStandardFontsWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize;

@end
