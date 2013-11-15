//
//  IAMAppDelegate.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
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
#import <MapKit/MapKit.h>
#import <StoreKit/StoreKit.h>

#import "CoreDataController.h"

#define kGotLocation @"gotLocation"
#define kSkipAdProcessingChanged @"skipAdChanged"

@interface IAMAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate, SKPaymentTransactionObserver>

@property (strong, nonatomic) UIWindow *window;

// helpers for corelocation.
@property (nonatomic, assign) BOOL isLocationDenied;
@property (nonatomic, assign) int nLocationUseDenies;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic) NSString *locationString;

// CoreData helper
@property (nonatomic, strong, readonly) CoreDataController *coreDataController;

// Ads
@property (nonatomic) BOOL skipAds;
@property (atomic) BOOL processingPurchase;
@property (atomic) BOOL userInitedShutdown;

@end
