//
//  DocSetViewController.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "DocSetViewController.h"
#import "DocSet.h"
#import "DetailViewController.h"
#import "BookmarksViewController.h"

#define SEARCH_SPINNER_TAG	1

@interface DocSetViewController ()

- (void)reloadSearchResults;
- (void)openNode:(NSManagedObject *)node;

@end


@implementation DocSetViewController

@synthesize docSet, rootNode, detailViewController, searchResults, searchDisplayController;

- (id)initWithDocSet:(DocSet *)set rootNode:(NSManagedObject *)node
{
	self = [super initWithStyle:UITableViewStylePlain];
	
	docSet = set;
	rootNode = node;
	nodeSections = [docSet nodeSectionsForRootNode:rootNode];
	
	self.title = (rootNode != nil) ? [rootNode valueForKey:@"kName"] : docSet.title;
	self.contentSizeForViewInPopover = CGSizeMake(400.0, 1024.0);
	
	iconsByTokenType = [[NSDictionary alloc] initWithObjectsAndKeys:
						[UIImage imageNamed:@"Const"], @"econst",
						[UIImage imageNamed:@"Member.png"], @"intfm",
						[UIImage imageNamed:@"Macro.png"], @"macro",
						[UIImage imageNamed:@"Type.png"], @"tdef",
						[UIImage imageNamed:@"Class.png"], @"cat",
						[UIImage imageNamed:@"Property.png"], @"intfp",
						[UIImage imageNamed:@"Const.png"], @"clconst",
						[UIImage imageNamed:@"Protocol.png"], @"intf",
						[UIImage imageNamed:@"Member.png"], @"instm",
						[UIImage imageNamed:@"Class.png"], @"cl",
						[UIImage imageNamed:@"Struct.png"], @"tag",
						[UIImage imageNamed:@"Member.png"], @"clm",
						[UIImage imageNamed:@"Property.png"], @"instp",
						[UIImage imageNamed:@"Function.png"], @"func",
						[UIImage imageNamed:@"Global.png"], @"data",
						nil];
	
	self.clearsSelectionOnViewWillAppear = YES;
		
	return self;
}

- (void)loadView
{
	[super loadView];
	
	UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	searchBar.scopeButtonTitles = [NSArray arrayWithObjects:NSLocalizedString(@"API",nil), NSLocalizedString(@"Title",nil), nil];
	searchBar.selectedScopeButtonIndex = 0;
	searchBar.showsScopeBar = NO;
	self.tableView.tableHeaderView = searchBar;
	
	self.tableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
	
	self.searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
	searchDisplayController.delegate = self;
	searchDisplayController.searchResultsDataSource = self;
	searchDisplayController.searchResultsDelegate = self;
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(showBookmarks:)];
		self.navigationItem.rightBarButtonItem.style = UIBarButtonItemStylePlain;
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (!self.navigationController.toolbarHidden) {
		[self.navigationController setToolbarHidden:YES animated:animated];
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.searchDisplayController.searchBar resignFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Search

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
	[docSet prepareSearch];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
	self.searchResults = nil;
	[self reloadSearchResults];
	return YES;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)searchResultsTableView
{
	searchResultsTableView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didHideSearchResultsTableView:(UITableView *)tableView
{
	self.searchResults = nil;
	[self.searchDisplayController.searchResultsTableView reloadData];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
	if (searchString.length == 0) {
		self.searchResults = nil;
		return YES;
	} else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadSearchResults) object:nil];
		[self performSelector:@selector(reloadSearchResults) withObject:nil afterDelay:0.2];
		return (self.searchResults == nil);
	}
}

- (void)reloadSearchResults
{
	NSString *searchTerm = self.searchDisplayController.searchBar.text;
	DocSetSearchCompletionHandler completionHandler = ^(NSString *completedSearchTerm, NSArray *results) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString *currentSearchTerm = self.searchDisplayController.searchBar.text;
			if ([currentSearchTerm isEqualToString:completedSearchTerm]) {
				self.searchResults = results;
				[self.searchDisplayController.searchResultsTableView reloadData];
			}
		});
	};
	
	if (self.searchDisplayController.searchBar.selectedScopeButtonIndex == 0) {
		[docSet searchForTokensMatching:searchTerm completion:completionHandler];
	} else {
		[docSet searchForNodesMatching:searchTerm completion:completionHandler];
	}	
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView 
{
	if (aTableView == self.tableView) {
		return [nodeSections count];
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		return 1;
	}
	return 0;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	if (aTableView == self.tableView) {
		NSDictionary *nodeSection = [nodeSections objectAtIndex:section];
		return [nodeSection objectForKey:kNodeSectionTitle];
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section 
{
	if (aTableView == self.tableView) {
		return [[[nodeSections objectAtIndex:section] objectForKey:kNodeSectionNodes] count];
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		if (!self.searchResults) {
			return 1;
		} else {
			return [searchResults count];
		}
	}
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (aTableView == self.tableView) {
		static NSString *CellIdentifier = @"Cell";
		UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
		}
			
		NSDictionary *nodeSection = [nodeSections objectAtIndex:indexPath.section];
		NSManagedObject *node = [[nodeSection objectForKey:kNodeSectionNodes] objectAtIndex:indexPath.row];
		
		BOOL expandable = [docSet nodeIsExpandable:node];
		cell.accessoryType = (expandable) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
		
		if ([[node valueForKey:@"installDomain"] intValue] > 1) {
			//external link, e.g. man pages
			cell.textLabel.textColor = [UIColor grayColor];
		} else {
			cell.textLabel.textColor = [UIColor blackColor];
		}
		
		int documentType = [[node valueForKey:@"kDocumentType"] intValue];
		if (documentType == 1) {
			cell.imageView.image = [UIImage imageNamed:@"SampleCodeIcon.png"];
		} else if (documentType == 2) {
			cell.imageView.image = [UIImage imageNamed:@"ReferenceIcon.png"];
		} else if (!expandable) {
			cell.imageView.image = [UIImage imageNamed:@"BookIcon.png"];
		} else {
			cell.imageView.image = nil;
		}
		
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
		cell.textLabel.text = [node valueForKey:@"kName"];
		cell.detailTextLabel.text = nil;
		cell.accessoryView = nil;
		return cell;
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		static NSString *searchCellIdentifier = @"SearchResultCell";
		SearchResultCell *cell = (SearchResultCell *)[aTableView dequeueReusableCellWithIdentifier:searchCellIdentifier];
		if (cell == nil) {
			cell = [[SearchResultCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:searchCellIdentifier];
			cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
		}
		
		if (!self.searchResults) {
			cell.searchTerm = nil;
			cell.textLabel.text = NSLocalizedString(@"Searching...", nil);
			cell.textLabel.textColor = [UIColor grayColor];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.imageView.image = nil;
			UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			[spinner startAnimating];
			cell.accessoryView = spinner;
			cell.detailTextLabel.text = nil;
		} else {
			cell.searchTerm = self.searchDisplayController.searchBar.text;
			cell.textLabel.textColor = [UIColor blackColor];
			cell.selectionStyle = UITableViewCellSelectionStyleBlue;
			cell.accessoryView = nil;
			NSDictionary *result = [searchResults objectAtIndex:indexPath.row];
			
			if ([result objectForKey:@"tokenType"]) {
				NSManagedObject *metaInfo = [docSet.managedObjectContext existingObjectWithID:[result objectForKey:@"metainformation"] error:NULL];
				NSSet *deprecatedVersions = [metaInfo valueForKey:@"deprecatedInVersions"];
				cell.deprecated = ([deprecatedVersions count] > 0);
				
				NSManagedObjectID *tokenTypeID = [result objectForKey:@"tokenType"];
				if (tokenTypeID) {
					NSManagedObject *tokenType = [[docSet managedObjectContext] existingObjectWithID:tokenTypeID error:NULL];
					NSString *tokenTypeName = [tokenType valueForKey:@"typeName"];
					UIImage *icon = [iconsByTokenType objectForKey:tokenTypeName];
					cell.imageView.image = icon;
				} else {
					cell.imageView.image = nil;
				}
				
				NSManagedObjectID *parentNodeID = [result objectForKey:@"parentNode"];
				if (parentNodeID) {
					NSManagedObject *parentNode = [[docSet managedObjectContext] existingObjectWithID:parentNodeID error:NULL];
					NSString *parentNodeTitle = [parentNode valueForKey:@"kName"];
					cell.detailTextLabel.text = parentNodeTitle;
				} else {
					cell.detailTextLabel.text = nil;
				}
				
				cell.textLabel.text = [result objectForKey:@"tokenName"];
				cell.accessoryType = UITableViewCellAccessoryNone;
			} else {
				cell.deprecated = NO;
				cell.textLabel.text = [result objectForKey:@"kName"];
				NSManagedObjectID *objectID = [result objectForKey:@"objectID"];
				
				NSManagedObject *node = [[docSet managedObjectContext] existingObjectWithID:objectID error:NULL];
			
				BOOL expandable = [docSet nodeIsExpandable:node];
				cell.accessoryType = (expandable) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
			
				int documentType = [[node valueForKey:@"kDocumentType"] intValue];
				if (documentType == 1) {
					cell.imageView.image = [UIImage imageNamed:@"SampleCodeIcon.png"];
				} else if (documentType == 2) {
					cell.imageView.image = [UIImage imageNamed:@"ReferenceIcon.png"];
				} else if (!expandable) {
					cell.imageView.image = [UIImage imageNamed:@"BookIcon.png"];
				} else {
					cell.imageView.image = nil;
				}
				cell.detailTextLabel.text = nil;
			}
		}
		return cell;
	}
	return nil;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (aTableView == self.tableView) {
		NSDictionary *nodeSection = [nodeSections objectAtIndex:indexPath.section];
		NSManagedObject *node = [[nodeSection objectForKey:kNodeSectionNodes] objectAtIndex:indexPath.row];
		if ([[node valueForKey:@"installDomain"] intValue] > 1) {
			[aTableView deselectRowAtIndexPath:indexPath animated:YES];
			[self openNode:node];
		} else {
			[self openNode:node];
		}
	} else if (aTableView == self.searchDisplayController.searchResultsTableView) {
		[self.searchDisplayController.searchBar resignFirstResponder];
		NSDictionary *result = [searchResults objectAtIndex:indexPath.row];
		if ([result objectForKey:@"tokenType"]) {
			if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
				[self.detailViewController showToken:result inDocSet:docSet];
			} else {
				self.detailViewController = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
				[self.navigationController pushViewController:self.detailViewController animated:YES];
				[self.detailViewController showToken:result inDocSet:docSet];
			}
		} else {
			NSManagedObject *node = [[docSet managedObjectContext] existingObjectWithID:[result objectForKey:@"objectID"] error:NULL];
			if ([[node valueForKey:@"installDomain"] intValue] > 1) {
				[aTableView deselectRowAtIndexPath:indexPath animated:YES];
			} else {
				[self openNode:node];
			}
		}
	}
}

- (void)openNode:(NSManagedObject *)node
{
	BOOL expandable = [docSet nodeIsExpandable:node];
	if (expandable) {
		DocSetViewController *childViewController = [[DocSetViewController alloc] initWithDocSet:docSet rootNode:node];
		childViewController.detailViewController = self.detailViewController;
		[self.navigationController pushViewController:childViewController animated:YES];
	} else {
		if ([[node valueForKey:@"installDomain"] intValue] > 1) {
			NSURL *webURL = [docSet webURLForNode:node];
			if (webURL) {
				[[UIApplication sharedApplication] openURL:webURL];
			}
			return;
		}
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			[self.detailViewController showNode:node inDocSet:docSet];
		} else {
			self.detailViewController = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
			[self.navigationController pushViewController:self.detailViewController animated:YES];
			[self.detailViewController showNode:node inDocSet:docSet];
		}
	}
}

- (void)showBookmarks:(id)sender
{
	BookmarksViewController *vc = [[BookmarksViewController alloc] initWithDocSet:self.docSet];
	vc.delegate = self;
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
	navController.toolbarHidden = NO;
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)bookmarksViewController:(BookmarksViewController *)viewController didSelectBookmark:(NSDictionary *)bookmark
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
	DetailViewController *vc = [[DetailViewController alloc] initWithNibName:nil bundle:nil];
	vc.docSet = self.docSet;
	[self.navigationController pushViewController:vc animated:YES];
	[vc loadView];
	[vc bookmarksViewController:viewController didSelectBookmark:bookmark];
}

#pragma mark -

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end



@implementation SearchResultCell

@synthesize searchTerm, deprecated;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (self) {
		highlightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
		highlightView.backgroundColor = [UIColor colorWithRed:0.922 green:0.910 blue:0.745 alpha:1.0];
		UIView *underlineView = [[UIView alloc] initWithFrame:CGRectMake(0, 9, 10, 1)];
		underlineView.backgroundColor = [UIColor colorWithRed:0.929 green:0.792 blue:0.149 alpha:1.0];
		underlineView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
		[highlightView addSubview:underlineView];
		highlightView.hidden = YES;
		[self.contentView insertSubview:highlightView belowSubview:self.textLabel];
	}
	return self;
}

- (void)setDeprecated:(BOOL)deprecatedFlag
{
	deprecated = deprecatedFlag;
	if (deprecated) {
		if (!strikeThroughView) {
			strikeThroughView = [[UIView alloc] initWithFrame:CGRectZero];
			strikeThroughView.backgroundColor = [UIColor redColor];
			[self.contentView addSubview:strikeThroughView];
		}
	} else {
		if (strikeThroughView) {
			[strikeThroughView removeFromSuperview];
			strikeThroughView = nil;
		}
	}
}

- (void)layoutSubviews
{
	[super layoutSubviews];
	
	if (searchTerm.length > 0) {
		NSRange searchTermRange = [self.textLabel.text rangeOfString:searchTerm options:NSCaseInsensitiveSearch];
		if (searchTermRange.location != NSNotFound) {
			UIFont *font = self.textLabel.font;
			CGSize searchTermSize = [searchTerm sizeWithFont:font]; 
			NSString *prefix = [self.textLabel.text substringToIndex:searchTermRange.location];
			CGSize prefixSize = [prefix sizeWithFont:font];
			CGRect highlightRect = CGRectMake(self.textLabel.frame.origin.x + prefixSize.width, self.textLabel.frame.origin.y, searchTermSize.width, self.textLabel.frame.size.height);
			self.textLabel.backgroundColor = [UIColor clearColor];
			highlightView.frame = highlightRect;
			highlightView.hidden = NO;
		} else {
			highlightView.hidden = YES;
		}
	} else {
		highlightView.hidden = YES;
	}
	if (deprecated) {
		CGRect textLabelFrame = self.textLabel.frame;
		strikeThroughView.frame = CGRectMake(textLabelFrame.origin.x, CGRectGetMidY(textLabelFrame), textLabelFrame.size.width, 1);
	}
}

@end