//
//  UIViewController+GTFrames.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 01/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "UIViewController+GTFrames.h"

// Extension to UIViewController to return the maxiumum usable frame size for a view

@implementation UIViewController (GTFrames)

- (CGRect) gt_maximumUsableFrame
{
    
    static CGFloat const kNavigationBarPortraitHeight = 44;
    static CGFloat const kNavigationBarLandscapeHeight = 34;
    static CGFloat const kToolBarHeight = 49;
    
    // Start with the screen size minus the status bar if present
    CGRect maxFrame = [UIScreen mainScreen].applicationFrame;
    
    // If the orientation is landscape left or landscape right then swap the width and height
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        CGFloat temp = maxFrame.size.height;
        maxFrame.size.height = maxFrame.size.width;
        maxFrame.size.width = temp;
    }
    
    // Take into account if there is a navigation bar present and visible (note that if the NavigationBar may
    // not be visible at this stage in the view controller's lifecycle.  If the NavigationBar is shown/hidden
    // in the loadView then this provides an accurate result.  If the NavigationBar is shown/hidden using the
    // navigationController:willShowViewController: delegate method then this will not be accurate until the
    // viewDidAppear method is called.
    if (self.navigationController) {
        if (self.navigationController.navigationBarHidden == NO) {
            
            // Depending upon the orientation reduce the height accordingly
            if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
                maxFrame.size.height -= kNavigationBarLandscapeHeight;
            }
            else {
                maxFrame.size.height -= kNavigationBarPortraitHeight;
            }
        }
    }
    
    // Take into account if there is a toolbar present and visible
    if (self.tabBarController) {
        if (!self.tabBarController.view.hidden) maxFrame.size.height -= kToolBarHeight;
    }
    // Compensate status bar
    if(maxFrame.origin.y == 20)
        maxFrame.origin.y = 0;
    return maxFrame;
}

@end
