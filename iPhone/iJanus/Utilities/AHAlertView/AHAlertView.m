//
//  AHAlertView.m
//  AHAlertViewSample
//
//	Copyright (C) 2012 Auerhaus Development, LLC
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy of
//	this software and associated documentation files (the "Software"), to deal in
//	the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//	the Software, and to permit persons to whom the Software is furnished to do so,
//	subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "AHAlertView.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Key used to associate block objects with their respective buttons
static const char * const AHAlertViewButtonBlockKey = "AHAlertViewButtonBlock";

static const NSInteger AHViewAutoresizingFlexibleSizeAndMargins =
	UIViewAutoresizingFlexibleLeftMargin |
	UIViewAutoresizingFlexibleWidth |
	UIViewAutoresizingFlexibleRightMargin |
	UIViewAutoresizingFlexibleTopMargin |
	UIViewAutoresizingFlexibleHeight |
	UIViewAutoresizingFlexibleBottomMargin;

// These hardcoded constants affect the layout of alert views but were not deemed
// important enough to expose via UIAppearance selectors. If you disagree with that
// assessment, you can either tweak them here as your application requires, or you
// can submit an issue or pull request to make layout behavior more flexible.
static const CGFloat AHAlertViewDefaultWidth = 276;
static const CGFloat AHAlertViewMinimumHeight = 100;
static const CGFloat AHAlertViewDefaultButtonHeight = 40;
static const CGFloat AHAlertViewDefaultTextFieldHeight = 26;
static const CGFloat AHAlertViewTitleLabelBottomMargin = 8;
static const CGFloat AHAlertViewMessageLabelBottomMargin = 16;
static const CGFloat AHAlertViewTextFieldBottomMargin = 8;
static const CGFloat AHAlertViewTextFieldLeading = -1;
static const CGFloat AHAlertViewButtonBottomMargin = 4;
static const CGFloat AHAlertViewButtonHorizontalSpacing = 4;

// This function may not be completely general. Works well enough for our purposes here.
static CGFloat CGAffineTransformGetAbsoluteRotationAngleDifference(CGAffineTransform t1, CGAffineTransform t2)
{
	CGFloat dot = t1.a * t2.a + t1.c * t2.c;
	CGFloat n1 = sqrtf(t1.a * t1.a + t1.c * t1.c);
	CGFloat n2 = sqrtf(t2.a * t2.a + t2.c * t2.c);
	return acosf(dot / (n1 * n2));
}

#pragma mark - Internal interface

// Internal block type definitions
typedef void (^AHAnimationCompletionBlock)(BOOL);
typedef void (^AHAnimationBlock)();

@interface AHAlertView () <UITextFieldDelegate>
@end

@interface AHAlertView () {
	// Flag to indicate whether this alert view has ever layed out its subviews
	BOOL hasLayedOut;
	// Flag to indicate whether keyboard is visible (or will soon be visible) on the screen
	BOOL keyboardIsVisible;
	// Flag to indicate whether the alert view is in the process of a dismissal animation
	BOOL isDismissing;
	// Vertical position of top edge of keyboard, when visible
	CGFloat keyboardHeight;
	// Last known interface orientation
	UIInterfaceOrientation previousOrientation;
}

@property (nonatomic, strong) UIWindow *alertWindow;
@property (nonatomic, strong) UIWindow *previousKeyWindow;
@property (nonatomic, strong) UIImageView *dimView;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UITextField *plainTextField;
@property (nonatomic, strong) UITextField *secureTextField;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *destructiveButton;
@property (nonatomic, strong) NSMutableArray *otherButtons;
@property (nonatomic, strong) NSMutableDictionary *buttonBackgroundImagesForControlStates;
@property (nonatomic, strong) NSMutableDictionary *cancelButtonBackgroundImagesForControlStates;
@property (nonatomic, strong) NSMutableDictionary *destructiveButtonBackgroundImagesForControlStates;
@end

#pragma mark - Implementation

@implementation AHAlertView

#pragma mark - Class life cycle methods

+ (void)initialize
{
	[self applySystemAlertAppearance];
}

+ (NSDictionary *)textAttributesWithFont:(UIFont *)font
						 foregroundColor:(UIColor *)foregroundColor
							 shadowColor:(UIColor *)shadowColor
							shadowOffset:(CGSize)shadowOffset
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
	NSShadow *textShadow = [[NSShadow alloc] init];
	textShadow.shadowColor = shadowColor;
	textShadow.shadowOffset = shadowOffset;

	return @{ NSFontAttributeName : font,
			  NSForegroundColorAttributeName : foregroundColor,
			  NSShadowAttributeName : textShadow };
#else
	return @{ UITextAttributeFont: font,
			  UITextAttributeTextColor : foregroundColor,
			  UITextAttributeTextShadowColor :[UIColor blackColor],
			  UITextAttributeTextShadowOffset : [NSValue valueWithCGSize:CGSizeMake(0, -1)] };
#endif
}

+ (void)getFont:(UIFont **)font
foregroundColor:(UIColor **)foregroundColor
	shadowColor:(UIColor **)shadowColor
   shadowOffset:(CGSize *)shadowOffset
fromTextAttributes:(NSDictionary *)attributes
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
	NSShadow *textShadow = attributes[NSShadowAttributeName];
	if (font)
		*font = attributes[NSFontAttributeName];
	if (foregroundColor)
		*foregroundColor = attributes[NSForegroundColorAttributeName];
	if (shadowColor)
		*shadowColor = textShadow.shadowColor;
	if (shadowOffset)
		*shadowOffset = textShadow.shadowOffset;
#else
	if (font)
		*font = attributes[UITextAttributeFont];
	if (foregroundColor)
		*foregroundColor = attributes[UITextAttributeTextColor];
	if (shadowColor)
		*shadowColor = attributes[UITextAttributeTextShadowColor];
	if (shadowOffset)
		*shadowOffset = [attributes[UITextAttributeTextShadowOffset] CGSizeValue];
#endif
}

+ (void)applySystemAlertAppearance {
	// Set up default values for all UIAppearance-compatible selectors

	// Set default (blue glass) background image. See drawing code below.
	[[self appearance] setBackgroundImage:[self alertBackgroundImage]];

	// Empirically determined edge insets for system style alerts
	[[self appearance] setContentInsets:UIEdgeInsetsMake(16, 8, 8, 8)];

	// Configure text properties for title, message, and buttons so they accord with system defaults.
	[[self appearance] setTitleTextAttributes:[self textAttributesWithFont:[UIFont boldSystemFontOfSize:17]
														   foregroundColor:[UIColor whiteColor]
															   shadowColor:[UIColor blackColor]
															  shadowOffset:CGSizeMake(0, -1)]];

	[[self appearance] setMessageTextAttributes:[self textAttributesWithFont:[UIFont systemFontOfSize:15]
															 foregroundColor:[UIColor whiteColor]
																 shadowColor:[UIColor blackColor]
																shadowOffset:CGSizeMake(0, -1)]];

	[[self appearance] setButtonTitleTextAttributes:[self textAttributesWithFont:[UIFont boldSystemFontOfSize:17]
																 foregroundColor:[UIColor whiteColor]
																	 shadowColor:[UIColor blackColor]
																	shadowOffset:CGSizeMake(0, -1)]];

	// Set basic button background images.
	[[self appearance] setButtonBackgroundImage:[self normalButtonBackgroundImage] forState:UIControlStateNormal];
	
	[[self appearance] setCancelButtonBackgroundImage:[self cancelButtonBackgroundImage] forState:UIControlStateNormal];
}

#pragma mark - Instance life cycle methods

- (id)initWithTitle:(NSString *)title message:(NSString *)message
{
	// The height of this frame is overridden in layoutSubviews, but it makes a good first approximation.
	CGRect frame = CGRectMake(0, 0, AHAlertViewDefaultWidth, AHAlertViewMinimumHeight);
	
	if((self = [super initWithFrame:frame]))
	{
		[super setBackgroundColor:[UIColor clearColor]];

		// Cache text properties for later use
		_title = title;
		_message = message;

		// Set default presentation and dismissal animation styles
		_presentationStyle = AHAlertViewPresentationStyleDefault;
		_dismissalStyle = AHAlertViewDismissalStyleDefault;
		_enterDirection = AHAlertViewEnterDirectionFromRight;
		_exitDirection = AHAlertViewExitDirectionToLeft;

		// Subscribe to orientation and keyboard visibility change notifications
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(deviceOrientationChanged:)
													 name:UIDeviceOrientationDidChangeNotification
												   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardFrameChanged:)
													 name:UIKeyboardWillShowNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardFrameChanged:)
													 name:UIKeyboardWillHideNotification
												   object:nil];

		// Finally, indicate that we'd like to know when the device changes orientations
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	}
	return self;
}

- (void)dealloc
{
	// Remove blocks associated with all buttons
	for(id button in _otherButtons)
		objc_setAssociatedObject(button, AHAlertViewButtonBlockKey, nil, OBJC_ASSOCIATION_RETAIN);

	if(_cancelButton)
		objc_setAssociatedObject(_cancelButton, AHAlertViewButtonBlockKey, nil, OBJC_ASSOCIATION_RETAIN);
	
	if(_destructiveButton)
		objc_setAssociatedObject(_destructiveButton, AHAlertViewButtonBlockKey, nil, OBJC_ASSOCIATION_RETAIN);

	// Indicate that this object is no longer interested in orientation changes
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];

	// Unsubscribe from all notifications we signed up for
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIDeviceOrientationDidChangeNotification
												  object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillShowNotification
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillHideNotification
												  object:nil];
}

#pragma mark - Button management methods

// Internal utility to initialize a button while also wiring up the block associated with its touch action
- (UIButton *)buttonWithTitle:(NSString *)aTitle associatedBlock:(AHAlertViewButtonBlock)block {
	UIButton *button = [[UIButton alloc] initWithFrame:CGRectZero];
	
	[button setTitle:aTitle forState:UIControlStateNormal];
	[button addTarget:self action:@selector(buttonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
	objc_setAssociatedObject(button, AHAlertViewButtonBlockKey, block, OBJC_ASSOCIATION_RETAIN);
	return button;
}

// Add a normal button with a title and a block to call when it is tapped.
- (void)addButtonWithTitle:(NSString *)title block:(AHAlertViewButtonBlock)block {
	if(!self.otherButtons)
		self.otherButtons = [NSMutableArray array];
	
	UIButton *otherButton = [self buttonWithTitle:title associatedBlock:block];
	[self.otherButtons addObject:otherButton];
	[self addSubview:otherButton];
}

// Set the destructive button title and a block to call when it is tapped.
- (void)setDestructiveButtonTitle:(NSString *)title block:(AHAlertViewButtonBlock)block {
	if(title) {
		self.destructiveButton = [self buttonWithTitle:title associatedBlock:block];
		[self addSubview:self.destructiveButton];
	} else {
		[self.destructiveButton removeFromSuperview];
		self.destructiveButton = nil;
	}
}

// Set the cancel button title and a block to call when it is tapped.
- (void)setCancelButtonTitle:(NSString *)title block:(AHAlertViewButtonBlock)block {
	if(title) {
		self.cancelButton = [self buttonWithTitle:title associatedBlock:block];
		[self addSubview:self.cancelButton];
	} else {
		[self.cancelButton removeFromSuperview];
		self.cancelButton = nil;
	}
}

#pragma mark - Text field accessor

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex {
	return [self textFieldAtIndex:textFieldIndex throws:YES];
}

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex throws:(BOOL)shouldThrow
{
	// Lazily instantiate text fields if we haven't layed out yet.
	[self ensureTextFieldsForCurrentAlertStyle];

	// The text field corresponding to the index depends solely on which alert view style is currently set.
	switch(self.alertViewStyle)
	{
		case AHAlertViewStyleLoginAndPasswordInput:
			if(textFieldIndex == 0)
				return self.plainTextField;
			else if(textFieldIndex == 1)
				return self.secureTextField;
			break;

		case AHAlertViewStylePlainTextInput:
			if(textFieldIndex == 0)
				return self.plainTextField;
			break;

		case AHAlertViewStyleSecureTextInput:
			if(textFieldIndex == 0)
				return self.secureTextField;
			break;

		default:
			break;
	}

	if(shouldThrow)
	{
		NSString *exceptionReason = [NSString stringWithFormat:@"Text field index %d was beyond bounds for current style.",
									 textFieldIndex];
		NSException *rangeException = [NSException exceptionWithName:NSRangeException reason:exceptionReason userInfo:nil];
		[rangeException raise];
	}
	
	return nil;
}

#pragma mark - Appearance selectors

- (void)setAlertViewStyle:(AHAlertViewStyle)alertViewStyle
{
	_alertViewStyle = alertViewStyle;

	// Cause text fields or other views to be instantiated lazily next time we lay out
	[self setNeedsLayout];
}

// Appearance selector for setting background image of normal buttons
- (void)setButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state
{
	if(!self.buttonBackgroundImagesForControlStates)
		self.buttonBackgroundImagesForControlStates = [NSMutableDictionary dictionary];
	
	[self.buttonBackgroundImagesForControlStates setObject:backgroundImage
													forKey:[NSNumber numberWithInteger:state]];
}

// Appearance selector for getting background image of normal buttons
- (UIImage *)buttonBackgroundImageForState:(UIControlState)state
{
	return [self.buttonBackgroundImagesForControlStates objectForKey:[NSNumber numberWithInteger:state]];
}

// Appearance selector for setting background image of cancel buttons
- (void)setCancelButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state
{
	if(!self.cancelButtonBackgroundImagesForControlStates)
		self.cancelButtonBackgroundImagesForControlStates = [NSMutableDictionary dictionary];

	[self.cancelButtonBackgroundImagesForControlStates setObject:backgroundImage
														  forKey:[NSNumber numberWithInteger:state]];
}

// Appearance selector for getting background image of cancel buttons
- (UIImage *)cancelButtonBackgroundImageForState:(UIControlState)state
{
	return [self.cancelButtonBackgroundImagesForControlStates objectForKey:[NSNumber numberWithInteger:state]];
}

// Appearance selector for setting background image of destructive buttons
- (void)setDestructiveButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state
{
	if(!self.destructiveButtonBackgroundImagesForControlStates)
		self.destructiveButtonBackgroundImagesForControlStates = [NSMutableDictionary dictionary];
	
	[self.destructiveButtonBackgroundImagesForControlStates setObject:backgroundImage
															   forKey:[NSNumber numberWithInteger:state]];
}

// Appearance selector for getting background image of destructive buttons
- (UIImage *)destructiveButtonBackgroundImageForState:(UIControlState)state
{
	return [self.destructiveButtonBackgroundImagesForControlStates objectForKey:[NSNumber numberWithInteger:state]];
}

- (void)applyTextAttributes:(NSDictionary *)attributes toLabel:(UILabel *)label
{
	UIFont *font;
	UIColor *textColor;
	UIColor *shadowColor;
	CGSize shadowOffset;
	[[self class] getFont:&font
		  foregroundColor:&textColor
			  shadowColor:&shadowColor
			 shadowOffset:&shadowOffset
	   fromTextAttributes:attributes];
	label.font = font;
	label.textColor = textColor;
	label.shadowColor = shadowColor;
	label.shadowOffset = shadowOffset;
}

- (void)applyTextAttributes:(NSDictionary *)attributes toButton:(UIButton *)button
{
	UIFont *font;
	UIColor *textColor;
	UIColor *shadowColor;
	CGSize shadowOffset;
	[[self class] getFont:&font
		  foregroundColor:&textColor
			  shadowColor:&shadowColor
			 shadowOffset:&shadowOffset
	   fromTextAttributes:attributes];
	button.titleLabel.font = font;
	[button setTitleColor:textColor forState:UIControlStateNormal];
	[button setTitleShadowColor:shadowColor forState:UIControlStateNormal];
	button.titleLabel.shadowOffset = shadowOffset;
}

- (void)applyBackgroundImages:(NSDictionary *)imagesForStates toButton:(UIButton *)button
{
	[imagesForStates enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[button setBackgroundImage:obj forState:[key integerValue]];
	}];
}

- (void)applyAppearanceAttributesToButtons
{
	if(self.cancelButton)
	{
		[self applyBackgroundImages:self.cancelButtonBackgroundImagesForControlStates
						   toButton:self.cancelButton];
		[self applyTextAttributes:self.buttonTitleTextAttributes toButton:self.cancelButton];
	}

	if(self.destructiveButton)
	{
		[self applyBackgroundImages:self.destructiveButtonBackgroundImagesForControlStates
						   toButton:self.destructiveButton];
		[self applyTextAttributes:self.buttonTitleTextAttributes toButton:self.destructiveButton];
	}

	for(UIButton *otherButton in self.otherButtons)
	{
		[self applyBackgroundImages:self.buttonBackgroundImagesForControlStates
						   toButton:otherButton];
		[self applyTextAttributes:self.buttonTitleTextAttributes toButton:otherButton];
	}
}

#pragma mark - Presentation and dismissal methods

- (void)show {
	// Show with the current presentation style.
	[self showWithStyle:self.presentationStyle];
}

- (void)showWithStyle:(AHAlertViewPresentationStyle)style
{
	self.presentationStyle = style;

	// Cache the orientation we begin in.
	previousOrientation = [[UIApplication sharedApplication] statusBarOrientation];

	// Create a new alert-level UIWindow instance and make key. We need to do this so
	// we appear above the status bar and can fade it appropriately.
	CGRect screenBounds = [[UIScreen mainScreen] bounds];
	self.alertWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	self.alertWindow.windowLevel = UIWindowLevelAlert;
	self.previousKeyWindow = [[UIApplication sharedApplication] keyWindow];
	[self.alertWindow makeKeyAndVisible];

	// Create a new radial gradiant background image to do the screen dimming effect
	self.dimView = [[UIImageView alloc] initWithFrame:self.alertWindow.bounds];
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        self.dimView.image = [self backgroundGradientImageWithSize:self.alertWindow.bounds.size];
    } else {
        self.dimView.image = [self imageWithColor:[UIColor colorWithWhite:0.882 alpha:1.0]];
    }
	self.dimView.userInteractionEnabled = YES;
	
	[self.alertWindow addSubview:self.dimView];
	[self.alertWindow addSubview:self];

	[self layoutIfNeeded];

	// Animate the alert view itself onto the screen
	[self performPresentationAnimation];
}


- (void)dismiss {
	// Hide with the current dismissal style
	[self dismissWithStyle:self.dismissalStyle];
}

- (void)dismissWithStyle:(AHAlertViewDismissalStyle)style
{
	self.dismissalStyle = style;

	// Flag any methods that might want to change our transform that we're in the midst of a dismissal
	isDismissing = YES;

	// Force editing of any currently active text fields.
	[self endEditing:YES];

	[self performDismissalAnimation];
}

- (void)buttonWasPressed:(UIButton *)sender {
	// Retrieve and invoke the block associated with this button when it was created.
	AHAlertViewButtonBlock block = objc_getAssociatedObject(sender, AHAlertViewButtonBlockKey);
	if(block)
		block();

	// Automatically dismiss after the button tap event is propagated.
	[self dismissWithStyle:self.dismissalStyle];
}

#pragma mark - Presentation and dismissal animation utilities

- (void)setCenterAlignToPixel:(CGPoint)center
{
	self.center = center;
	CGRect frame = self.frame;
	CGFloat inverseScale = 1.0 / [[UIScreen mainScreen] scale];
	CGPoint centerCorrection = CGPointMake(fmod(frame.origin.x, inverseScale), fmod(frame.origin.y, inverseScale));
	CGPoint roundedCenter = CGPointMake(center.x - centerCorrection.x, center.y - centerCorrection.y);
	self.center = roundedCenter;
}

- (void)performPresentationAnimation
{
	if(self.presentationStyle == AHAlertViewPresentationStylePop)
	{
		// This animation makes the alert view zoom into view, overshoot slightly, and finally
		// settle in where it should be. It is very similar to the system animation for presenting alert views.
		
		// This implementation was inspired by Jeff LaMarche's article on custom UIAlertViews. Thanks!
		// See: http://iphonedevelopment.blogspot.com/2010/05/custom-alert-views.html
		CAKeyframeAnimation *bounceAnimation = [CAKeyframeAnimation animation];
		bounceAnimation.duration = 0.3;
		bounceAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
		bounceAnimation.values = [NSArray arrayWithObjects:
								  [NSNumber numberWithFloat:0.01],
								  [NSNumber numberWithFloat:1.1],
								  [NSNumber numberWithFloat:0.9],
								  [NSNumber numberWithFloat:1.0],
								  nil];
		
		[self.layer addAnimation:bounceAnimation forKey:@"transform.scale"];

		// While the alert view pops in, the background overlay fades in
		CABasicAnimation *fadeInAnimation = [CABasicAnimation animation];
		fadeInAnimation.duration = 0.3;
		fadeInAnimation.fromValue = [NSNumber numberWithFloat:0];
		fadeInAnimation.toValue = [NSNumber numberWithFloat:1];
		[self.dimView.layer addAnimation:fadeInAnimation forKey:@"opacity"];
	}
	else if(self.presentationStyle == AHAlertViewPresentationStyleFade)
	{
		// This presentation animation is a slightly more subtle presentation with a gentle fade in.

		self.dimView.alpha = self.alpha = 0;

		[UIView animateWithDuration:0.3
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 self.dimView.alpha = self.alpha = 1;
		 }
						 completion:nil];
	}
	else if(self.presentationStyle == AHAlertViewPresentationStylePush)
	{
		CGPoint targetCenter = self.center;
		CGPoint offset = [self centerOffsetForDirection:self.enterDirection];
		offset = CGPointApplyAffineTransform(offset, self.transform);
		CGPoint originCenter = CGPointMake(self.center.x + offset.x, self.center.y + offset.y);

		[self setCenterAlignToPixel:originCenter];
		self.dimView.alpha = 0.01;

		[UIView animateWithDuration:0.4
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 [self setCenterAlignToPixel:targetCenter];
			 self.dimView.alpha = 1;
		 }
						 completion:nil];
	}
	else
	{
		// Views appear immediately when added
	}

	// As we're appearing, the first text field should become active.
	[[self textFieldAtIndex:0 throws:NO] becomeFirstResponder];
}

- (void)performDismissalAnimation
{
	// This block is called at the completion of the dismissal animations.
	AHAnimationCompletionBlock completionBlock = ^(BOOL finished)
	{
		// Remove relevant views.
		[self.dimView removeFromSuperview];
		[self removeFromSuperview];

		// Restore previous key window and tear down our own window
		[self.previousKeyWindow makeKeyWindow];
		self.alertWindow = nil;
		self.previousKeyWindow = nil;

		// We are no longer dismissing and can be re-presented or destroyed.
		isDismissing = NO;
	};
	
	if(self.dismissalStyle == AHAlertViewDismissalStyleTumble)
	{
		// This animation does a Tweetbot-style tumble animation where the alert view "falls"
		// off the screen while rotating slightly off-kilter. Use sparingly.
		[UIView animateWithDuration:0.6
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState
						 animations:^
		 {
			 CGPoint offset = CGPointMake(0, self.superview.bounds.size.height * 1.5);
			 offset = CGPointApplyAffineTransform(offset, self.transform);
			 self.transform = CGAffineTransformConcat(self.transform, CGAffineTransformMakeRotation(-M_PI_4));
			 [self setCenterAlignToPixel:CGPointMake(self.center.x + offset.x, self.center.y + offset.y)];
			 self.dimView.alpha = 0;
		 }
						 completion:completionBlock];
	}
	else if(self.dismissalStyle == AHAlertViewDismissalStyleFade)
	{
		// This animation subtly fades out the alert view over a short period.
		[UIView animateWithDuration:0.25
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 self.dimView.alpha = self.alpha = 0;
		 }
						 completion:completionBlock];
	}
	else if(self.dismissalStyle == AHAlertViewDismissalStyleZoomDown)
	{
		// This animation zooms the alert view down, "into" the screen, while fading.
		[UIView animateWithDuration:0.3
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseIn
						 animations:^
		 {
			 self.transform = CGAffineTransformConcat(self.transform, CGAffineTransformMakeScale(0.01, 0.01));
			 self.dimView.alpha = self.alpha = 0;
		 }
						 completion:completionBlock];
	}
	else if(self.dismissalStyle == AHAlertViewDismissalStyleZoomOut)
	{
		// This animation zooms the alert view out, "toward" the viewer, while fading.
		[UIView animateWithDuration:0.25
							  delay:0.0
							options:UIViewAnimationOptionCurveLinear
						 animations:^
		 {
			 self.transform = CGAffineTransformConcat(self.transform, CGAffineTransformMakeScale(10, 10));
			 self.dimView.alpha = self.alpha = 0;
		 }
						 completion:completionBlock];
	}
	else if(self.dismissalStyle == AHAlertViewDismissalStylePush)
	{
		[UIView animateWithDuration:0.4
							  delay:0.0
							options:UIViewAnimationOptionCurveEaseInOut
						 animations:^
		 {
			 CGPoint offset = [self centerOffsetForDirection:self.exitDirection];
			 offset = CGPointApplyAffineTransform(offset, self.transform);
			 [self setCenterAlignToPixel:CGPointMake(self.center.x + offset.x, self.center.y + offset.y)];
			 
			 self.dimView.alpha = 0;
		 }
						 completion:completionBlock];
	}
	else
	{
		completionBlock(YES);
	}
}

- (CGPoint)centerOffsetForDirection:(NSInteger)direction
{
	switch(direction)
	{
		case AHAlertViewEnterDirectionFromTop: // also AHAlertViewExitDirectionToTop
			return CGPointMake(0, -self.superview.bounds.size.height * 1.5);
		case AHAlertViewEnterDirectionFromRight:  // also AHAlertViewExitDirectionToRight
			return CGPointMake(self.superview.bounds.size.width * 1.5, 0);
		case AHAlertViewEnterDirectionFromBottom:  // also AHAlertViewExitDirectionToBottom
			return CGPointMake(0, self.superview.bounds.size.height * 1.5);
		case AHAlertViewEnterDirectionFromLeft:  // also AHAlertViewExitDirectionToLeft
			return CGPointMake(-self.superview.bounds.size.width * 1.5, 0);
	}

	return CGPointZero;
}

#pragma mark - Layout calculation methods

- (void)layoutSubviews {
	[super layoutSubviews];

	// Calculate the rectangle into which we should lay out our subviews, then extend the height infinitely downward
	CGRect boundingRect = self.bounds;
	boundingRect = UIEdgeInsetsInsetRect(boundingRect, self.contentInsets);
	boundingRect.size.height = FLT_MAX;

	// Lay out the various subviews, keeping track of the permissible bounding rectangle at each step.
	boundingRect = [self layoutTitleLabelWithinRect:boundingRect];
	boundingRect = [self layoutMessageLabelWithinRect:boundingRect];
	boundingRect = [self layoutTextFieldsWithinRect:boundingRect];
	boundingRect = [self layoutButtonsWithinRect:boundingRect];

	// Since we now know the downward extent of all of the subviews, we know the proper bounds to assign ourselves.
	CGRect newBounds = CGRectMake(0, 0, self.bounds.size.width, boundingRect.origin.y + self.contentInsets.bottom);
	self.bounds = newBounds;

	// Configure the background image view.
	[self layoutBackgroundImageView];

	// Rotate and position the alert view based on the new layout.
	[self reposition];
}

- (CGSize)sizeOfString:(NSString *)string withFont:(UIFont *)font constrainedToSize:(CGSize)size
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 70000
	NSDictionary *attributes = @{ NSFontAttributeName : font };
	return [string boundingRectWithSize:size
								options:NSStringDrawingUsesLineFragmentOrigin
							 attributes:attributes
								context:NULL].size;
#else
	return [string sizeWithFont:font constrainedToSize:size lineBreakMode:AHLineBreakModeWordWrap];
#endif
}

- (CGRect)layoutTitleLabelWithinRect:(CGRect)boundingRect
{
	// Lazily generate a title label.
	if(!self.titleLabel && self.title)
		self.titleLabel = [self addLabelAsSubview];

	// Assign appropriate text attributes to this label, then calculate a suitable frame for it.
	[self applyTextAttributes:self.titleTextAttributes toLabel:self.titleLabel];
	self.titleLabel.text = self.title;
	CGSize titleSize = [self sizeOfString:self.titleLabel.text
								 withFont:self.titleLabel.font
						constrainedToSize:boundingRect.size];
	self.titleLabel.frame = CGRectMake(boundingRect.origin.x, boundingRect.origin.y,
									   boundingRect.size.width, titleSize.height);

	// Adjust and return the bounding rect for the rest of the layout.
	CGFloat margin = (titleSize.height > 0) ? AHAlertViewTitleLabelBottomMargin : 0;
	boundingRect.origin.y = boundingRect.origin.y + titleSize.height + margin;
	return boundingRect;
}

- (CGRect) layoutMessageLabelWithinRect:(CGRect)boundingRect
{
	// Lazily generate a message label.
	if(!self.messageLabel && self.message)
		self.messageLabel = [self addLabelAsSubview];

	// Assign appropriate text attributes to this label, then calculate a suitable frame for it.
	[self applyTextAttributes:self.messageTextAttributes toLabel:self.messageLabel];
	self.messageLabel.text = self.message;
	CGSize messageSize = [self sizeOfString:self.messageLabel.text
								   withFont:self.messageLabel.font
						  constrainedToSize:boundingRect.size];
	self.messageLabel.frame = CGRectMake(boundingRect.origin.x, boundingRect.origin.y,
										 boundingRect.size.width, messageSize.height);

	// Adjust and return the bounding rect for the rest of the layout.
	CGFloat margin = (messageSize.height > 0) ? AHAlertViewMessageLabelBottomMargin : 0;
	boundingRect.origin.y = boundingRect.origin.y + messageSize.height + margin;
	return boundingRect;
}

- (Class)textFieldClass
{
    if ([_textFieldClass isSubclassOfClass:[UITextField class]])
        return _textFieldClass;
    else
        return [UITextField class];
}

// Internal utility to create or destroy text fields based on current alert view style
- (void)ensureTextFieldsForCurrentAlertStyle
{
	BOOL wantsPlainTextField = (self.alertViewStyle == AHAlertViewStylePlainTextInput ||
								self.alertViewStyle == AHAlertViewStyleLoginAndPasswordInput);
	BOOL wantsSecureTextField = (self.alertViewStyle == AHAlertViewStyleSecureTextInput ||
								 self.alertViewStyle == AHAlertViewStyleLoginAndPasswordInput);

	if(!wantsPlainTextField)
	{
		[self.plainTextField removeFromSuperview];
		self.plainTextField = nil;
	}
	else if(wantsPlainTextField && !self.plainTextField)
	{
		self.plainTextField = [[[self textFieldClass] alloc] initWithFrame:CGRectZero];
		self.plainTextField.backgroundColor = [UIColor whiteColor];
		self.plainTextField.keyboardAppearance = UIKeyboardAppearanceAlert;
		self.plainTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
		self.plainTextField.returnKeyType = UIReturnKeyDone;
		self.plainTextField.borderStyle = UITextBorderStyleLine;
		self.plainTextField.placeholder = @"PIN Code";
		self.plainTextField.delegate = self;
		[self addSubview:self.plainTextField];
	}

	if(!wantsSecureTextField)
	{
		[self.secureTextField removeFromSuperview];
		self.secureTextField = nil;
	}
	else if(wantsSecureTextField && !self.secureTextField)
	{
		self.secureTextField = [[[self textFieldClass] alloc] initWithFrame:CGRectZero];
		self.secureTextField.backgroundColor = [UIColor whiteColor];
		self.secureTextField.keyboardAppearance = UIKeyboardAppearanceAlert;
		self.secureTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
		self.secureTextField.returnKeyType = UIReturnKeyDone;
		self.secureTextField.borderStyle = UITextBorderStyleLine;
		self.secureTextField.placeholder = @"Password";
		self.secureTextField.secureTextEntry = YES;
		self.secureTextField.delegate = self;
		[self addSubview:self.secureTextField];
        
		self.plainTextField.returnKeyType = UIReturnKeyNext;
	}
}

- (CGRect)layoutTextFieldsWithinRect:(CGRect)boundingRect
{
	// Ensure we have text fields to lay out.
	[self ensureTextFieldsForCurrentAlertStyle];

	NSMutableArray *textFields = [NSMutableArray arrayWithCapacity:2];

	if(self.plainTextField)
		[textFields addObject:self.plainTextField];
	if(self.secureTextField)
		[textFields addObject:self.secureTextField];

	// Position the text fields in the current bounding rectangle.
	for(UITextField *textField in textFields)
	{
		CGRect fieldFrame = CGRectMake(boundingRect.origin.x, boundingRect.origin.y,
									   boundingRect.size.width, AHAlertViewDefaultTextFieldHeight);
		textField.frame = fieldFrame;

		CGFloat leading = (textField != [textFields lastObject]) ? AHAlertViewTextFieldLeading : 0;
		boundingRect.origin.y = CGRectGetMaxY(fieldFrame) + leading;
	}

	// Adjust and return the bounding rect for the rest of the layout.
	if([textFields count] > 0)
		boundingRect.origin.y += AHAlertViewTextFieldBottomMargin;
	return boundingRect;
}

- (CGRect)layoutButtonsWithinRect:(CGRect)boundingRect
{
	[self applyAppearanceAttributesToButtons];

	NSArray *allButtons = [self allButtonsInHIGDisplayOrder];

	if([self shouldUseSingleRowButtonLayout])
	{
		CGFloat buttonOriginX = boundingRect.origin.x;
		CGFloat buttonWidth = ((boundingRect.size.width + AHAlertViewButtonHorizontalSpacing) / [allButtons count]);
		buttonWidth -= AHAlertViewButtonHorizontalSpacing;

		for(UIButton *button in allButtons)
		{
			CGRect buttonFrame = CGRectMake(buttonOriginX, boundingRect.origin.y,
											buttonWidth, AHAlertViewDefaultButtonHeight);
			button.frame = buttonFrame;

			buttonOriginX = CGRectGetMaxX(buttonFrame) + AHAlertViewButtonHorizontalSpacing;
		}
		
		boundingRect.origin.y = CGRectGetMaxY([[allButtons lastObject] frame]);
	}
	else
	{
		for(UIButton *button in allButtons)
		{
			CGRect buttonFrame = CGRectMake(boundingRect.origin.x, boundingRect.origin.y,
											boundingRect.size.width, AHAlertViewDefaultButtonHeight);
			button.frame = buttonFrame;

			CGFloat margin = (button != [allButtons lastObject]) ? AHAlertViewButtonBottomMargin : 0;
			boundingRect.origin.y = CGRectGetMaxY(buttonFrame) + margin;
		}
	}
	
	return boundingRect;
}

- (void)layoutBackgroundImageView
{
	// Lazily create background image view and set its properties.
	if(!self.backgroundImageView)
	{
		self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
		self.backgroundImageView.autoresizingMask = AHViewAutoresizingFlexibleSizeAndMargins;
		self.backgroundImageView.contentMode = UIViewContentModeScaleToFill;
		[self insertSubview:self.backgroundImageView atIndex:0];
	}

	self.backgroundImageView.image = self.backgroundImage;
}

// Utility method to add a new center-aligned, multi-line label to this alert view
- (UILabel *)addLabelAsSubview
{
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
	label.backgroundColor = [UIColor clearColor];
	label.textAlignment = AHTextAlignmentCenter;
	label.numberOfLines = 0;
	[self addSubview:label];
	
	return label;
}

// If there are exactly two buttons, we position them side-by-side rather than stacked, regardless of title widths.
- (BOOL)shouldUseSingleRowButtonLayout
{
	NSInteger buttonCount =
		[self.otherButtons count] +
		((self.cancelButton) ? 1 : 0) +
		((self.destructiveButton) ? 1 : 0);

	if(buttonCount != 2)
		return NO;

	UIButton *cancelButtonOrNil = self.cancelButton;
	UIButton *onlyOtherButtonOrNil = self.destructiveButton;
	if(!onlyOtherButtonOrNil && [self.otherButtons count] == 1)
		onlyOtherButtonOrNil = [self.otherButtons objectAtIndex:0];

	return (cancelButtonOrNil && onlyOtherButtonOrNil);
}

// This method tries to compensate for HIG recommendations regarding button layout, but does so incompletely.
- (NSArray *)allButtonsInHIGDisplayOrder
{
	// Add all buttons to a common array, starting with destructive, followed by normal, finishing with cancel.
	NSMutableArray *allButtons = [NSMutableArray array];
	if(self.destructiveButton)
		[allButtons addObject:self.destructiveButton];
	if([self.otherButtons count] > 0)
		[allButtons addObjectsFromArray:self.otherButtons];
	if(self.cancelButton)
		[allButtons addObject:self.cancelButton];

	// If there are just two buttons, position them side-by-side, cancel button first.
	if([self shouldUseSingleRowButtonLayout])
	{
		allButtons = [NSMutableArray arrayWithObjects:self.cancelButton, [allButtons objectAtIndex:0], nil];
	}

	return allButtons;
}

#pragma mark - Keyboard helpers

- (void)keyboardFrameChanged:(NSNotification *)notification
{
	// Toggle keyboard visibility flag based on which notification we're receiving.
	keyboardIsVisible = ![notification.name isEqualToString:UIKeyboardWillHideNotification];

	// Retrieve keyboard frame in screen space and transform it to window space.
	CGRect keyboardFrame = [[[notification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGRect transformedFrame = CGRectApplyAffineTransform(keyboardFrame, [self transformForCurrentOrientation]);
	keyboardHeight = transformedFrame.size.height;

	// If the keyboard will soon be invisible, zero-out the stored height.
	if(!keyboardIsVisible)
		keyboardHeight = 0.0;

	// If we're not currently dismissing, we should position ourselves to account for the keyboard.
	if(!isDismissing)
		[self setNeedsLayout];
}

#pragma mark - Orientation helpers

- (CGAffineTransform)transformForCurrentOrientation
{
	// Calculate a rotation transform that matches the current interface orientation.
	CGAffineTransform transform = CGAffineTransformIdentity;
	UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
	if(orientation == UIInterfaceOrientationPortraitUpsideDown)
		transform = CGAffineTransformMakeRotation(M_PI);
	else if(orientation == UIInterfaceOrientationLandscapeLeft)
		transform = CGAffineTransformMakeRotation(-M_PI_2);
	else if(orientation == UIInterfaceOrientationLandscapeRight)
		transform = CGAffineTransformMakeRotation(M_PI_2);
	
	return transform;
}

- (void)reposition
{
	CGAffineTransform baseTransform = [self transformForCurrentOrientation];

	// This block contains all of the logic for how we position ourselves to account for the
	// presence of the keyboard and the current interface orientation.
	AHAnimationBlock layoutBlock = ^
	{
		self.transform = baseTransform;

		// Try to center ourselves in the space above the keyboard.
		CGPoint keyboardOffset = CGPointMake(0, -keyboardHeight);
		keyboardOffset = CGPointApplyAffineTransform(keyboardOffset, self.transform);
		CGRect superviewBounds = self.superview.bounds;
		superviewBounds.size.width += keyboardOffset.x;
		superviewBounds.size.height += keyboardOffset.y;

		CGPoint newCenter = CGPointMake(superviewBounds.size.width * 0.5, superviewBounds.size.height * 0.5);
		[self setCenterAlignToPixel:newCenter];
	};

	// Determine if the rotation we're about to undergo is 90 degrees or 180 degrees.
	CGFloat delta = CGAffineTransformGetAbsoluteRotationAngleDifference(self.transform, baseTransform);
	const CGFloat HALF_PI = 1.581; // Don't use M_PI_2 here; precision errors will cause incorrect results below.
	BOOL isDoubleRotation = (delta > HALF_PI);

	// If we've layed out before, we should rotate to the new orientation.
	if(hasLayedOut)
	{
		// Use the system rotation duration.
		CGFloat duration = [[UIApplication sharedApplication] statusBarOrientationAnimationDuration];

		// Egregious hax. iPad lies about its rotation duration.
		if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
			duration = 0.4;

		// Simply double the animation duration if we're rotating a full 180 degrees.
		if(isDoubleRotation)
			duration *= 2;

		[UIView animateWithDuration:duration animations:layoutBlock];
	}
	else
	{
		// We've never layed out before, so we should do it without animating, to prevent weird rotations.
		layoutBlock();
	}

	hasLayedOut = YES;
}

- (void)deviceOrientationChanged:(NSNotification *)notification
{
	UIInterfaceOrientation currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];

	// If the current orientation doesn't match the destination orientation, rotate to compensate.
	if(previousOrientation != currentOrientation)
	{
		previousOrientation = currentOrientation;
		[self reposition];
	}
}

#pragma mark - Text field delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == [self textFieldAtIndex:0 throws:NO]) {
        if (([self textFieldAtIndex:1 throws:NO] != nil)) {
            [[self textFieldAtIndex:1 throws:NO] becomeFirstResponder];
            
        } else {
            UIButton *defaultButton = [self.otherButtons lastObject];
            [self buttonWasPressed:defaultButton];
        }
        
    } else if (textField == [self textFieldAtIndex:1 throws:NO]) {
        UIButton *defaultButton = [self.otherButtons lastObject];
        [self buttonWasPressed:defaultButton];
    }
    
    return YES;
}

#pragma mark - Drawing utilities for implementing system control styles

- (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage *)backgroundGradientImageWithSize:(CGSize)size
{
	CGPoint center = CGPointMake(size.width * 0.5, size.height * 0.5);
	CGFloat innerRadius = 0;
    CGFloat outerRadius = sqrtf(size.width * size.width + size.height * size.height) * 0.5;

	BOOL opaque = NO;
    UIGraphicsBeginImageContextWithOptions(size, opaque, [[UIScreen mainScreen] scale]);
	CGContextRef context = UIGraphicsGetCurrentContext();

    const size_t locationCount = 2;
    CGFloat locations[locationCount] = { 0.0, 1.0 };
    CGFloat components[locationCount * 4] = {
		0.941, 0.941, 0.941, 1.0, // More transparent black
		0.882, 0.882, 0.882, 1.0  // More opaque black
	};
	
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, locationCount);
	
    CGContextDrawRadialGradient(context, gradient, center, innerRadius, center, outerRadius, 0);
	
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    CGColorSpaceRelease(colorspace);
    CGGradientRelease(gradient);
	
    return image;
}

#pragma mark - Class drawing utilities for implementing system control styles

+ (UIImage *)alertBackgroundImage
{
	CGRect rect = CGRectMake(0, 0, AHAlertViewDefaultWidth, AHAlertViewMinimumHeight);
	const CGFloat lineWidth = 2;
	const CGFloat cornerRadius = 8;

	CGFloat shineWidth = rect.size.width * 1.33;
	CGFloat shineHeight = rect.size.width * 0.2;
	CGFloat shineOriginX = rect.size.width * 0.5 - shineWidth * 0.5;
	CGFloat shineOriginY = -shineHeight * 0.45;
	CGRect shineRect = CGRectMake(shineOriginX, shineOriginY, shineWidth, shineHeight);

	UIColor *fillColor = [UIColor colorWithRed:1/255.0 green:21/255.0 blue:54/255.0 alpha:0.9];
	UIColor *strokeColor = [UIColor colorWithWhite:1.0 alpha:0.7];
	
	BOOL opaque = NO;
    UIGraphicsBeginImageContextWithOptions(rect.size, opaque, [[UIScreen mainScreen] scale]);

	CGRect fillRect = CGRectInset(rect, lineWidth, lineWidth);
	UIBezierPath *fillPath = [UIBezierPath bezierPathWithRoundedRect:fillRect cornerRadius:cornerRadius];
	[fillColor setFill];
	[fillPath fill];
	
	CGRect strokeRect = CGRectInset(rect, lineWidth * 0.5, lineWidth * 0.5);
	UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:cornerRadius];
	strokePath.lineWidth = lineWidth;
	[strokeColor setStroke];
	[strokePath stroke];
	
	UIBezierPath *shinePath = [UIBezierPath bezierPathWithOvalInRect:shineRect];
	[fillPath addClip];
	[shinePath addClip];
	
    const size_t locationCount = 2;
    CGFloat locations[locationCount] = { 0.0, 1.0 };
    CGFloat components[locationCount * 4] = {
		1, 1, 1, 0.75,  // Translucent white
		1, 1, 1, 0.05   // More translucent white
	};
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, locationCount);
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGPoint startPoint = CGPointMake(CGRectGetMidX(shineRect), CGRectGetMinY(shineRect));
	CGPoint endPoint = CGPointMake(CGRectGetMidX(shineRect), CGRectGetMaxY(shineRect));
	CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
	
	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
	CGFloat capHeight = CGRectGetMaxY(shineRect);
	CGFloat capWidth = rect.size.width * 0.5;
	return [image resizableImageWithCapInsets:UIEdgeInsetsMake(capHeight, capWidth, capHeight, capWidth)];
}

+ (UIImage *)normalButtonBackgroundImage
{
	const size_t locationCount = 4;
	CGFloat opacity = 1.0;
    CGFloat locations[locationCount] = { 0.0, 0.5, 0.5 + 0.0001, 1.0 };
    CGFloat components[locationCount * 4] = {
		179/255.0, 185/255.0, 199/255.0, opacity,
		121/255.0, 132/255.0, 156/255.0, opacity,
		87/255.0, 100/255.0, 130/255.0, opacity, 
		108/255.0, 120/255.0, 146/255.0, opacity,
	};
	return [self glassButtonBackgroundImageWithGradientLocations:locations
													  components:components
												   locationCount:locationCount];
}

+ (UIImage *)cancelButtonBackgroundImage
{
	const size_t locationCount = 4;
	CGFloat opacity = 1.0;
    CGFloat locations[locationCount] = { 0.0, 0.5, 0.5 + 0.0001, 1.0 };
    CGFloat components[locationCount * 4] = {
		164/255.0, 169/255.0, 184/255.0, opacity,
		77/255.0, 87/255.0, 115/255.0, opacity,
		51/255.0, 63/255.0, 95/255.0, opacity,
		78/255.0, 88/255.0, 116/255.0, opacity,
	};
	return [self glassButtonBackgroundImageWithGradientLocations:locations
													  components:components
												   locationCount:locationCount];
}

+ (UIImage *)glassButtonBackgroundImageWithGradientLocations:(CGFloat *)locations
												  components:(CGFloat *)components
											   locationCount:(NSInteger)locationCount
{
	const CGFloat lineWidth = 1;
	const CGFloat cornerRadius = 4;
	UIColor *strokeColor = [UIColor colorWithRed:1/255.0 green:11/255.0 blue:39/255.0 alpha:1.0];
	
	CGRect rect = CGRectMake(0, 0, cornerRadius * 2 + 1, AHAlertViewDefaultButtonHeight);

	BOOL opaque = NO;
    UIGraphicsBeginImageContextWithOptions(rect.size, opaque, [[UIScreen mainScreen] scale]);

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, locationCount);
	
	CGRect strokeRect = CGRectInset(rect, lineWidth * 0.5, lineWidth * 0.5);
	UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:cornerRadius];
	strokePath.lineWidth = lineWidth;
	[strokeColor setStroke];
	[strokePath stroke];
	
	CGRect fillRect = CGRectInset(rect, lineWidth, lineWidth);
	UIBezierPath *fillPath = [UIBezierPath bezierPathWithRoundedRect:fillRect cornerRadius:cornerRadius];
	[fillPath addClip];
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
	CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
	CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
	
	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
	CGFloat capHeight = floorf(rect.size.height * 0.5);
	return [image resizableImageWithCapInsets:UIEdgeInsetsMake(capHeight, cornerRadius, capHeight, cornerRadius)];
}

@end
