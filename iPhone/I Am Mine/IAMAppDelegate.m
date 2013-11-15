//
//  IAMAppDelegate.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#import "GTThemer.h"
#import <Dropbox/Dropbox.h>
#import "IAMDataSyncController.h"
#import "iRate.h"
#import "STKeychain.h"
#import "GTTransientMessage.h"
#import "AHAlertView.h"

@interface IAMAppDelegate()

@end

@implementation IAMAppDelegate

+ (void)initialize {
    [iRate sharedInstance].daysUntilPrompt = 5;
    [iRate sharedInstance].usesUntilPrompt = 5;
    [iRate sharedInstance].appStoreID = 651150600;
    [iRate sharedInstance].appStoreGenreID = 0;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Starting, so we want PIN request (if any) later
    self.userInitedShutdown = YES;
    // init colorizer...
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [[GTThemer sharedInstance] saveStandardColors:[[GTThemer sharedInstance] getStandardColorsID]];
    }
    // Core Location init: get number of times user denied location use in app lifetime...
	self.nLocationUseDenies = [[NSUserDefaults standardUserDefaults] integerForKey:@"userDeny"];
	self.isLocationDenied = NO;
    self.locationString = NSLocalizedString(@"Location unknown", @"");
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    // Init datasync engine
    [IAMDataSyncController sharedInstance];
    // Set itself as store observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // Purge cache directory
    [self deleteCache];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {
    DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
    if (account) {
        DLog(@"App linked successfully!");
        return YES;
    }
    return NO;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    DLog(@"Marking user inited app shutdown.");
    self.userInitedShutdown = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    DLog(@"Here we are.");
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationWillResignActive:(UIApplication *)application {
    DLog(@"Resigning active.");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (!self.userInitedShutdown) {
        DLog(@"Active from external reason (no user inited), skipping PIN check");
        return;
    }
    self.userInitedShutdown = NO;
    NSError *error;
    NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
    if(pin) {
        DLog(@"PIN (%@) is required!", pin);
        [self getPIN];
    } else {
        DLog(@"PIN is not required");
    }
}

-(void)getPIN {
    AHAlertView *alertView = [[AHAlertView alloc] initWithTitle:NSLocalizedString(@"Enter Lock Code", nil) message:NSLocalizedString(@"Enter the lock code to access the application.", nil)];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [[alertView textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumberPad];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        [self applyCustomAlertAppearance];
        [alertView setButtonBackgroundImage:[self imageWithColor:[UIColor colorWithWhite:0.882 alpha:1.0]] forState:UIControlStateNormal];
    }
    __weak AHAlertView *weakAlert = alertView;
    [alertView addButtonWithTitle:NSLocalizedString(@"OK", nil) block:^ {
        DLog(@"Button clicked, text is: \'%@\'", [weakAlert textFieldAtIndex:0].text);
        NSError *error;
        NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
        if(!pin || ![pin isEqualToString:[weakAlert textFieldAtIndex:0].text]) {
            [self getPIN];
        }
    }];
    [alertView show];
}

- (void)applyCustomAlertAppearance
{
	[[AHAlertView appearance] setContentInsets:UIEdgeInsetsMake(12, 18, 12, 18)];
	[[AHAlertView appearance] setBackgroundImage:[self imageWithColor:[UIColor colorWithWhite:0.882 alpha:1.0]]];
	[[AHAlertView appearance] setTitleTextAttributes:[AHAlertView textAttributesWithFont:[UIFont boldSystemFontOfSize:18] foregroundColor:[UIColor blackColor] shadowColor:[UIColor clearColor] shadowOffset:CGSizeMake(0, -1)]];
	[[AHAlertView appearance] setMessageTextAttributes:[AHAlertView textAttributesWithFont:[UIFont systemFontOfSize:14] foregroundColor:[UIColor colorWithWhite:0.2 alpha:1.0] shadowColor:[UIColor clearColor] shadowOffset:CGSizeMake(0, -1)]];
	[[AHAlertView appearance] setButtonTitleTextAttributes:[AHAlertView textAttributesWithFont:[UIFont boldSystemFontOfSize:18] foregroundColor:[UIColor colorWithRed:0.004 green:0.475 blue:0.988 alpha:1.000] shadowColor:[UIColor clearColor] shadowOffset:CGSizeMake(0, -1)]];
}

- (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSLog(@"Button %d clicked, text is: \'%@\'", buttonIndex, [alertView textFieldAtIndex:0].text);
    NSError *error;
    NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
    if(!pin || ![pin isEqualToString:[alertView textFieldAtIndex:0].text]) {
        [self getPIN];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DLog(@"Here we are");
}

#pragma mark iAD

- (void)setSkipAds:(BOOL)skipAds {
    [[NSUserDefaults standardUserDefaults] setBool:skipAds forKey:@"skipAds"];
}

- (BOOL)skipAds {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"skipAds"];
}

#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                DLog(@"SKPaymentTransactionStatePurchased");
                self.skipAds = YES;
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
                [GTTransientMessage showWithTitle:@"Thank you!" andSubTitle:@"No Ad will be shown anymore." forSeconds:1.0];
                break;
            case SKPaymentTransactionStateFailed: {
                DLog(@"SKPaymentTransactionStateFailed");
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error purchasing: %@.", nil), [transaction.error localizedDescription]];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Error" message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
                [alert show];
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateRestored:
                DLog(@"SKPaymentTransactionStateRestored");
                self.skipAds = YES;
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
            case SKPaymentTransactionStatePurchasing:
                DLog(@"SKPaymentTransactionStatePurchasing");
                self.processingPurchase = YES;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error restoring purchase: %@.", nil), [error localizedDescription]];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    [alert show];
    self.processingPurchase = NO;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DLog(@"Restore finished");
    self.processingPurchase = NO;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    DLog(@"Called with %@", downloads);
}


#pragma mark - cache management

-(void)deleteCache {
    // Async load so don't use defaultManage, not thread safe
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [[NSFileManager alloc] init];
        NSError *error;
        NSString *directory = [[fileMgr URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] path];
        NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
        for (NSString *filename in fileArray)  {
            [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
        }
        fileMgr = nil;
    });
}

#pragma mark - CLLocationManagerDelegate and its delegate

- (void)startLocation {
    // if no location services, give up
    if(![CLLocationManager locationServicesEnabled])
        return;
	// If user already denied once this session, bail out
	if(self.isLocationDenied)
		return;
	// if user denied thrice, bail out...
	if(self.nLocationUseDenies >= 3)
		return;
    // Create the location manager (if needed)
    if(self.locationManager == nil) {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    }
    
    // Set a movement threshold for new events
    self.locationManager.distanceFilter = 500;
    
    [self.locationManager startUpdatingLocation];
}

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation {
    // Got a location, good.
    DLog(@"Got a location, good. lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy);
    self.locationString = [NSString stringWithFormat:@"lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy];
    // Notify the world that we have found ourselves
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
    // Now look for reverse geolocation
    CLGeocoder *theNewReverseGeocoder = [[CLGeocoder alloc] init];
    [theNewReverseGeocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        if(placemarks != nil) {
            CLPlacemark * placemark = placemarks[0];
            self.locationString = [NSString stringWithFormat:@"%@, %@, %@", placemark.locality, placemark.administrativeArea, placemark.country];
            // Notify the world that we have found ourselves
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
        } else {
            NSLog(@"Reverse geolocation failed with error: '%@'", [error localizedDescription]);
        }
    }];
    // If it's a relatively recent event and accuracy is satisfactory, turn off updates to save power (only if we're using standard location)
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 5.0 && newLocation.horizontalAccuracy < 501) {
        DLog(@"It's a relatively recent event and accuracy is satisfactory, turning off GPS");
        [manager stopUpdatingLocation];
        manager = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Location Manager error: %@", [error localizedDescription]);
	// if the user don't want to give us the rights, give up.
	if(error.code == kCLErrorDenied) {
		[manager stopUpdatingLocation];
		// mark that user already denied us for this session
		self.isLocationDenied = YES;
		// add one to Get how many times user refused and save to default
		self.nLocationUseDenies = self.nLocationUseDenies + 1;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:self.nLocationUseDenies forKey:@"userDeny"];
	}
}

@end
