//
//  RootViewController.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "RootViewController.h"
#import "DetailViewController.h"
#import "DocSetViewController.h"
#import "DownloadViewController.h"
#import "DocSetDownloadManager.h"
#import "DocSet.h"
#import "AboutViewController.h"

#define FIRST_USE_ALERT_TAG		1

@implementation RootViewController

@synthesize detailViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nil bundle:nil];
	self.title = NSLocalizedString(@"DocSets",nil);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(docSetsChanged:) name:DocSetDownloadManagerUpdatedDocSetsNotification object:nil];
	return self;
}

- (void)viewDidLoad 
{
	[super viewDidLoad];
	self.tableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
	self.clearsSelectionOnViewWillAppear = YES;
	self.contentSizeForViewInPopover = CGSizeMake(400.0, 1024.0);
	self.tableView.rowHeight = 64.0;
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addDocSet:)];
	self.navigationItem.rightBarButtonItem = [self editButtonItem];
	
	UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 64)];
	UIButton *aboutButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[aboutButton setTitle:NSLocalizedString(@"About DocSets", nil) forState:UIControlStateNormal];
	[aboutButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
	aboutButton.titleLabel.font = [UIFont systemFontOfSize:14.0];
	aboutButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	aboutButton.showsTouchWhenHighlighted = YES;
	[aboutButton setFrame:CGRectInset(footerView.bounds, 50, 20)];
	[aboutButton addTarget:self action:@selector(showInfo:) forControlEvents:UIControlEventTouchUpInside];
	[footerView addSubview:aboutButton];
	self.tableView.tableFooterView = footerView;
	
	double delayInSeconds = 0.5;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		if ([[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] count] == 0) {
			UIAlertView *firstUseAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Welcome", nil)
																	message:NSLocalizedString(@"To start using the app, you have to download one or more documentation sets first.\n\nTo download more sets later, use the ✚ button.", nil) 
																   delegate:self
														  cancelButtonTitle:NSLocalizedString(@"Cancel", nil) 
														  otherButtonTitles:NSLocalizedString(@"Download...", nil), nil];
			firstUseAlert.tag = FIRST_USE_ALERT_TAG;
			[firstUseAlert show];
		}
	});
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == FIRST_USE_ALERT_TAG) {
		if (buttonIndex == alertView.cancelButtonIndex) return;
		[self addDocSet:nil];
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

- (void)addDocSet:(id)sender
{
	DownloadViewController *vc = [[DownloadViewController alloc] initWithStyle:UITableViewStyleGrouped];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
	navController.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentModalViewController:navController animated:YES];
}

- (void)showInfo:(id)sender
{
	//TODO: Show info dialog with libxar license
	AboutViewController *vc = [[AboutViewController alloc] initWithNibName:nil bundle:nil];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		navController.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	[self.view.window.rootViewController presentModalViewController:navController animated:YES];
}

- (void)docSetsChanged:(NSNotification *)notification
{
	if (!self.editing) {
		[self.tableView reloadData];
	}
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView 
{
	return 1;
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section 
{
	return [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	static NSString *CellIdentifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.imageView.image = [UIImage imageNamed:@"DocSet.png"];
    }
    
	DocSet *docSet = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
    cell.textLabel.text = docSet.title;
	cell.detailTextLabel.text = docSet.copyright;
	
	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		DocSet *docSetToDelete = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
		[[DocSetDownloadManager sharedDownloadManager] deleteDocSet:docSetToDelete];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	DocSet *selectedDocSet = [[[DocSetDownloadManager sharedDownloadManager] downloadedDocSets] objectAtIndex:indexPath.row];
	DocSetViewController *docSetViewController = [[DocSetViewController alloc] initWithDocSet:selectedDocSet rootNode:nil];
	docSetViewController.detailViewController = self.detailViewController;
	[self.navigationController pushViewController:docSetViewController animated:YES];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && !self.detailViewController.docSet) {
		//enables the bookmarks button
		self.detailViewController.docSet = selectedDocSet;
	}
}

#pragma mark -

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end

