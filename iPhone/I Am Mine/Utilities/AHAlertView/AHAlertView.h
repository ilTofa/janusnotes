//
//  AHAlertView.h
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

#import <UIKit/UIKit.h>

#ifdef __IPHONE_6_0
#define AHTextAlignmentCenter NSTextAlignmentCenter
#define AHLineBreakModeWordWrap NSLineBreakByWordWrapping
#else
#define AHTextAlignmentCenter UITextAlignmentCenter
#define AHLineBreakModeWordWrap UILineBreakModeWordWrap
#endif

typedef enum {
    AHAlertViewStyleDefault = 0,
    AHAlertViewStyleSecureTextInput,
    AHAlertViewStylePlainTextInput,
    AHAlertViewStyleLoginAndPasswordInput,
} AHAlertViewStyle;

typedef enum {
	AHAlertViewEnterDirectionFromTop,
	AHAlertViewEnterDirectionFromRight,
	AHAlertViewEnterDirectionFromBottom,
	AHAlertViewEnterDirectionFromLeft,
} AHAlertViewEnterDirection;

typedef enum {
	AHAlertViewExitDirectionToTop,
	AHAlertViewExitDirectionToRight,
	AHAlertViewExitDirectionToBottom,
	AHAlertViewExitDirectionToLeft,
} AHAlertViewExitDirection;

typedef enum {
	AHAlertViewPresentationStyleNone = 0,
	AHAlertViewPresentationStylePop,
	AHAlertViewPresentationStyleFade,
	AHAlertViewPresentationStylePush,

	AHAlertViewPresentationStyleDefault = AHAlertViewPresentationStylePop
} AHAlertViewPresentationStyle;

typedef enum {
	AHAlertViewDismissalStyleNone = 0,
	AHAlertViewDismissalStyleZoomDown,
	AHAlertViewDismissalStyleZoomOut,
	AHAlertViewDismissalStyleFade,
	AHAlertViewDismissalStyleTumble,
	AHAlertViewDismissalStylePush,

	AHAlertViewDismissalStyleDefault = AHAlertViewDismissalStyleFade
} AHAlertViewDismissalStyle;

typedef void (^AHAlertViewButtonBlock)();

@interface AHAlertView : UIView

// This text is presented at the top of the alert view, if non-nil.
@property(nonatomic, copy) NSString *title;
// This text is presented below the title and above any other controls, if non-nil.
@property(nonatomic, copy) NSString *message;
// This property indicates whether the alert is currently displayed on the screen.
@property(nonatomic, readonly, assign, getter = isVisible) BOOL visible;
// This property determines which controls are added to the alert (see AHAlertViewStyle above)
@property(nonatomic, assign) AHAlertViewStyle alertViewStyle;
// This property determines the animation used when the alert is shown.
@property(nonatomic, assign) AHAlertViewPresentationStyle presentationStyle;
// This property determines the animation used when the alert is dismissed.
@property(nonatomic, assign) AHAlertViewDismissalStyle dismissalStyle;
// For presentation animations that have an origin other than the center of the screen (push),
// this specifies the origination direction of the alert view.
@property(nonatomic, assign) AHAlertViewEnterDirection enterDirection;
// For dismissal animations that have an origin other than the center of the screen (push),
// this specifies the destination direction of the alert view.
@property(nonatomic, assign) AHAlertViewExitDirection exitDirection;
// Use this class inheriting from UITextField for text fields.
@property(nonatomic, retain) Class textFieldClass;

// Resets all UIAppearance modifiers back to generic iOS alert styles
+ (void)applySystemAlertAppearance;

// Builds a text attributes dictionary from the provided text attributes
+ (NSDictionary *)textAttributesWithFont:(UIFont *)font
						 foregroundColor:(UIColor *)foregroundColor
							 shadowColor:(UIColor *)shadowColor
							shadowOffset:(CGSize)shadowOffset;

// Designated initializer
- (id)initWithTitle:(NSString *)title message:(NSString *)message;

// Use this method to add an arbitrary number of buttons to the alert view.
// The block, if present, will be invoked when the corresponding button is pressed.
- (void)addButtonWithTitle:(NSString *)title block:(AHAlertViewButtonBlock)block;
// Use this method to set the title and action for a "destructive" button,
// which may have a different visual style than a normal button.
- (void)setDestructiveButtonTitle:(NSString *)title block:(AHAlertViewButtonBlock)block;
// Use this method to set the title and action for the cancel button,
// which may have a different visual style than a normal button
- (void)setCancelButtonTitle:(NSString *)title block:(AHAlertViewButtonBlock)block;

// Show the alert with the current presentation style
- (void)show;
// Show the alert with a custom presentation style, which then becomes the alert's current presentation style
- (void)showWithStyle:(AHAlertViewPresentationStyle)presentationStyle;
// Hide the alert with the current dismissal style
- (void)dismiss;
// Hide the alert with a custom dismissal style, which then becomes the alert's current dismissal style
- (void)dismissWithStyle:(AHAlertViewDismissalStyle)dismissalStyle;

// Retrieve the text field corresponding to the supplied index:
// For AHAlertViewStyleSecureTextInput and AHAlertViewStylePlainTextInput styles, there is only one text field at index 0.
// For AHAlertViewStyleLoginAndPasswordInput, the login field is at index 0, and the password field is at index 1.
- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex;

// UIAppearance methods and properties

// Use this property to set the background image of alerts. For best results, use a resizable image.
@property(nonatomic, strong) UIImage *backgroundImage UI_APPEARANCE_SELECTOR;
// Use this property to customize the insets surrounding the content of the alert.
// This does not affect leading between labels and other controls.
@property(nonatomic, assign) UIEdgeInsets contentInsets UI_APPEARANCE_SELECTOR;

// Use this property to customize the title text appearance. The dictionary keys are documented in UIStringDrawing.h
@property(nonatomic, copy) NSDictionary *titleTextAttributes UI_APPEARANCE_SELECTOR;
// Use this property to customize the message text appearance. The dictionary keys are documented in UIStringDrawing.h
@property(nonatomic, copy) NSDictionary *messageTextAttributes UI_APPEARANCE_SELECTOR;
// Use this property to customize the button title text appearance. The dictionary keys are documented in UIStringDrawing.h
@property(nonatomic, copy) NSDictionary *buttonTitleTextAttributes UI_APPEARANCE_SELECTOR;

// Use these methods to set/get the background image for control state(s) of normal buttons.
- (void)setButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state UI_APPEARANCE_SELECTOR;
- (UIImage *)buttonBackgroundImageForState:(UIControlState)state UI_APPEARANCE_SELECTOR;

// Use these methods to set/get the background image for control state(s) of cancel buttons.
- (void)setCancelButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state UI_APPEARANCE_SELECTOR;
- (UIImage *)cancelButtonBackgroundImageForState:(UIControlState)state UI_APPEARANCE_SELECTOR;

// Use these methods to set/get the background image for control state(s) of destructive buttons.
- (void)setDestructiveButtonBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state UI_APPEARANCE_SELECTOR;
- (UIImage *)destructiveButtonBackgroundImageForState:(UIControlState)state UI_APPEARANCE_SELECTOR;

@end
