//
//  IAMViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMViewController.h"

#import <iAd/iAd.h>

#import "IAMAppDelegate.h"
#import "IAMNoteCell.h"
#import "Note.h"
#import "IAMNoteEdit.h"
#import "GTThemer.h"
#import "IAMDataSyncController.h"
#import "MBProgressHUD.h"
#import "IAMPreferencesController.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"

@interface IAMViewController () <UISearchBarDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic) NSDateFormatter *dateFormatter;
@property MBProgressHUD *hud;

@property BOOL dropboxSyncStillPending;
@property (atomic) NSDate *lastDropboxSync;
@property NSTimer *pendingRefreshTimer;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *preferencesButton;

@property IAMAppDelegate *appDelegate;

@property UIPopoverController* popSegue;

@property SortKey sortKey;
@property DateShownKey dateShownKey;

- (IBAction)preferencesAction:(id)sender;

@end

@implementation IAMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dropboxSyncStillPending = NO;
    [self loadPreviousSearchKeys];
    // Load & set some sane defaults
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = self.appDelegate.coreDataController.mainThreadContext;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSyncNeedsThePassword:) name:kIAMDataSyncNeedsAPasswordNow object:nil];
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    NSArray *leftButtons = @[self.editButtonItem, self.preferencesButton];
    self.navigationItem.leftBarButtonItems = leftButtons;
    // Notifications to be honored during controller lifecycle
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissPopoverRequested:) name:kPreferencesPopoverCanBeDismissed object:nil];
    if([IAMDataSyncController sharedInstance].syncControllerReady)
        [self refreshControlSetup];
    [self processAds:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerReady object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerStopped object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreStillPendingChanges:) name:kIAMDataSyncStillPendingChanges object:nil];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dynamicFontChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    }
    [self setupFetchExecAndReload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [self colorize];
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        // Workaround a modification on tableView content inset that happens on returning from note editor.
        self.tableView.contentInset = UIEdgeInsetsMake(64.0, 0, 0, 0);
    }
    [self sortAgain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAds:) name:kSkipAdProcessingChanged object:nil];
    // if the dropbox backend have an user, but is not ready (that means it's waiting on something)
    if([IAMDataSyncController sharedInstance].syncControllerInited && ![IAMDataSyncController sharedInstance].syncControllerReady) {
        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Waiting for Dropbox", nil);
        self.hud.detailsLabelText = NSLocalizedString(@"First sync in progress, please wait.", nil);
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSkipAdProcessingChanged object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)processAds:(NSNotification *)note {
    if (note) {
        DLog(@"Called by notification...");
    }
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
}

- (void)dynamicFontChanged:(NSNotification *)aNotification {
    [self.tableView reloadData];
}

-(void)colorize
{
    [[GTThemer sharedInstance] applyColorsToView:self.tableView];
    [[GTThemer sharedInstance] applyColorsToView:self.navigationController.navigationBar];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    [[GTThemer sharedInstance] applyColorsToView:self.searchBar];
    [self.tableView reloadData];
}

- (void)sortAgain {
    self.sortKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateShownKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    DLog(@"Sort: %d, date: %d", self.sortKey, self.dateShownKey);
    [self setupFetchExecAndReload];
}

#define SECONDS_TO_WAIT_FOR_DROPBOX 15.0

- (void)rescheduleRefreshTimer {
    // Let's schedule a call to syncStatus for a later check for changes
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.pendingRefreshTimer.isValid) {
            DLog(@"Rescheduling refresh in %.0f seconds", SECONDS_TO_WAIT_FOR_DROPBOX + 1);
            if(self.pendingRefreshTimer) {
                [self.pendingRefreshTimer invalidate];
                self.pendingRefreshTimer = nil;
            }
            self.pendingRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:SECONDS_TO_WAIT_FOR_DROPBOX + 1 target:self selector:@selector(refreshDropboxContent:) userInfo:nil repeats:NO];
        } else {
            DLog(@"Refresh timer is already scheduled in %.0f", [[self.pendingRefreshTimer fireDate] timeIntervalSinceNow]);
        }
        self.dropboxSyncStillPending = YES;
    });
}

- (void)refreshControlSetup {
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Dropbox refresh", nil)];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    // Here we are sure there is an active dropbox link
//    self.syncStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(syncStatus:) userInfo:nil repeats:YES];
    IAMViewController __weak *weakSelf = self;
    [[DBFilesystem sharedFilesystem] addObserver:self forPathAndDescendants:[DBPath root] block:^{
        if([self.lastDropboxSync timeIntervalSinceNow] < -SECONDS_TO_WAIT_FOR_DROPBOX) {
            DLog(@"*** Files have changed in the dropbox filesystem, reloading");
            [weakSelf refreshDropboxContent:nil];
        } else {
            DLog(@"+++ Files have changed but not reloading, because not enough time has passed: %.0f secs from last reload.", -[self.lastDropboxSync timeIntervalSinceNow]);
            [self rescheduleRefreshTimer];
        }
    }];
    [[DBFilesystem sharedFilesystem] addObserver:self block:^{
        DLog(@"*** Status changed");
        [weakSelf syncStatus:nil];
//        [weakSelf rescheduleRefreshTimer];
    }];
}

- (void)checkForRefreshDropboxContentPending {
    DLog(@"Checking if a refresh of Dropbox content is needed.");
    if(self.dropboxSyncStillPending && [self.lastDropboxSync timeIntervalSinceNow] < -SECONDS_TO_WAIT_FOR_DROPBOX) {
        [self refreshDropboxContent:nil];
    }
}

- (void)refreshDropboxContent:(NSTimer *)timer {
    DLog(@"Reloading data from dropbox! Last reload %.0f seconds ago", -[self.lastDropboxSync timeIntervalSinceNow]);
    self.dropboxSyncStillPending = NO;
    self.lastDropboxSync = [NSDate date];
    [self syncStatus:nil];
    [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
}

-(void)syncStatus:(NSTimer *)timer {
    dispatch_async(dispatch_get_main_queue(), ^{
        DBSyncStatus status = [[DBFilesystem sharedFilesystem] status];
        DLog(@"Checking status%@: %d", (timer) ? @" from timer call" : @"", status);
        // DBSyncStatusActive is the default
        NSMutableString *title = [[NSMutableString alloc] initWithString:@"Sync "];
        if(!status || (status == DBSyncStatusActive)) {
            title = [NSLocalizedString(@"Notes ", nil) mutableCopy];
            if (self.dropboxSyncStillPending) {
                [title appendString:@"🕐"];
            } else {
                [title appendString:@"✔"];
            }
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            [self checkForRefreshDropboxContentPending];
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
        if (status & DBSyncStatusSyncing) {
            [title appendString:@"⇅"];
        }
        if(status & DBSyncStatusDownloading) {
            [title appendString:@"↓"];
            self.dropboxSyncStillPending = YES;
//            [self checkForRefreshDropboxContentPending];
        }
        if(status & DBSyncStatusUploading)
            [title appendString:@"↑"];
        self.title = title;
    });
}

-(void)refresh {
    [self.refreshControl beginRefreshing];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSyncNotificationHandler:) name:kIAMDataSyncRefreshTerminated object:nil];
    [self refreshDropboxContent:nil];
    [self syncStatus:nil];
}

- (void)syncStoreNotificationHandler:(NSNotification *)note {
    IAMDataSyncController *controller = note.object;
    if(controller.syncControllerReady) {
        [self refreshControlSetup];
        self.lastDropboxSync = [NSDate date];
    }
    else {
        self.refreshControl = nil;
        if(self.pendingRefreshTimer) {
            [self.pendingRefreshTimer invalidate];
            self.pendingRefreshTimer = nil;
        }
    }
    if(self.hud) {
        [self.hud hide:YES];
        self.hud = nil;
    }
}

- (void)syncStoreStillPendingChanges:(NSNotification *)note {
    DLog(@"Sync store is still pending syncronization.");
    [self rescheduleRefreshTimer];
}

- (void)endSyncNotificationHandler:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kIAMDataSyncRefreshTerminated object:nil];
    [self syncStatus:nil];
    [self.refreshControl endRefreshing];
}

- (void)dataSyncNeedsThePassword:(NSNotification *)notification {
    DLog(@"Notification caught for password need");
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            [self performSegueWithIdentifier:@"Preferences" sender:self];
        } else {
            [self performSegueWithIdentifier:@"Preferences7" sender:self];
        }
    } else {
        if ([self.popSegue isPopoverVisible]) {
            // protect double instancing
            return;
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
        NSString *preferencesID;
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            preferencesID = @"Preferences";
        } else {
            preferencesID = @"Preferences7";
        }
        IAMPreferencesController *pc = [storyboard instantiateViewControllerWithIdentifier:preferencesID];
        self.popSegue = [[UIPopoverController alloc] initWithContentViewController:pc];
        [self.popSegue presentPopoverFromBarButtonItem:self.preferencesButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

#pragma mark -
#pragma mark Search and search delegate

-(void)loadPreviousSearchKeys {
    self.searchText = [[NSUserDefaults standardUserDefaults] stringForKey:@"searchText"];
    if(!self.searchText)
        self.searchText = @"";
    self.searchBar.text = self.searchText;
}

-(void)saveSearchKeys {
    [[NSUserDefaults standardUserDefaults] setObject:self.searchText forKey:@"searchText"];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    searchBar.text = self.searchText = @"";
    [self setupFetchExecAndReload];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchBar.text;
    [self setupFetchExecAndReload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.searchText = searchBar.text;
    // Perform search... :)
    [self setupFetchExecAndReload];
}

- (void)setupFetchExecAndReload {
    // Set up the fetched results controller
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number
    [fetchRequest setFetchBatchSize:25];
    
    // Edit the sort key as appropriate.
    NSString *sortField = @"timeStamp";
    BOOL sortDirectionAscending = NO;
    if (self.sortKey == sortModification) {
        sortField = @"timeStamp";
    } else if (self.sortKey == sortCreation) {
        sortField = @"creationDate";
    } else if (self.sortKey == sortTitle) {
        sortField = @"title";
        sortDirectionAscending = YES;
    }
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:sortField ascending:sortDirectionAscending];
    NSArray *sortDescriptors = @[dateAddedSortDesc];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSString *queryString = nil;
    if(![self.searchText isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        NSArray *terms = [self.searchText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        for(NSString *term in terms)
        {
            if([term length] == 0)
                continue;
            if(queryString == nil)
                queryString = [NSString stringWithFormat:@"(text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND (text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
        }
    }
    else
        queryString = @"text  like[c] \"*\"";
//    DLog(@"Fetching again. Query string is: '%@'", queryString);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
    [fetchRequest setPredicate:predicate];
    
    NSString *sectionNameKeyPath = @"sectionIdentifier";
    if (self.sortKey == sortTitle) {
        sectionNameKeyPath = nil;
    } else if (self.sortKey == sortCreation) {
        sectionNameKeyPath = @"creationIdentifier";
    }
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:sectionNameKeyPath
                                                                                   cacheName:nil];
    self.fetchedResultsController.delegate = self;
    NSError *error = nil;
    if (self.fetchedResultsController != nil) {
        if (![[self fetchedResultsController] performFetch:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        else {
            [self.tableView reloadData];
            if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
                [self colorize];
            }
        }
    }
    [self saveSearchKeys];
}

#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (void)configureCell:(IAMNoteCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.titleLabel.text = note.title;
    cell.noteTextLabel.text = note.text;
    if (self.dateShownKey == modificationDateShown) {
        cell.dateLabel.text = [self.dateFormatter stringFromDate:note.timeStamp];
    } else {
        cell.dateLabel.text = [self.dateFormatter stringFromDate:note.creationDate];
    }
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [[GTThemer sharedInstance] applyColorsToLabel:cell.titleLabel withFontSize:17];
        [[GTThemer sharedInstance] applyColorsToLabel:cell.noteTextLabel withFontSize:12];
        [[GTThemer sharedInstance] applyColorsToLabel:cell.dateLabel withFontSize:10];
        [[GTThemer sharedInstance] applyColorsToLabel:cell.attachmentsQuantityLabel withFontSize:10];
    } else {
        cell.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.noteTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    }
    NSUInteger attachmentsQuantity = 0;
    if(note.attachment) {
        attachmentsQuantity = [note.attachment count];
    }
    cell.attachmentsQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu attachment(s)", nil), attachmentsQuantity];
}

// Override to customize the look of a cell representing an object. The default is to display
// a UITableViewCellStyleDefault style cell with the label being the first key in the object.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TextCell";
    IAMNoteCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[IAMNoteCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	NSInteger count = [[self.fetchedResultsController sections] count];
	return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
	NSInteger count = [sectionInfo numberOfObjects];
	return count;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Create a local moc, children of the sync moc and delete there.
        Note *noteInThisContext = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DLog(@"Deleting note %@", noteInThisContext.title);
        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        [moc setParentContext:[IAMDataSyncController sharedInstance].dataSyncThreadContext];
        NSURL *uri = [[noteInThisContext objectID] URIRepresentation];
        Note *delenda = (Note *)[moc objectWithURI:uri];
        if(!delenda) {
            ALog(@"*** Note is nil while deleting note!");
            return;
        }
        DLog(@"About to delete note: %@", delenda);
        [moc deleteObject:delenda];
        NSError *error;
        if(![moc save:&error])
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
        // Save on parent context
        [[IAMDataSyncController sharedInstance].dataSyncThreadContext performBlock:^{
            NSError *localError;
            if(![[IAMDataSyncController sharedInstance].dataSyncThreadContext save:&localError])
                ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
        }];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    // No sections (and section title) if sort by title
    if (self.sortKey == sortTitle) {
        return nil;
    }
	id <NSFetchedResultsSectionInfo> theSection = [[self.fetchedResultsController sections] objectAtIndex:section];
    /*
     Section information derives from an event's sectionIdentifier, which is a string representing the number (year * 1000) + month.
     To display the section title, convert the year and month components to a string representation.
     */
    static NSArray *monthSymbols = nil;
    
    if (!monthSymbols) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setCalendar:[NSCalendar currentCalendar]];
        monthSymbols = [formatter monthSymbols];
    }
    NSInteger numericSection = [[theSection name] integerValue];
	NSInteger year = numericSection / 1000;
	NSInteger month = numericSection - (year * 1000);
	NSString *titleString = [NSString stringWithFormat:@"%@ %d", [monthSymbols objectAtIndex:month-1], year];
	return titleString;
}

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark Segues

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // If on iPad and we already have an active popover for preferences, don't perform segue
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && ([identifier isEqualToString:@"Preferences"] || [identifier isEqualToString:@"Preferences7"]) && [self.popSegue isPopoverVisible])
        return NO;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
/*    if ([[segue identifier] isEqualToString:@"AddTextNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        // Create a new note
        IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.coreDataController.mainThreadContext];
        noteEditor.editedNote = newNote;
        noteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }*/
    if ([[segue identifier] isEqualToString:@"EditNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:self.tableView.indexPathForSelectedRow];
        selectedNote.timeStamp = [NSDate date];
        noteEditor.idForTheNoteToBeEdited = [selectedNote objectID];
    }
}

- (void)dismissPopoverRequested:(NSNotification *) notification
{
    DLog(@"This is dismissPopoverRequested: called for %@", notification.object);
    if ([self.popSegue isPopoverVisible])
    {
        [self.popSegue dismissPopoverAnimated:YES];
        self.popSegue = nil;
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            [self colorize];
        }
        [self sortAgain];
    }
}

- (IBAction)preferencesAction:(id)sender {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            [self performSegueWithIdentifier:@"Preferences" sender:self];
        } else {
            [self performSegueWithIdentifier:@"Preferences7" sender:self];
        }
    } else {
        if ([self.popSegue isPopoverVisible]) {
            // protect double instancing
            return;
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
        NSString *preferencesID;
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
            preferencesID = @"Preferences";
        } else {
            preferencesID = @"Preferences7";
        }
        IAMPreferencesController *pc = [storyboard instantiateViewControllerWithIdentifier:preferencesID];
        self.popSegue = [[UIPopoverController alloc] initWithContentViewController:pc];
        [self.popSegue presentPopoverFromBarButtonItem:self.preferencesButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

@end
