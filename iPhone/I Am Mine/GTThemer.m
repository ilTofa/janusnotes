//
//  GTThemer.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 08/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTThemer.h"

@interface GTThemer()

// Values Arrays
@property NSArray *colorsConfigs;
@property NSArray *fontsConfigs;

// Saved Values
@property NSString *defaultFontFace;
@property NSInteger defaultFontSize;
@property NSDictionary *defaultColors;

@property UIColor *backgroundColor, *textColor, *tintColor;

@end

@implementation GTThemer

+ (GTThemer *)sharedInstance
{
    static GTThemer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GTThemer alloc] init];
        sharedInstance.colorsConfigs = @[
                                         @{
                                             @"textColor" : [UIColor colorWithRed:0.216 green:0.212 blue:0.192 alpha:1.000],
                                             @"backgroundColor" : [UIColor colorWithRed:1.000 green:0.988 blue:0.922 alpha:1.000],
                                             @"tintColor" : [UIColor colorWithHue:0.083 saturation:1.000 brightness:0.502 alpha:1.000]},
                                         @{
                                             @"textColor" : [UIColor blackColor],
                                             @"backgroundColor" : [UIColor whiteColor],
                                             @"tintColor" : [UIColor colorWithWhite:0.700 alpha:1.000]},
                                         @{
                                             @"textColor" : [UIColor colorWithRed:1.000 green:1.000 blue:0.969 alpha:1.000],
                                             @"backgroundColor" : [UIColor colorWithRed:0.000 green:0.188 blue:0.318 alpha:1.000],
                                             @"tintColor" : [UIColor colorWithRed:0.169 green:0.318 blue:0.420 alpha:1.000]},
                                         @{
                                             @"textColor" : [UIColor colorWithRed:0.118 green:0.000 blue:0.000 alpha:1.000],
                                             @"backgroundColor" : [UIColor colorWithWhite:0.850 alpha:1.000],
                                             @"tintColor" : [UIColor colorWithWhite:0.655 alpha:1.000]},
                                         ];
        sharedInstance.fontsConfigs = @[@"Cochin", @"Georgia", @"Helvetica", @"Marker Felt"];
        [sharedInstance getDefaultValues];
    });
    return sharedInstance;
}

- (void)getDefaultValues
{
    self.defaultFontFace = self.fontsConfigs[[[NSUserDefaults standardUserDefaults] integerForKey:@"fontFace"]];
    self.defaultColors = self.colorsConfigs[[[NSUserDefaults standardUserDefaults] integerForKey:@"standardColors"]];
    self.defaultFontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if(self.defaultFontSize == 0)
        self.defaultFontSize = 14;
}

- (void)applyColorsToView:(UIView *)view
{
    // Do something only on iOS 6.1 or earlier
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        // if is a text field, set font (bigger) and color
        if([view isMemberOfClass:[UITextField class]]){
            [(UITextField *)view setFont:[UIFont fontWithName:self.defaultFontFace size:self.defaultFontSize + 3]];
            [(UITextField *)view setTextColor:self.defaultColors[@"textColor"]];
        }
        // If a text view, set font and color
        if([view isMemberOfClass:[UITextView class]]){
            [(UITextView *)view setFont:[UIFont fontWithName:self.defaultFontFace size:self.defaultFontSize]];
            [(UITextView *)view setTextColor:self.defaultColors[@"textColor"]];
        }
        // if it is a "tintable" class: set tint.
        else if([view isMemberOfClass:[UIToolbar class]] || [view isMemberOfClass:[UINavigationBar class]] || [view isMemberOfClass:[UISearchBar class]] || [view isMemberOfClass:[UIActivityIndicatorView class]]) {
            [(UIToolbar *)view setTintColor:self.defaultColors[@"tintColor"]];
        }
        // All else failing, set background for the view (or the collection view)
        else if([view isKindOfClass:[UIView class]]) {
            [view setBackgroundColor:self.defaultColors[@"backgroundColor"]];
        }
    }
}

-(void)applyColorsToLabel:(UILabel *)label withFontSize:(int)fontSize
{
    // Do something only on iOS 6.1 or earlier
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [label setTextColor:self.defaultColors[@"textColor"]];
        [label setFont:[UIFont fontWithName:self.defaultFontFace size:fontSize]];
    }
}

-(NSInteger)getStandardColorsID
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"standardColors"];
}

-(NSInteger)getStandardFontFaceID
{
    int fontFace = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontFace"];
    return fontFace;
}

-(NSInteger)getStandardFontSize
{
    int fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if(fontSize == 0)
        fontSize = 14;
    return fontSize;
}

-(void)saveStandardFontsWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize
{
    [[NSUserDefaults standardUserDefaults] setInteger:fontFace forKey:@"fontFace"];
    [[NSUserDefaults standardUserDefaults] setInteger:fontSize forKey:@"fontSize"];
    [self getDefaultValues];
}

-(void)saveStandardColors:(NSInteger)colorMix
{
    [[NSUserDefaults standardUserDefaults] setInteger:colorMix forKey:@"standardColors"];
    // Reload...
    [self getDefaultValues];
}

@end
