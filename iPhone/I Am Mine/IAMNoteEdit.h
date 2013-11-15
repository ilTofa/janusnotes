//
//  IAMTextNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
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
