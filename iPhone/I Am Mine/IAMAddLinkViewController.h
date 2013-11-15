//
//  IAMAddLinkViewController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 06/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IAMAddLinkViewController;

@protocol IAMAddLinkViewControllerDelegate <NSObject>

- (void)addLinkViewController:(IAMAddLinkViewController *)addLinkViewController didAddThisLink:(NSString *)theLink;
- (void)addLinkViewControllerDidCancelAction:(IAMAddLinkViewController *)addLinkViewController;

@end

@interface IAMAddLinkViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *linkEditor;

@property (weak, nonatomic) id<IAMAddLinkViewControllerDelegate>delegate;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
