//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEdit.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <iAd/iAd.h>

#import "IAMAppDelegate.h"
#import "UIViewController+GTFrames.h"
#import "Attachment.h"
#import "IAMAddLinkViewController.h"
#import "IAMAttachmentCell.h"
#import "IAMAttachmentDetailViewController.h"
#import "MicrophoneWindow.h"
#import "GTThemer.h"
#import "UIImage+FixOrientation.h"
#import "IAMDataSyncController.h"
#import "IAMMarkdownPreViewController.h"
// #import "NSManagedObjectContext+FetchedObjectFromURI.h"

@interface IAMNoteEdit () <UITextViewDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, IAMAddLinkViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, AttachmentDeleter, MicrophoneWindowDelegate>

@property CGRect oldFrame;
@property (strong) NSString *originalTitle;
@property NSArray *attachmentsArray;
@property(nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) MicrophoneWindow *recordView;
@property BOOL attachmensAreHidden;
@property UIPopoverController *popover;
// The note to be edited
@property Note *editedNote;
@property (strong) NSString *originalText;

@property NSManagedObjectContext *noteEditorMOC;

@property CGFloat currentAttachmentConstraintHeight;

@end

@implementation IAMNoteEdit

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // The NSManagedObjectContext instance should change for a local (to the controller instance) one.
    // We need to migrate the passed object to the new moc.
    self.noteEditorMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [self.noteEditorMOC setParentContext:[IAMDataSyncController sharedInstance].dataSyncThreadContext];
    if(!self.idForTheNoteToBeEdited) {
        // It seems that we're created without a note, that will mean that we're required to create a new one.
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.noteEditorMOC];
        self.editedNote = newNote;
    } else { // Get a copy of edited note into the local context.
        NSError *error;
        self.editedNote = (Note *)[self.noteEditorMOC existingObjectWithID:self.idForTheNoteToBeEdited error:&error];
        NSAssert1(self.editedNote, @"Shit! Invalid ObjectID, there. Error: %@", [error description]);
    }
    // Keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    // UIContentSizeCategoryDidChangeNotification
    // Preset the note
    self.originalTitle = self.titleEdit.text = self.editedNote.title;
    self.originalText = self.textEdit.text = self.editedNote.text;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [[GTThemer sharedInstance] applyColorsToView:self.titleEdit];
        [[GTThemer sharedInstance] applyColorsToView:self.textEdit];
        [[GTThemer sharedInstance] applyColorsToView:self.view];
        [[GTThemer sharedInstance] applyColorsToView:self.collectionView];
        [[GTThemer sharedInstance] applyColorsToView:self.theToolbar];
    } else {
        [self dynamicFontChanged:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dynamicFontChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    self.attachmensAreHidden = NO;
    [self refreshAttachments];
    [self processAds:nil];
    // If this is a new note, set the cursor on title field
    if([self.titleEdit.text isEqualToString:@""])
        [self.titleEdit becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (![self.originalText isEqualToString:self.textEdit.text] || ![self.originalTitle isEqualToString:self.titleEdit.text]) {
        DLog(@"Note is changed, save it in any case.");
        [self save:nil];
    }
    [super viewWillDisappear:animated];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)processAds:(NSNotification *)note {
    if (note) {
        DLog(@"Called by notification...");
    }
    if ([self respondsToSelector:@selector(setCanDisplayBannerAds:)]) {
        if (!((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).skipAds) {
            DLog(@"Preparing Ads");
            self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyAutomatic;
        } else {
            DLog(@"Skipping ads");
            self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyNone;
        }
    }
}

- (void)dynamicFontChanged:(NSNotification *)notification {
    self.textEdit.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.titleEdit.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.attachmentQuantityLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
}

-(void)refreshAttachments
{
    // Set attachment quantity
    self.attachmentQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Files: %lu", nil), [self.editedNote.attachment count]];
    self.attachmentsArray = [self.editedNote.attachment allObjects];
    if([self.attachmentsArray count] == 0 && !self.attachmensAreHidden) {
        DLog(@"No attachments. Hiding collection view");
        [UIView animateWithDuration:0.5
                         animations:^{
                             self.currentAttachmentConstraintHeight = self.textToToolbarConstraint.constant = self.attachmentGreyRowToToolbarConstraint.constant = 0.0;
                             self.collectionView.alpha = self.attachmentsGreyRow.alpha = 0.0;
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished){
                             self.collectionView.hidden = self.attachmentsGreyRow.hidden = YES;
                             self.attachmensAreHidden = YES;
                         }];
    }
    if([self.attachmentsArray count] != 0 && self.attachmensAreHidden){
        DLog(@"Attachments found. Showing collection view");
        self.collectionView.hidden = self.attachmentsGreyRow.hidden = NO;
        [UIView animateWithDuration:0.5
                         animations:^{
                             self.currentAttachmentConstraintHeight = self.textToToolbarConstraint.constant = self.attachmentGreyRowToToolbarConstraint.constant = 63.0;
                             self.collectionView.alpha = self.attachmentsGreyRow.alpha = 1.0;
                             [self.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished){
                             self.attachmensAreHidden = NO;
                         }];
    }
    [self.collectionView reloadData];
}

#pragma mark - UIKeyboardNotifications

- (void)keyboardWillShow:(NSNotification *)aNotification {
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    BOOL isPortrait = UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
    CGFloat height = isPortrait ? kbSize.height : kbSize.width;
    self.textToToolbarConstraint.constant = height - self.theToolbar.frame.size.height;
    NSTimeInterval animationDuration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.textToToolbarConstraint.constant = self.currentAttachmentConstraintHeight;
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView {
    [textView scrollRangeToVisible:textView.selectedRange];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    // Keep the caret always visible
    [textView scrollRangeToVisible:range];
    return YES;
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.textEdit resignFirstResponder];
    [self save:nil];
}

- (IBAction)save:(id)sender
{
    // save (if useful) and pop back
    if([self.titleEdit.text isEqualToString:@""] || [self.textEdit.text isEqualToString:@""])
        return;
    self.editedNote.title = self.titleEdit.text;
    self.editedNote.text = self.textEdit.text;
    NSError *error;
    if(![self.noteEditorMOC save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    // Save on parent context
    [[IAMDataSyncController sharedInstance].dataSyncThreadContext performBlock:^{
        NSError *localError;
        if(![[IAMDataSyncController sharedInstance].dataSyncThreadContext save:&localError])
            ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
    }];
    // If title is changed, delete old note (with wrong name)
    if(![self.editedNote.title isEqualToString:self.originalTitle] && self.originalTitle && ![self.originalTitle isEqualToString:@""]) {
        [[IAMDataSyncController sharedInstance] deleteNoteTextWithUUID:self.editedNote.uuid afterFilenameChangeFrom:self.originalTitle];
        self.originalTitle = self.editedNote.title;
    }
    self.originalText = self.editedNote.text;
    // If called via action
    if(sender)
        [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)addImageToNote:(id)sender
{
    // Check what the client have.
    BOOL library = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    BOOL camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    if(library && camera) {
        // Let the user choose
        UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"New Attachment", nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"Image from Library", nil), NSLocalizedString(@"Image from Camera", nil), nil];
        [chooseIt showInView:self.view];
    } else if (camera) {
        [self showMediaPickerFor:UIImagePickerControllerSourceTypeCamera];
    } else if (library) {
        [self showMediaPickerFor:UIImagePickerControllerSourceTypePhotoLibrary];
    } else {
        // If no images available, tell user and disable button...
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No images available on this device", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
        [self.addImageButton setEnabled:NO];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if (buttonIndex == 0) {
        DLog(@"Library requested");
        [self showMediaPickerFor:UIImagePickerControllerSourceTypePhotoLibrary];
    } else if (buttonIndex == 1) {
        DLog(@"Camera requested");
        [self showMediaPickerFor:UIImagePickerControllerSourceTypeCamera];
    } else {
        DLog(@"Cancel selected");
    }
}

-(void)showMediaPickerFor:(UIImagePickerControllerSourceType)type
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.delegate = self;
	imagePicker.sourceType = type;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || type == UIImagePickerControllerSourceTypeCamera)
        [self presentViewController:imagePicker animated:YES completion:^{}];
    else
    {
         self.popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
        [self.popover presentPopoverFromBarButtonItem:self.addImageButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	// MediaType can be kUTTypeImage or kUTTypeMovie. If it's a movie then you
    // can get the URL to the actual file itself. This example only looks for images.
    NSLog(@"info: %@", info);
    NSString* mediaType = info[UIImagePickerControllerMediaType];
    // Try getting the edited image first. If it doesn't exist then you get the
    // original image.
    //
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo)
	{
        UIImage *pickedImage = info[UIImagePickerControllerEditedImage];
        if (!pickedImage)
			pickedImage = info[UIImagePickerControllerOriginalImage];
        // Fix orientation
        pickedImage = [pickedImage normalizedImage];
        // Now add attachment...
        Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.noteEditorMOC];
        newAttachment.uti = (__bridge NSString *)(kUTTypeImage);
        newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeImage, kUTTagClassFilenameExtension);
        if(!newAttachment.extension)
            newAttachment.extension = @"jpg";
        newAttachment.filename = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], newAttachment.extension];
        newAttachment.type = @"Image";
        newAttachment.data = UIImageJPEGRepresentation(pickedImage, 0.5);
        // Now link attachment to the note
        newAttachment.note = self.editedNote;
        [self.editedNote addAttachmentObject:newAttachment];
        [self save:nil];
        [self refreshAttachments];
    }
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [picker dismissViewControllerAnimated:YES completion:^{}];
    else
        [self.popover dismissPopoverAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [picker dismissViewControllerAnimated:YES completion:^{}];
    else
        [self.popover dismissPopoverAnimated:YES];
}

- (IBAction)shareAction:(id)sender
{
    // Save (but not return)
    [self save:nil];
    NSMutableArray *activityItems = [[NSMutableArray alloc] initWithObjects:self.editedNote.title, self.editedNote.text, nil];
    // loop on the attachments...
    for (Attachment *attachment in self.editedNote.attachment) {
        if([attachment.type isEqualToString:@"Link"]) {
            NSURL *linkToAdd = [NSURL URLWithString:[[NSString alloc] initWithData:attachment.data encoding:NSUTF8StringEncoding]];
            if(linkToAdd)
                [activityItems addObject:linkToAdd];
        } else if([attachment.type isEqualToString:@"Image"]) {
            UIImage *imageToAdd = [[UIImage alloc] initWithData:attachment.data];
            if(imageToAdd)
                [activityItems addObject:imageToAdd];
        }
    }
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll, UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypePostToWeibo];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

#pragma mark - IAMAddLinkViewControllerDelegate

- (void)addLinkViewController:(IAMAddLinkViewController *)addLinkViewController didAddThisLink:(NSString *)theLink {
    // Now add attachment...
    DLog(@"This is addLinkViewController: didAddThisLink: for '%@'", theLink);
    Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.noteEditorMOC];
    newAttachment.uti = (__bridge NSString *)(kUTTypeURL);
    newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeURL, kUTTagClassFilenameExtension);
    if(!newAttachment.extension)
        newAttachment.extension = @"url";
    newAttachment.filename = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], newAttachment.extension];
    newAttachment.type = @"Link";
    newAttachment.data = [theLink dataUsingEncoding:NSUTF8StringEncoding];
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    [self.editedNote addAttachmentObject:newAttachment];
    [self save:nil];
    [self refreshAttachments];
}

- (void)addLinkViewControllerDidCancelAction:(IAMAddLinkViewController *)addLinkViewController {
    DLog(@"This is addLinkViewControllerDidCancelAction:");
    [self refreshAttachments];
}

#pragma mark - AttachmentDeleter

-(void)deleteAttachment:(Attachment *)toBeDeleted
{
    [self.editedNote removeAttachmentObject:toBeDeleted];
    [self save:nil];
    [self refreshAttachments];
}

#pragma mark - Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"AddLink"])
    {
        IAMAddLinkViewController *segueController = [segue destinationViewController];
        segueController.delegate = self;
    }
    if ([[segue identifier] isEqualToString:@"AttachmentDetail"]) {
        IAMAttachmentDetailViewController *segueController = [segue destinationViewController];
        NSArray *indexPaths = [self.collectionView indexPathsForSelectedItems];
        NSIndexPath *index = [indexPaths objectAtIndex:0];
        DLog(@"Opening the detail for cell %d", index.row);
        Attachment *attachment = self.attachmentsArray[index.row];
        segueController.theAttachment = attachment;
        segueController.deleterObject = self;
    }
    if ([[segue identifier] isEqualToString:@"markdownPreview"]) {
        IAMMarkdownPreViewController *segueController = [segue destinationViewController];
        segueController.markdownTitle = self.editedNote.title;
        segueController.markdownText = self.editedNote.text;
        for (Attachment *attachment in self.editedNote.attachment) {
            [attachment generateFile];
        }
    }

}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSInteger retValue = [self.editedNote.attachment count];
    return retValue;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    IAMAttachmentCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AttachmentCell" forIndexPath:indexPath];
    Attachment *attachment = self.attachmentsArray[indexPath.row];
    cell.cellLabelView.text = attachment.type;
    if([attachment.type isEqualToString:@"Link"]) {
        cell.cellImageView.image = [UIImage imageNamed:@"link-icon-big"];
    } else if([attachment.type isEqualToString:@"Audio"]) {
        cell.cellImageView.image = [UIImage imageNamed:@"link-microphone-big"];
    } else if([attachment.type isEqualToString:@"Image"]) {
        cell.cellImageView.image = [[UIImage alloc] initWithData:attachment.data];
    } else {
        cell.cellImageView.image = [UIImage imageNamed:@"link-unknown-big"];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    DLog(@"This is collectionView:didSelectItemAtIndexPath:%d", indexPath.row);
    [self performSegueWithIdentifier:@"AttachmentDetail" sender:nil];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    DLog(@"This is collectionView:didDeselectItemAtIndexPath:%d", indexPath.row);
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(65, 65);
}

#pragma mark - AudioRecording Management

-(void)recordingOK:(NSString *)recordingFilename
{
	DLog(@"Received a record on %@", recordingFilename);
	// Now get rid of the view
	[self recordingCancelled];
    Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.noteEditorMOC];
    NSURL *url = [NSURL fileURLWithPath:recordingFilename];
    newAttachment.uti = (__bridge NSString *)(kUTTypeAudio);
    newAttachment.extension = [url pathExtension];
    newAttachment.filename = [url lastPathComponent];
    newAttachment.data = [NSData dataWithContentsOfURL:url];
    newAttachment.type = @"Audio";
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    [self.editedNote addAttachmentObject:newAttachment];
    [self save:nil];
    [self refreshAttachments];
}

- (void)recordingCancelled
{
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
		[self.recordView.view removeFromSuperview];
	else
		[self.popover dismissPopoverAnimated:YES];
	self.recordView = nil;
}

- (IBAction)recordAudio:(id)sender
{
	NSLog(@"This is voiceMail: handler");
	// Check for audio... (only on actual device)
	if(![[AVAudioSession sharedInstance] inputIsAvailable])
	{
		UIAlertView *theAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                                           message:NSLocalizedString(@"No audio input available", @"")
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
		[theAlert show];
		return;
	}
	if(self.recordView == nil)
	{
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
			self.recordView = [[MicrophoneWindow alloc] initWithNibName:@"MicrophoneWindow-iPad" bundle:nil];
		else
			self.recordView = [[MicrophoneWindow alloc] initWithNibName:@"MicrophoneWindow" bundle:nil];
		self.recordView.delegate = self;
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
			[self.view addSubview:self.recordView.view];
	}
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		UIPopoverController* aPopover = [[UIPopoverController alloc]
										 initWithContentViewController:self.recordView];
		aPopover.popoverContentSize = CGSizeMake(220.0, 300.0);
		
		// Store the popover in a custom property for later use.
		self.popover = aPopover;
		[self.popover presentPopoverFromBarButtonItem:self.recordingButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	}
}

@end
