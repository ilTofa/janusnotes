// UIImage+RoundedCorner.h
// Created by Trevor Harmon on 9/20/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

// Extends the UIImage class to support making rounded corners
@interface UIImage (RoundedCorner)
- (UIImage *)roundedCornerImage:(NSInteger)cornerSize withFixedScale:(BOOL)fixedScale borderSize:(NSInteger)borderSize;
- (UIImage *)squaredThumbnail:(int)sideSize withFixedScale:(BOOL)fixedScale;
- (UIImage *)roundedThumbnail:(int)sideSize withFixedScale:(BOOL)fixedScale cornerSize:(NSInteger)cornerSize borderSize:(NSInteger)borderSize;
@end
