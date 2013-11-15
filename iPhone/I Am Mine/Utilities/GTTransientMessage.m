//
//  GTTransientMessage.m
//
//  Created by Giacomo Tufano on 24/08/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTTransientMessage.h"

#import "MBProgressHUD.h"

@implementation GTTransientMessage

+ (void)showWithTitle:(NSString *)title andSubTitle:(NSString *)subTitle forSeconds:(double)secondsDelay {
    UIView *topView = [[[[UIApplication sharedApplication] keyWindow] subviews] lastObject];
    if(topView) {
//        dispatch_sync(dispatch_get_main_queue(), ^{
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:topView animated:YES];
            hud.mode = MBProgressHUDModeText;
            hud.labelText = title;
            if (subTitle) {
                hud.detailsLabelText = subTitle;
            }
            [hud hide:YES afterDelay:secondsDelay];
//        });
    }
}

@end
