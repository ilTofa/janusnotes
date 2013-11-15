// UIImage+RoundedCorner.m
// Created by Trevor Harmon on 9/20/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

#import "UIImage+RoundedCorner.h"

@implementation UIImage (RoundedCorner)

- (UIImage *)roundedThumbnail:(int)sideSize withFixedScale:(BOOL)fixedScale cornerSize:(NSInteger)cornerSize borderSize:(NSInteger)borderSize
{
	// Create a graphics image context
	CGSize newSize = CGSizeMake(sideSize, sideSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, (fixedScale) ? 1.0 : [[UIScreen mainScreen] scale]);
	// Tell the old image to draw in this new context, with the desired size
	[self drawInRect:CGRectMake(0, 0, sideSize, sideSize)];
	// Get the new image from the context
	UIImage *thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
	// End the context
	UIGraphicsEndImageContext();
	return [thumbnailImage roundedCornerImage:cornerSize withFixedScale:fixedScale borderSize:borderSize];
}

-(UIImage *)squaredThumbnail:(int)sideSize withFixedScale:(BOOL)fixedScale
{
	// Create a graphics image context
	CGSize newSize;
    newSize = CGSizeMake(sideSize * [UIScreen mainScreen].scale, sideSize * [UIScreen mainScreen].scale);
		
    UIGraphicsBeginImageContextWithOptions(newSize, NO, (fixedScale) ? 1.0 : [[UIScreen mainScreen] scale]);
	// Tell the old image to draw in this new context, with the desired size
	[self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
	// Get the new image from the context
	UIImage *thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
	// End the context
	UIGraphicsEndImageContext();
	return thumbnailImage;
}

// Creates a copy of this image with rounded corners
// If borderSize is non-zero, a transparent border of the given size will also be added
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
- (UIImage *)roundedCornerImage:(NSInteger)cornerSize withFixedScale:(BOOL)fixedScale borderSize:(NSInteger)borderSize 
{
    UIImage *image = self;

	DLog(@"image size: %f, %f", image.size.width, image.size.height);
	
    // Build a context that's the same dimensions as the new size
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 image.size.width,
                                                 image.size.height,
                                                 CGImageGetBitsPerComponent(image.CGImage),
                                                 0,
                                                 CGImageGetColorSpace(image.CGImage),
                                                 CGImageGetBitmapInfo(image.CGImage));

    // Create a clipping path with rounded corners
    CGContextBeginPath(context);
    [self addRoundedRectToPath:CGRectMake(borderSize, borderSize, image.size.width - borderSize * 2, image.size.height - borderSize * 2)
                       context:context
                     ovalWidth:cornerSize
                    ovalHeight:cornerSize];
    CGContextClosePath(context);
    CGContextClip(context);

    // Draw the image to the context; the clipping path will make anything outside the rounded rect transparent
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    
    // Create a CGImage from the context
    CGImageRef clippedImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    // Create a UIImage from the CGImage
	UIImage *roundedImage = [UIImage imageWithCGImage:clippedImage scale:(fixedScale) ? 1.0 : [[UIScreen mainScreen] scale] orientation: UIImageOrientationUp];
		
    CGImageRelease(clippedImage);
    
    return roundedImage;
}

#pragma mark -
#pragma mark Private helper methods

// Adds a rectangular path to the given context and rounds its corners by the given extents
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
- (void)addRoundedRectToPath:(CGRect)rect context:(CGContextRef)context ovalWidth:(CGFloat)ovalWidth ovalHeight:(CGFloat)ovalHeight 
{
    if (ovalWidth == 0 || ovalHeight == 0) 
	{
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM(context, ovalWidth, ovalHeight);
    CGFloat fw = CGRectGetWidth(rect) / ovalWidth;
    CGFloat fh = CGRectGetHeight(rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

// Returns true if the image has an alpha layer
- (BOOL)hasAlpha 
{
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(self.CGImage);
    return (alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}

// Returns a copy of the given image, adding an alpha channel if it doesn't already have one
- (UIImage *)imageWithAlpha 
{
    if ([self hasAlpha]) {
        return self;
    }
    
    CGImageRef imageRef = self.CGImage;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
    CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
														  width,
														  height,
                                                          8,
                                                          0,
                                                          CGImageGetColorSpace(imageRef),
                                                          kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    
    // Draw the image into the context and retrieve the new image, which will now have an alpha layer
    CGContextDrawImage(offscreenContext, CGRectMake(0, 0, width, height), imageRef);
    CGImageRef imageRefWithAlpha = CGBitmapContextCreateImage(offscreenContext);
    UIImage *imageWithAlpha = [UIImage imageWithCGImage:imageRefWithAlpha scale:[[UIScreen mainScreen] scale] orientation: UIImageOrientationUp];
    
    // Clean up
    CGContextRelease(offscreenContext);
    CGImageRelease(imageRefWithAlpha);
    
    return imageWithAlpha;
}

@end
