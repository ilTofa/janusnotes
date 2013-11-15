//
//  IAMAttachmentDetailViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 07/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAttachmentDetailViewController.h"

#import "GTThemer.h"

#define kReadabilityBookmarkletCode @"(function(){window.baseUrl='https://www.readability.com';window.readabilityToken='';var s=document.createElement('script');s.setAttribute('type','text/javascript');s.setAttribute('charset','UTF-8');s.setAttribute('src',baseUrl+'/bookmarklet/read.js');document.documentElement.appendChild(s);})()"

@interface IAMAttachmentDetailViewController () <UIActionSheetDelegate, UIDocumentInteractionControllerDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *theWebView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *theSpinnerForWebView;
@property (weak, nonatomic) IBOutlet UIToolbar *theToolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;

@property (strong, nonatomic) UIDocumentInteractionController *interationController;

- (IBAction)goBackClicked:(id)sender;
- (IBAction)goForwardClicked:(id)sender;
- (IBAction)readability:(id)sender;

- (IBAction)openInSafari:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)deleteAttachment:(id)sender;

@end

@implementation IAMAttachmentDetailViewController

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
    NSAssert(self.theAttachment, @"No valid Attachment object sent to IAMAttachmentDetailViewController.");
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [[GTThemer sharedInstance] applyColorsToView:self.theToolbar];
        [[GTThemer sharedInstance] applyColorsToView:self.theWebView];
        [[GTThemer sharedInstance] applyColorsToView:self.view];
    }
    self.theWebView.clipsToBounds = NO;
    if(!self.deleterObject)
        [self.deleteButton setEnabled:NO];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.interationController = nil;
    if([self.theAttachment.type isEqualToString:@"Link"]) {
        [self.theWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSString alloc] initWithData:self.theAttachment.data encoding:NSUTF8StringEncoding]]]];
    } else {
        NSURL *file = [self.theAttachment generateFile];
        self.interationController = [UIDocumentInteractionController interactionControllerWithURL:file];
        self.interationController.delegate = self;
        self.interationController.UTI = self.theAttachment.uti;
        if([self.theAttachment.type isEqualToString:@"Image"]) {
            [self.theWebView loadData:self.theAttachment.data MIMEType:@"image/jpeg" textEncodingName:nil baseURL:nil];
        } else {
            [self.interationController presentOptionsMenuFromBarButtonItem:self.shareButton animated:YES];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIDocumentInterationControllerDelegate

- (UIView *) documentInteractionControllerViewForPreview: (UIDocumentInteractionController *) controller {
    return self.theWebView;
}

- (UIViewController *) documentInteractionControllerViewControllerForPreview: (UIDocumentInteractionController *) controller {
    return self;
}

#pragma mark - UIWebViewDelegate and actions

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.theSpinnerForWebView stopAnimating];
//    self.goForwardButton.enabled = [self.theWebView canGoForward];
//    self.goBackButton.enabled = [self.theWebView canGoBack];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.theSpinnerForWebView startAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"Error: %@", [error description]);
    [self webViewDidFinishLoad:webView];
}

#pragma mark - IBAction(s)

- (IBAction)goBackClicked:(id)sender
{
    [self.theWebView goBack];
}

- (IBAction)goForwardClicked:(id)sender
{
    [self.theWebView goForward];
}

- (IBAction)readability:(id)sender
{
    [self.theWebView stringByEvaluatingJavaScriptFromString:kReadabilityBookmarkletCode];
}

- (IBAction)openInSafari:(id)sender
{
    if(self.interationController)
        [self.interationController presentOptionsMenuFromBarButtonItem:self.shareButton animated:YES];
    else
        [[UIApplication sharedApplication] openURL:self.theWebView.request.URL];
}

- (IBAction)done:(id)sender
{
    if(self.interationController) {
        [self.interationController dismissMenuAnimated:YES];
        self.interationController = nil;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)deleteAttachment:(id)sender
{
    UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Delete Attachment from Note?", nil)
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", nil)
                                            destructiveButtonTitle:NSLocalizedString(@"Yes, Delete It!", nil)
                                                 otherButtonTitles:nil];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [chooseIt showInView:self.view];
    else
        [chooseIt showFromBarButtonItem:self.deleteButton animated:YES];
}

#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if(buttonIndex == 0)
    {
        [self.deleterObject deleteAttachment:self.theAttachment];
        [self done:nil];
    }
}


@end
