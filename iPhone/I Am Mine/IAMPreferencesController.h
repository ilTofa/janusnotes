//
//  IAMPreferencesController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
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

#define kPreferencesPopoverCanBeDismissed @"PreferencesPopoverCanBeDismissed"

typedef enum {
    sortModification = 0,
    sortCreation,
    sortTitle
} SortKey;

typedef enum {
    modificationDateShown = 0,
    creationDataShown
} DateShownKey;

@interface IAMPreferencesController : UITableViewController

@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UIStepper *sizeStepper;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UILabel *dropboxLabel;
@property (weak, nonatomic) IBOutlet UISwitch *encryptionSwitch;
@property (weak, nonatomic) IBOutlet UILabel *encryptionLabel;
@property (weak, nonatomic) IBOutlet UISwitch *lockSwitch;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sortSelector;
@property (weak, nonatomic) IBOutlet UISegmentedControl *dateSelector;
@property (weak, nonatomic) IBOutlet UILabel *productCoffeeLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *productCoffeeCell;
@property (weak, nonatomic) IBOutlet UILabel *productCoffeePriceLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *restoreCell;
@property (weak, nonatomic) IBOutlet UILabel *restoreCellLabel;

- (IBAction)sizePressed:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)encryptionAction:(id)sender;
- (IBAction)lockCodeAction:(id)sender;
- (IBAction)sortSelectorAction:(id)sender;
- (IBAction)dateSelectorAction:(id)sender;

@end
