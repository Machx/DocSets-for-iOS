//
//  BookmarkSyncLogViewController.m
//  DocSets
//
//  Created by Ole Zorn on 23.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarkSyncLogViewController.h"
#import "BookmarksManager.h"

@interface BookmarkSyncLogViewController ()

@end

@implementation BookmarkSyncLogViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logDidUpdate:) name:BookmarksManagerDidLogSyncEventNotification object:[BookmarksManager sharedBookmarksManager]];
    }
    return self;
}

- (void)viewDidLoad
{
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sendLog:)];
    [super viewDidLoad];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)logDidUpdate:(NSNotification *)notification
{
	[self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[[BookmarksManager sharedBookmarksManager] syncLog] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
	}
	NSMutableArray *log = [[BookmarksManager sharedBookmarksManager] syncLog];
	NSDictionary *logEntry = [log objectAtIndex:log.count - indexPath.row - 1];
	NSString *title = [logEntry objectForKey:kBookmarkSyncLogTitle];
	NSString *dateString = [NSDateFormatter localizedStringFromDate:[logEntry objectForKey:kBookmarkSyncLogDate] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
	int level = [[logEntry objectForKey:kBookmarkSyncLogLevel] intValue];
	cell.textLabel.text = title;
	cell.detailTextLabel.text = dateString;
	if (level == 0) {
		cell.imageView.image = [UIImage imageNamed:@"BubbleGreen.png"];
	} else if (level == 1) {
		cell.imageView.image = [UIImage imageNamed:@"BubbleOrange.png"];
	} else {
		cell.imageView.image = [UIImage imageNamed:@"BubbleRed.png"];
	}
	
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSMutableArray *log = [[BookmarksManager sharedBookmarksManager] syncLog];
	NSDictionary *logEntry = [log objectAtIndex:log.count - indexPath.row - 1];
	NSString *message = [logEntry objectForKey:kBookmarkSyncLogTitle];
	[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Log Message", nil) 
								message:message 
							   delegate:nil 
					  cancelButtonTitle:NSLocalizedString(@"OK", nil) 
					  otherButtonTitles:nil] show];
}

#pragma mark -

- (void)sendLog:(id)sender
{
	if ([MFMailComposeViewController canSendMail]) {
		MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
		composer.mailComposeDelegate = self;
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			composer.modalPresentationStyle = UIModalPresentationFormSheet;
		}
		[composer setSubject:@"DocSets Bookmark Sync Log"];
		[composer setToRecipients:[NSArray arrayWithObject:@"support@omz-software.com"]];
		NSMutableString *logString = [NSMutableString stringWithString:@"\n\n"];
		for (NSDictionary *logEntry in [[BookmarksManager sharedBookmarksManager] syncLog]) {
			NSString *title = [logEntry objectForKey:kBookmarkSyncLogTitle];
			NSDate *date = [logEntry objectForKey:kBookmarkSyncLogDate];
			[logString appendFormat:@"%@: %@\n\n", date, title];
		}
		[composer setMessageBody:logString isHTML:NO];
		NSData *bookmarksData = [[BookmarksManager sharedBookmarksManager] bookmarksDataForSharingSyncLog];
		if (bookmarksData) {
			[composer addAttachmentData:bookmarksData mimeType:@"application/x-plist" fileName:@"Bookmarks.plist"];
		}
        [self presentViewController:composer animated:YES completion:nil];
	} else {
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Send Mail", nil) 
									message:NSLocalizedString(@"Your device is not configured for sending email. Please use the Settings app to set up an email account.", nil) 
								   delegate:nil 
						  cancelButtonTitle:NSLocalizedString(@"OK", nil) 
						  otherButtonTitles:nil] show];
	}
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
