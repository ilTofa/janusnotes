//
//  IAMTextNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
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

#import <UIKit/UIKit.h>

#import "Note.h"

@interface IAMNoteEdit : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *titleEdit;
@property (weak, nonatomic) IBOutlet UITextView *textEdit;
@property (weak, nonatomic) IBOutlet UIImageView *greyRowImage;
@property (weak, nonatomic) IBOutlet UIImageView *attachmentsGreyRow;
@property (weak, nonatomic) IBOutlet UIToolbar *theToolbar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addImageButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *recordingButton;
@property (weak, nonatomic) IBOutlet UILabel *attachmentQuantityLabel;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textToToolbarConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachmentGreyRowToToolbarConstraint;

@property NSManagedObjectID *idForTheNoteToBeEdited;

- (IBAction)save:(id)sender;
- (IBAction)addImageToNote:(id)sender;
- (IBAction)recordAudio:(id)sender;

@end
