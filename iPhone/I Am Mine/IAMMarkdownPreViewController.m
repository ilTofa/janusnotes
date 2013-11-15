//
//  IAMMarkdownPreViewController.m
//  iJanus
//
//  Created by Giacomo Tufano on 24/10/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMMarkdownPreViewController.h"

#import "markdown.h"
#import "html.h"

#import "IAMAppDelegate.h"
#import <iAd/iAd.h>

@interface IAMMarkdownPreViewController ()

@property (strong) NSString *previewStyleHTML;
@property (strong) NSURL *cacheDirectory;
@property (strong) NSURL *cacheFile;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIWebView *theWebView;

- (IBAction)actionDone:(id)sender;

@end

@implementation IAMMarkdownPreViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Load preview support files
    NSError *error;
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"MarkdownPreview" ofType:@"html"];
    self.previewStyleHTML = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    self.cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    self.cacheFile = [self.cacheDirectory URLByAppendingPathComponent:@"preview.html"];
    self.titleLabel.text = self.markdownTitle;
    if ([self respondsToSelector:@selector(setCanDisplayBannerAds:)]) {
        if (!((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).skipAds) {
            DLog(@"Preparing Ads");
            self.canDisplayBannerAds = YES;
            self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyAutomatic;
        } else {
            DLog(@"Skipping ads");
            self.canDisplayBannerAds = NO;
            self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyNone;
        }
    }
    [self loadMarkdownPreview];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    // Redirect links to external browser if is a link or "other" with a real (not "file:") url
    if ((navigationType == UIWebViewNavigationTypeLinkClicked) ||
        (navigationType == UIWebViewNavigationTypeOther && ![request.URL isFileURL])) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:request.URL];
        });
        return NO;
    }
    return YES;
}

#pragma mark - markdown support

- (void)loadMarkdownPreview {
    NSMutableString *htmlString = [self.previewStyleHTML mutableCopy];
    [htmlString replaceOccurrencesOfString:@"this_is_where_the_title_goes" withString:self.markdownTitle options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];
    [htmlString replaceOccurrencesOfString:@"this_is_where_the_text_goes" withString:[self convertToHTML:self.self.markdownText] options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];
    [htmlString replaceOccurrencesOfString:@"$attachment$!" withString:[self.cacheDirectory absoluteString] options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];
    NSError *error;
    [htmlString writeToURL:self.cacheFile atomically:NO encoding:NSUTF8StringEncoding error:&error];
    [self.theWebView loadRequest:[NSURLRequest requestWithURL:self.cacheFile]];
    //    [self.previewWebView.mainFrame loadHTMLString:htmlString baseURL:self.cacheDirectory];
}

- (NSString *)convertToHTML:(NSString *)rawMarkdown {
    const char * prose = [rawMarkdown UTF8String];
    struct buf *ib, *ob;
    
    unsigned long length = [rawMarkdown lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    
    ib = bufnew(length);
    bufgrow(ib, length);
    memcpy(ib->data, prose, length);
    ib->size = length;
    
    ob = bufnew(64);
    
    struct sd_callbacks callbacks;
    struct html_renderopt options;
    struct sd_markdown *markdown;
    
    
    sdhtml_renderer(&callbacks, &options, 0);
    markdown = sd_markdown_new(0, 16, &callbacks, &options);
    
    sd_markdown_render(ob, ib->data, ib->size, markdown);
    sd_markdown_free(markdown);
    
    
    NSString *shinyNewHTML = [NSString stringWithUTF8String:(const char *)ob->data];
    
    bufrelease(ib);
    bufrelease(ob);
    return shinyNewHTML;
}

#pragma mark - Actions

- (IBAction)actionDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
