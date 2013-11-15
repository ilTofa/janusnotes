//
//  IAMAddLinkViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 06/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAddLinkViewController.h"

#import "GTThemer.h"

@interface IAMAddLinkViewController ()

@end

@implementation IAMAddLinkViewController

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
    [[GTThemer sharedInstance] applyColorsToView:self.linkEditor];
    [[GTThemer sharedInstance] applyColorsToView:self.view];
    [self.linkEditor becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)isAValidUrl:(NSString *)candidate {
    NSURL *candidateURL = [NSURL URLWithString:self.linkEditor.text];
    if (candidateURL && candidateURL.scheme && candidateURL.host)
        return YES;
    else {
        // Try to add the protocol and retry...
        NSString *paddedString = [NSString stringWithFormat:@"http://%@", self.linkEditor.text];
        candidateURL = [NSURL URLWithString:paddedString];
        if (candidateURL && candidateURL.scheme && candidateURL.host) {
            // Save the padded string and say yes
            self.linkEditor.text = paddedString;
            return YES;
        }
    }
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if([self isAValidUrl:self.linkEditor.text])
        [textField resignFirstResponder];
    [self done:nil];
    return NO;
}

- (IBAction)cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    if(self.delegate)
        [self.delegate addLinkViewControllerDidCancelAction:self];
}

- (IBAction)done:(id)sender {
    // Do whatever needed to save
    if ([self isAValidUrl:self.linkEditor.text]) {
        // URL is valid, can be saved
        if(self.delegate)
            [self.delegate addLinkViewController:self didAddThisLink:self.linkEditor.text];
        [self cancel:nil];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:NSLocalizedString(@"Link is not a valid URL, please edit it or tap cancel.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    }
}

@end
