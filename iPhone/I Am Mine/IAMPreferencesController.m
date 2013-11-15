//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPreferencesController.h"

#import "GTThemer.h"
#import <Dropbox/Dropbox.h>
#import <MessageUI/MessageUI.h>
#import <StoreKit/StoreKit.h>
#import "IAMAppDelegate.h"
#import "iRate.h"
#import "IAMDataSyncController.h"
#import "MBProgressHUD.h"
#import "STKeychain.h"

typedef enum {
    supportJanus = 0,
    syncManagement,
    lockSelector,
    sortSelector,
    fontSelector,
    sizeSelector,
    colorSelector
} sectionIdentifiers;

typedef enum {
    supportHelp = 0,
    supportUnsatisfied,
    supportSatisfied,
    supportCoffee,
    supportRestore
} supportOptions;

@interface IAMPreferencesController () <MFMailComposeViewControllerDelegate, SKProductsRequestDelegate>

@property NSInteger fontFace, fontSize, colorSet;

@property MBProgressHUD *hud;

@property UIAlertView *passwordAlert;
@property UIAlertView *lockCodeAlert;

@property BOOL dropboxLinked;

@property NSArray *products;

@end

@implementation IAMPreferencesController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.versionLabel.text = [NSString stringWithFormat:@"This I Am Mine version %@ (%@)\n©2013 Giacomo Tufano - All rights reserved.\nIcons from icons8, licensed CC BY-ND 3.0", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    NSError *error;
    self.lockSwitch.on = ([STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error] != nil);
    self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
    self.sortSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        NSDictionary *fontAttributes = @{UITextAttributeFont: [UIFont boldSystemFontOfSize:13.0f]};
        [self.sortSelector setTitleTextAttributes:fontAttributes forState:UIControlStateNormal];
        [self.dateSelector setTitleTextAttributes:fontAttributes forState:UIControlStateNormal];
        self.fontSize = [[GTThemer sharedInstance] getStandardFontSize];
        [self.sizeStepper setValue:self.fontSize];
        self.colorSet = [[GTThemer sharedInstance] getStandardColorsID];
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:colorSelector] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
        self.fontFace = [[GTThemer sharedInstance] getStandardFontFaceID];
        [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.fontFace inSection:fontSelector] animated:false scrollPosition:UITableViewScrollPositionTop];
        [self sizePressed:nil];
    }
    [self.tableView setContentOffset:CGPointZero animated:YES];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Mark selected color...
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:colorSelector]];
        tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skipAdProcessed:) name:kSkipAdProcessingChanged object:nil];
    [self updateDropboxUI];
    [self updateStoreUI];
    if([[IAMDataSyncController sharedInstance] needsSyncPassword]) {
        [self changePasswordASAP];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidDisappear:animated];
}

- (void)skipAdProcessed:(NSNotification *)aNotification {
    DLog(@"Got a notifaction for store processing");
    [self updateStoreUI];
}

- (void)disableAllStoreUIOptions {
    self.productCoffeeCell.userInteractionEnabled = self.restoreCell.userInteractionEnabled = NO;
    self.productCoffeeLabel.enabled = self.restoreCellLabel.enabled = NO;
    self.productCoffeePriceLabel.enabled = NO;
    self.productCoffeePriceLabel.text = @"-";
}

- (void)updateStoreUI {
    // Disable store while we look for the products
    [self disableAllStoreUIOptions];
    // No money? No products!
    if (![SKPaymentQueue canMakePayments]) {
        self.productCoffeePriceLabel.text = @"Payments disabled.";
        return;
    }
    // If user already paid, leave disabled
    if (((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).skipAds) {
        self.productCoffeePriceLabel.text = @"Already bought.";
        return;
    }
    // If a transaction is already in progress, leave disabled
    if (((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).processingPurchase) {
        self.productCoffeePriceLabel.text = @"Transaction still in progress.";
        return;
    }
    DLog(@"starting request for products.");
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"In-App-Products" withExtension:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfURL:url];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

// SKProductsRequestDelegate protocol method
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    self.products = response.products;
    for (NSString * invalidProductIdentifier in response.invalidProductIdentifiers) {
        // Handle any invalid product identifiers.
    }
    DLog(@"%@", self.products);
     // Custom method
    if ([self.products count] == 0) {
        DLog(@"Void or invalid product array, returning");
        return;
    }
    SKProduct *product = self.products[0];
    self.productCoffeeLabel.text = product.localizedTitle;
    NSNumberFormatter * numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString * formattedPrice = [numberFormatter stringFromNumber:product.price];
    self.productCoffeePriceLabel.text = formattedPrice;
    self.productCoffeeCell.userInteractionEnabled = self.productCoffeeLabel.enabled = self.productCoffeePriceLabel.enabled = YES;
    self.restoreCell.userInteractionEnabled = self.restoreCellLabel.enabled = YES;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DLog(@"request failed: %@,  %@", request, error);
}

-(void)updateDropboxUI {
    // Check Dropbox linking
    DBAccount *dropboxAccount = [[DBAccountManager sharedManager] linkedAccount];
    if(!dropboxAccount) {
        self.dropboxLinked = NO;
        self.dropboxLabel.text = NSLocalizedString(@"Syncronize Notes with Dropbox", nil);
        self.encryptionSwitch.enabled = NO;
        self.encryptionLabel.text = @"";
    }
    else {
        self.dropboxLinked = YES;
        self.dropboxLabel.text = NSLocalizedString(@"Stop Notes Sync with Dropbox", nil);
        self.encryptionSwitch.enabled = YES;
        if(self.encryptionSwitch.isOn) {
            self.encryptionLabel.text = NSLocalizedString(@"Change Encryption Password", nil);
        } else {
            self.encryptionLabel.text = @"";
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dropbox
    if(indexPath.section == syncManagement) {
        // Dropbox link
        if(indexPath.row == 0) {
            if(self.dropboxLinked) {
                DLog(@"Logout from dropbox");
                [[[DBAccountManager sharedManager] linkedAccount] unlink];
            } else {
                DLog(@"Login into dropbox");
                [[DBAccountManager sharedManager] linkFromController:self];
                // Wait a while for app syncing.
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                    [self updateDropboxUI];
                });
            }
            [self updateDropboxUI];
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                [self done:self];
            }
        }
        // Change password (only if already encrypted)
        if(indexPath.row == 2) {
            if ([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
                [self changePassword];
            }
        }
    }
    // Change font
    if(indexPath.section == fontSelector) {
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:self.fontFace inSection:fontSelector];
        DLog(@"Changing font from %d to %d.", self.fontFace, indexPath.row);
        [tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        self.fontFace = indexPath.row;
    }
    // Change colors
    if(indexPath.section == colorSelector) {
        NSInteger oldColorsSet = [[GTThemer sharedInstance] getStandardColorsID];
        DLog(@"Changing colors set from %d to %d.", oldColorsSet, indexPath.row);
        UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:indexPath];
        tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:oldColorsSet inSection:colorSelector];
        tableCell = [self.tableView cellForRowAtIndexPath:oldIndexPath];
        tableCell.accessoryType = UITableViewCellAccessoryNone;
        [tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        self.colorSet = indexPath.row;
    }
    // Change lock status
    if(indexPath.section == lockSelector) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    // Sorting
    if(indexPath.section == sortSelector) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    // Change size
    if (indexPath.section == sizeSelector) {
        [self sizePressed:nil];
    }
    // Support
    if (indexPath.section == supportJanus) {
        if (indexPath.row == supportHelp) {
            DLog(@"Call help site.");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/help/"]];
        } else if (indexPath.row == supportUnsatisfied) {
            DLog(@"Prepare email to support");
            [self sendCommentAction:self];
        } else if (indexPath.row == supportSatisfied) {
            DLog(@"Call iRate for rating");
            [[iRate sharedInstance] openRatingsPageInAppStore];
        } else if (indexPath.row == supportCoffee) {
            DLog(@"Buy Ads Removal");
            SKPayment *payment = [SKPayment paymentWithProduct:self.products[0]];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        } else if (indexPath.row == supportRestore) {
            DLog(@"Restore Ads Removal");
            [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
            [self disableAllStoreUIOptions];
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DLog(@"This is tableView willDeselectRowAtIndexPath: %@", indexPath);
    // Don't deselect the selected row.
    if(indexPath.section == fontSelector && indexPath.row == self.fontFace)
        return nil;
    if(indexPath.section == colorSelector && indexPath.row == self.colorSet)
        return nil;
    return indexPath;
}

#pragma mark - Comment by email

- (IBAction)sendCommentAction:(id)sender {
    MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
    controller.mailComposeDelegate = self;
    [controller setToRecipients:@[@"support@janusnotes.com"]];
    [controller setSubject:[NSString stringWithFormat:@"Feedback on Janus Notes iOS app version %@ (%@)", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]]];
    [controller setMessageBody:@"" isHTML:NO];
    if (controller)
        [self presentViewController:controller animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    NSString *title;
    NSString *text;
    BOOL dismiss = NO;
    if (result == MFMailComposeResultSent) {
        title = @"Information";
        text = @"E-mail successfully sent. Thank you for the feedback!";
        dismiss = YES;
    } else if (result == MFMailComposeResultFailed) {
        title = @"Warning";
        text = @"Could not send email, please try again later.";
    } else {
        dismiss = YES;
    }
    if (text) {
        UIAlertView *alertBox = [[UIAlertView alloc] initWithTitle:title message:text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertBox show];
    }
    if(dismiss) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Actions

-(IBAction)sizePressed:(id)sender
{
    DLog(@"This is sizePressed: called for a value of: %.0f", self.sizeStepper.value);
    self.fontSize = self.sizeStepper.value;
    self.sizeLabel.text = [NSString stringWithFormat:@"Text Size is %d", self.fontSize];
    [[GTThemer sharedInstance] applyColorsToLabel:self.sizeLabel withFontSize:self.fontSize];
    [[GTThemer sharedInstance] saveStandardColors:self.colorSet];
    
}

- (IBAction)done:(id)sender
{
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        DLog(@"Saving. ColorSet n° %d, fontFace n° %d, fontSize %d", self.colorSet, self.fontFace, self.fontSize);
        [[GTThemer sharedInstance] saveStandardColors:self.colorSet];
        [[GTThemer sharedInstance] saveStandardFontsWithFaceID:self.fontFace andSize:self.fontSize];
    }
    // Dismiss (or ask for dismissing)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesPopoverCanBeDismissed object:self];
    else
        [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)pleaseNotNow {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"Please wait for the dropbox sync to finish before starting re-encrytion", nil)
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    [alertView show];
    self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
}

- (void)changePassword {
    DBSyncStatus status = [[DBFilesystem sharedFilesystem] status];
    if (status && (status != DBSyncStatusActive)) {
        [self pleaseNotNow];
        return;
    }
    self.passwordAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Set Crypt Password", nil)
                                                    message:NSLocalizedString(@"This password will crypt and decrypt your notes.\nPlease choose a strong password and note it somewhere. Your notes will *not* be readable anymore without the password! Don't lose or forget it!", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"OK. Crypt!", nil), nil];
    self.passwordAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    if ([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
        [self.passwordAlert textFieldAtIndex:0].text = [[IAMDataSyncController sharedInstance] cryptPassword];
    }
    [self.passwordAlert show];
}

- (void)changePasswordASAP {
    self.passwordAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Set Crypt Password", nil)
                                                    message:NSLocalizedString(@"Please insert remote crypt password.", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                          otherButtonTitles:NSLocalizedString(@"Save", nil), nil];
    self.passwordAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    if ([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
        [self.passwordAlert textFieldAtIndex:0].text = [[IAMDataSyncController sharedInstance] cryptPassword];
    }
    [self.passwordAlert show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // Password setup for dropbox encryption
    if(alertView == self.passwordAlert) {
        if ([[IAMDataSyncController sharedInstance] needsSyncPassword]) {   // This is the handler for changed password on remote
            [[IAMDataSyncController sharedInstance] setNeedsSyncPassword:NO];
            NSError *error;
            if(buttonIndex == 1 && ![[alertView textFieldAtIndex:0].text isEqualToString:@""]) {
                if([[IAMDataSyncController sharedInstance] checkCryptPassword:[alertView textFieldAtIndex:0].text error:&error]) {
                    [[IAMDataSyncController sharedInstance] setCryptPassword:[alertView textFieldAtIndex:0].text];
                }
            }
            // in any case... if password is not OK, the refresh will fail and this one recalled. :)
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesPopoverCanBeDismissed object:self];
            else
                [self.navigationController popToRootViewControllerAnimated:YES];
            // Give UI a second to stabilize (the call could reload this frame)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
            });
        } else {
            NSLog(@"Button %d clicked, text is: \'%@\'", buttonIndex, [alertView textFieldAtIndex:0].text);
            if(buttonIndex == 1 && ![[alertView textFieldAtIndex:0].text isEqualToString:@""]) {
                self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                self.hud.labelText = NSLocalizedString(@"Encrypting Notes", nil);
                if([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
                    DLog(@"Notes are already encrypted. Re-Crypt with new password: %@", [alertView textFieldAtIndex:0].text);
                    self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we crypt the notes...", nil);
                    [[IAMDataSyncController sharedInstance] cryptNotesWithPassword:[alertView textFieldAtIndex:0].text andCompletionBlock:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if(self.hud) {
                                [self.hud hide:YES];
                                self.hud = nil;
                            }
                        });
                    }];
                } else {
                    DLog(@"Crypt now the notes with key: \'%@\'", [alertView textFieldAtIndex:0].text);
                    self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we re-encrypt the notes...", nil);
                    [[IAMDataSyncController sharedInstance] cryptNotesWithPassword:[alertView textFieldAtIndex:0].text andCompletionBlock:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if(self.hud) {
                                [self.hud hide:YES];
                                self.hud = nil;
                            }
                        });
                    }];
                }
            } else {
                self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
            }
        }
        self.passwordAlert = nil;
    }
    // lock code setup
    if(alertView == self.lockCodeAlert) {
        if(buttonIndex != alertView.cancelButtonIndex) {
            NSLog(@"Button %d clicked, text is: \'%@\'", buttonIndex, [alertView textFieldAtIndex:0].text);
            NSError *error;
            [STKeychain storeUsername:@"lockCode" andPassword:[alertView textFieldAtIndex:0].text forServiceName:@"it.iltofa.janus" updateExisting:YES error:&error];
            UIAlertView *lastAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Lock Code Set", nil)
                                                                message:[NSString stringWithFormat:NSLocalizedString(@"You just set the application lock code to %@.", nil), [alertView textFieldAtIndex:0].text]
                                                               delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
            lastAlert.alertViewStyle = UIAlertViewStyleDefault;
            [lastAlert show];
        }
        self.lockCodeAlert = nil;
    }
}

- (IBAction)encryptionAction:(id)sender {
    if (self.encryptionSwitch.isOn) {
        [self changePassword];
    } else {
        DBSyncStatus status = [[DBFilesystem sharedFilesystem] status];
        if (status && (status != DBSyncStatusActive)) {
            [self pleaseNotNow];
            return;
        }
        DLog(@"Remove crypt now.");
        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Decrypting Notes", nil);
        self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we decrypt the notes...", nil);
        [[IAMDataSyncController sharedInstance] decryptNotesWithCompletionBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if(self.hud) {
                    [self.hud hide:YES];
                    self.hud = nil;
                }
            });
        }];
    }
}

- (IBAction)lockCodeAction:(id)sender {
    if(self.lockSwitch.on) {
        self.lockCodeAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Set Lock Code", nil)
                                                        message:NSLocalizedString(@"This code will be asked at app startup.", nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              otherButtonTitles:NSLocalizedString(@"Done", nil), nil];
        self.lockCodeAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            [[self.lockCodeAlert textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumberPad];
        [self.lockCodeAlert show];
    } else {
        NSError *error;
        [STKeychain deleteItemForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
    }
}

- (IBAction)sortSelectorAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.sortSelector.selectedSegmentIndex forKey:@"sortBy"];
}

- (IBAction)dateSelectorAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.dateSelector.selectedSegmentIndex forKey:@"dateShown"];
}

@end
