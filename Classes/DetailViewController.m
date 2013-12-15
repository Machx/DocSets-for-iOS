//
//  DetailViewController.m
//  DocSets
//
//  Created by Ole Zorn on 05.12.10.
//  Copyright 2010 omz:software. All rights reserved.
//

#import "DetailViewController.h"
#import "OutlineViewController.h"
#import "SwipeSplitViewController.h"
#import "GenericDocSet.h"
#import "BookmarksManager.h"
#import <GDataXML-HTML/GDataXMLNode.h>

#define EXTERNAL_LINK_ALERT_TAG	1

@interface DetailViewController () 

- (void)updateBackForwardButtons;
- (void)dismissOutline:(id)sender;

@end

@implementation DetailViewController

@synthesize docSet, currentURL;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nil bundle:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(docSetWillBeDeleted:) name:DocSetWillBeDeletedNotification object:nil];
	
	UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	outlineButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Outline.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showOutline:)];
	outlineButtonItem.width = 32.0;
	outlineButtonItem.enabled = NO;
	
	backButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Back.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
	backButtonItem.enabled = NO;
	forwardButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Forward.png"] style:UIBarButtonItemStylePlain target:self action:@selector(goForward:)];
	forwardButtonItem.enabled = NO;
	bookmarksButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(showBookmarks:)];
	bookmarksButtonItem.enabled = NO;
	actionButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showActions:)];
	actionButtonItem.enabled = NO;
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		UIBarButtonItem *browseButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"DocSets", nil) style:UIBarButtonItemStyleBordered target:self action:@selector(showLibrary:)];
		UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		spaceItem.width = 24.0;	
		portraitToolbarItems = [NSArray arrayWithObjects:browseButtonItem, spaceItem, backButtonItem, spaceItem, forwardButtonItem, flexSpace, bookmarksButtonItem, spaceItem, actionButtonItem, spaceItem, outlineButtonItem, nil];
		landscapeToolbarItems = [NSArray arrayWithObjects:backButtonItem, spaceItem, forwardButtonItem, flexSpace, bookmarksButtonItem, spaceItem, actionButtonItem, spaceItem, outlineButtonItem, nil];
	}
    
    // moved this because it was nil
    
    titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 360, 34)];
	titleLabel.textColor = [UIColor colorWithRed:0.443 green:0.471 blue:0.502 alpha:1.0];
	titleLabel.shadowColor = [UIColor whiteColor];
	titleLabel.shadowOffset = CGSizeMake(0, 1);
	titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
	titleLabel.textAlignment = UITextAlignmentCenter;
	titleLabel.backgroundColor = [UIColor clearColor];
	titleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	
	CGFloat topToolbarHeight = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 44.0 : 0.0;
	webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, topToolbarHeight, self.view.bounds.size.width, self.view.bounds.size.height - topToolbarHeight)];
	webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	webView.scalesPageToFit = YES;//([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
	
	webView.delegate = self;
	[self.view addSubview:webView];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, topToolbarHeight)];
		toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		toolbar.items = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? portraitToolbarItems : landscapeToolbarItems;
		[self.view addSubview:toolbar];
		titleLabel.center = CGPointMake(toolbar.bounds.size.width * 0.5, toolbar.bounds.size.height * 0.5);
		[toolbar addSubview:titleLabel];
	} else {
		UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
		UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		spaceItem.width = 24.0;
		self.toolbarItems = [NSArray arrayWithObjects:bookmarksButtonItem, flexSpace, backButtonItem, spaceItem, forwardButtonItem, flexSpace, actionButtonItem, nil];
		self.navigationItem.rightBarButtonItem = outlineButtonItem;
	}
	
	coverView = [[UIView alloc] initWithFrame:webView.frame];
	coverView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"whitey.png"]];
	coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:coverView];
		
	return self;
}

- (void)viewDidAppear:(BOOL)animated
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && self.navigationController.toolbarHidden) {
		[self.navigationController setToolbarHidden:NO animated:animated];
	}
}


- (void)loadView
{
	[super loadView];
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	
}

- (void)docSetWillBeDeleted:(NSNotification *)notification
{
	if (notification.object == self.docSet) {
		titleLabel.text = nil;
		coverView = [[UIView alloc] initWithFrame:webView.frame];
		coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		coverView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
		[self.view addSubview:coverView];
		outlineButtonItem.enabled = NO;
		actionButtonItem.enabled = NO;
		backButtonItem.enabled = NO;
		forwardButtonItem.enabled = NO;
		self.currentURL = nil;
	}
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	CGRect keyboardFrame = [self.view convertRect:[[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
	CGFloat keyboardHeight = keyboardFrame.size.height;
	float animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:animationCurve];
	[UIView setAnimationDuration:animationDuration];
	webView.frame = CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44 - keyboardHeight);
	[UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	float animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:animationCurve];
	[UIView setAnimationDuration:animationDuration];
	webView.frame = CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44);
	[UIView commitAnimations];
}

- (void)goBack:(id)sender
{
	[webView goBack];
	[self updateBackForwardButtons];
}

- (void)goForward:(id)sender
{
	[webView goForward];
	[self updateBackForwardButtons];
}

- (void)updateBackForwardButtons
{
	double delayInSeconds = 0.1;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		backButtonItem.enabled = [webView canGoBack];
		forwardButtonItem.enabled = [webView canGoForward];
	});
}

- (void)showOutline:(id)sender
{
	if (activeSheet.visible) [activeSheet dismissWithClickedButtonIndex:activeSheet.cancelButtonIndex animated:NO];
	if (bookmarksPopover.popoverVisible) [bookmarksPopover dismissPopoverAnimated:NO];
	
	NSString *currentURLString = [[webView stringByEvaluatingJavaScriptFromString:@"window.location.href"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *URL = [NSURL URLWithString:currentURLString];
	NSString *pathForBook = [self bookPathForURL:URL];
	
	if (!outlineViewController || ![bookPath isEqualToString:pathForBook]) {
		bookPath = pathForBook;
		book = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:pathForBook] options:0 error:NULL];
		OutlineViewController *outlineVC = [[OutlineViewController alloc] initWithItems:[book objectForKey:@"sections"] title:[book objectForKey:@"title"]];
		outlineVC.detailViewController = self;
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
			outlineVC.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissOutline:)];
		}
		UINavigationController *outlineNavController = [[UINavigationController alloc] initWithRootViewController:outlineVC];
		outlineViewController = outlineNavController;
	}
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		if (outlinePopover.popoverVisible) {
			[outlinePopover dismissPopoverAnimated:YES];
			return;
		}
		outlinePopover = [[UIPopoverController alloc] initWithContentViewController:outlineViewController];
		[outlinePopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	} else {
		[self presentModalViewController:outlineViewController animated:YES];
	}
}

- (void)dismissOutline:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)showActions:(id)sender
{
	if (activeSheet.visible) {
		[activeSheet dismissWithClickedButtonIndex:activeSheet.cancelButtonIndex animated:YES];
		return;
	}
	if (outlinePopover.popoverVisible) [outlinePopover dismissPopoverAnimated:NO];
	if (bookmarksPopover.popoverVisible) [bookmarksPopover dismissPopoverAnimated:NO];
	activeSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
								destructiveButtonTitle:nil
									 otherButtonTitles:NSLocalizedString(@"Add Bookmark", nil),
													   NSLocalizedString(@"Copy Link", nil), 
													   NSLocalizedString(@"Open in Safari", nil), nil];
	[activeSheet showFromBarButtonItem:sender animated:YES];
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex != actionSheet.cancelButtonIndex) {
		NSString *currentURLString = [webView stringByEvaluatingJavaScriptFromString:@"window.location.href"];
		currentURLString = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)currentURLString, CFSTR("#"), CFSTR(""), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
		NSURL *URL = [NSURL URLWithString:currentURLString];
		if (buttonIndex == 0) {
			NSString *bookmarkTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
			NSString *bookmarkURL = currentURLString;
			NSString *fragment = [URL fragment];
			NSString *subtitle = @"";
			if (fragment && fragment.length > 0) {
				NSString *js = [NSString stringWithFormat:@"var elements = document.getElementsByName('%@'); if (elements.length > 0) { elements[0].title; } else { ''; }", 
								fragment];
				NSString *fragmentTitle = [webView stringByEvaluatingJavaScriptFromString:js];
				subtitle = fragmentTitle;
			}
			if (bookmarkTitle && bookmarkURL) {
				BOOL bookmarkAdded = [[BookmarksManager sharedBookmarksManager] addBookmarkWithURL:bookmarkURL title:bookmarkTitle subtitle:subtitle forDocSet:self.docSet];
				if (!bookmarkAdded) {
					[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) 
												message:NSLocalizedString(@"Bookmarks are currently being synced. Please try again in a moment.", nil) 
											   delegate:nil 
									  cancelButtonTitle:NSLocalizedString(@"OK", nil) 
									  otherButtonTitles:nil] show];
				}
			}
		} else {
			NSURL *webURL = [self.docSet webURLForLocalURL:URL];
			if (buttonIndex == 1) {
				[[UIPasteboard generalPasteboard] setString:[webURL absoluteString]];
			} else if (buttonIndex == 2) {
				[[UIApplication sharedApplication] openURL:webURL];
			}
		}
	}
}

- (void)showBookmarks:(id)sender
{
	if (self.docSet) {
		if (bookmarksPopover.popoverVisible) {
			[bookmarksPopover dismissPopoverAnimated:YES];
			return;
		}
		if (outlinePopover.popoverVisible) [outlinePopover dismissPopoverAnimated:NO];
		if (activeSheet.visible) [activeSheet dismissWithClickedButtonIndex:activeSheet.cancelButtonIndex animated:NO];
		
		BookmarksViewController *vc = [[BookmarksViewController alloc] initWithDocSet:self.docSet];
		vc.delegate = self;
		UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:vc];
		navController.toolbarHidden = NO;
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			bookmarksPopover = [[UIPopoverController alloc] initWithContentViewController:navController];
			[bookmarksPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
		} else {
			[self presentModalViewController:navController animated:YES];
		}
	}
}

- (void)showLibrary:(id)sender
{
	if (outlinePopover.popoverVisible) [outlinePopover dismissPopoverAnimated:YES];
	if (activeSheet.visible) [activeSheet dismissWithClickedButtonIndex:activeSheet.cancelButtonIndex animated:YES];
	[(SwipeSplitViewController *)self.parentViewController showMasterViewControllerAnimated:YES];
}

- (void)setDocSet:(GenericDocSet *)aDocSet
{
	docSet = aDocSet;
	//bookmarksButtonItem.enabled = [[BookmarksManager sharedBookmarksManager] bookmarksAvailable];
	bookmarksButtonItem.enabled = YES;
}

#pragma mark -
#pragma mark Navigation

- (void)showNode:(NSManagedObject *)node inDocSet:(GenericDocSet *)set
{
	self.docSet = set;
	NSURL *URL = [self.docSet URLForNode:node];
    
	NSString *nodeAnchor = [self.docSet anchorForNode:node];
	if (nodeAnchor.length == 0) nodeAnchor = nil;
	
	//Handle soft redirects (they otherwise break the history):	
	NSString *html = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL];
	if (html) {
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<meta id=\"refresh\".*?URL=(.*?)\"" options:0 error:NULL];
		NSTextCheckingResult *result = [regex firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
		if (result.numberOfRanges > 1) {
			NSString *relativeRedirectPath = [html substringWithRange:[result rangeAtIndex:1]];
			URL = [NSURL URLWithString:relativeRedirectPath relativeToURL:URL];
		}
	}
    
	[self openURL:URL withAnchor:nodeAnchor];
}

- (void)showToken:(NSDictionary *)tokenInfo inDocSet:(GenericDocSet *)set
{
	self.docSet = set;
	
	NSManagedObjectID *parentNodeID = [tokenInfo objectForKey:@"parentNode"];
	if (parentNodeID) {
		NSManagedObject *node = [[self.docSet managedObjectContext] existingObjectWithID:parentNodeID error:NULL];
		NSURL *nodeURL = [self.docSet URLForNode:node];
		NSManagedObjectID *metainformationID = [tokenInfo objectForKey:@"metainformation"];
		if (metainformationID) {
			NSManagedObject *metadata = [[self.docSet managedObjectContext] existingObjectWithID:metainformationID error:NULL];
			NSString *filePath = [metadata valueForKeyPath:@"file.path"];
			NSString *a = [metadata valueForKey:@"anchor"];
			if (filePath) {
				NSString *absoluteFilePath = [[self.docSet.path stringByAppendingPathComponent:@"Contents/Resources/Documents"] stringByAppendingPathComponent:filePath];
				NSURL *fileURL = [NSURL fileURLWithPath:absoluteFilePath];
				[self openURL:fileURL withAnchor:a];
			} else {
				[self openURL:nodeURL withAnchor:a];
			}
		}
	}
}

- (void)showOutlineItem:(OutlineItem *)outlineItem
{
	if (self.docSet) {		
		NSString *outlineAnchor = outlineItem.aref;
		NSString *href = outlineItem.href;
		//strip the anchor from the URL:
		NSRange hashRange = [href rangeOfString:@"#"];
		if (hashRange.location != NSNotFound) href = [href substringToIndex:hashRange.location];
		NSURL *baseURL = [NSURL fileURLWithPath:[bookPath stringByDeletingLastPathComponent]];
		NSURL *itemURL = [baseURL URLByAppendingPathComponent:href];
		[self openURL:itemURL withAnchor:outlineAnchor];
		if (outlinePopover.popoverVisible) {
			[outlinePopover dismissPopoverAnimated:YES];
		}
		[self updateBackForwardButtons];
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
			[self dismissOutline:nil];
		}
	}
}

- (void)bookmarksViewController:(BookmarksViewController *)viewController didSelectBookmark:(NSDictionary *)bookmark
{
	NSURL *bookmarkURL = [[BookmarksManager sharedBookmarksManager] URLForBookmark:bookmark inDocSet:self.docSet];
	[self openURL:bookmarkURL withAnchor:nil];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		[bookmarksPopover dismissPopoverAnimated:YES];
	} else {
		[self dismissModalViewControllerAnimated:YES];
	}
}

- (void)openURL:(NSURL *)URL withAnchor:(NSString *)anchor
{
	if (anchor != nil) {
		NSURL *URLWithAnchor = [NSURL URLWithString:[[URL absoluteString] stringByAppendingFormat:@"#%@", anchor]];
		[webView loadRequest:[NSURLRequest requestWithURL:URLWithAnchor]];
	} else {
		[webView loadRequest:[NSURLRequest requestWithURL:URL]];
	}
    
	[self updateBackForwardButtons];
	if ([self.parentViewController isKindOfClass:[SwipeSplitViewController class]]) {
		[(SwipeSplitViewController *)self.parentViewController hideMasterViewControllerAnimated:YES];
	}
}

#pragma mark -

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation)) {
		[toolbar setItems:portraitToolbarItems animated:YES];
	} else {
		[toolbar setItems:landscapeToolbarItems animated:YES];
	}
}

- (BOOL)webView:(UIWebView *)aWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *URL = [request URL];
	[self updateBackForwardButtons];
	if ([[URL scheme] isEqualToString:@"file"]) {
		
    
		NSString *html = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:NULL];
        
		if ([[URL path] rangeOfString:@"__cached__"].location == NSNotFound) {
            
            NSString *customCSS;
            
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                customCSS = docSet.ipadCSS;
            } else {
                customCSS = docSet.iphoneCSS;
            }
            
            GDataXMLDocument *parser = [[GDataXMLDocument alloc] initWithHTMLString:html encoding:NSUTF8StringEncoding error:NULL];
            
            GDataXMLNode *article = [parser firstNodeForXPath:docSet.contentPath error:NULL];
            GDataXMLElement *complete = [[GDataXMLElement alloc] initWithHTMLString:@"<html></html>" error:NULL];
            GDataXMLElement *meta = [[GDataXMLElement alloc] initWithHTMLString:@"<meta name=\"viewport\" user-scalable=\"0\" content=\"width = device-width, initial-scale=1.0\"/> <meta charset=\"utf-8\">" error:NULL];
            
            GDataXMLElement *css = [[GDataXMLElement alloc] initWithHTMLString:customCSS error:NULL];
            [complete addChild:meta];
            [complete addChild:css];
            [complete addChild:article];
            
            html = complete.XMLString;
        
            NSInteger anchorLocation = [[URL absoluteString] rangeOfString:@"#"].location;
            NSString *URLAnchor = (anchorLocation != NSNotFound) ? [[URL absoluteString] substringFromIndex:anchorLocation] : nil;
            NSString *path = [URL path];
            NSString *cachePath = [[path stringByDeletingPathExtension] stringByAppendingString:@"__cached__.html"];
            NSURL *cacheURL = [NSURL fileURLWithPath:cachePath];
            
            if (URLAnchor) {
                NSString *cacheURLString = [[cacheURL absoluteString] stringByAppendingFormat:@"%@", URLAnchor];
                cacheURL = [NSURL URLWithString:cacheURLString];
            }
            
            [html writeToURL:cacheURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            [webView loadRequest:[NSURLRequest requestWithURL:cacheURL]];
            return NO;
            
		}
		return YES;
        
	} else if ([[URL scheme] hasPrefix:@"http"]) { //http or https
		selectedExternalLinkURL = URL;
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Open Safari", nil)
														 message:NSLocalizedString(@"This is an external link. Do you want to open it in Safari?", nil) 
														delegate:self 
											   cancelButtonTitle:NSLocalizedString(@"Cancel", nil) 
											   otherButtonTitles:NSLocalizedString(@"Open Safari", nil), nil];
		alert.tag = EXTERNAL_LINK_ALERT_TAG;
		[alert show];
		return NO;
	}
    
	outlineButtonItem.enabled = NO;
	return YES;
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == EXTERNAL_LINK_ALERT_TAG && buttonIndex != alertView.cancelButtonIndex) {
		[[UIApplication sharedApplication] openURL:selectedExternalLinkURL];
	}
}

- (void)webView:(UIWebView *)aWebView didFailLoadWithError:(NSError *)error
{
	if ([error code] != -999) {
		//-999 is the code for "operation could not be completed", which would occur when a new page is requested before the current one has finished loading
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
														 message:[NSString stringWithFormat:@"The page could not be loaded (%@).", [error localizedDescription]]
														delegate:nil 
											   cancelButtonTitle:NSLocalizedString(@"OK",nil) 
											   otherButtonTitles:nil];
		[alert show];
	}
	[self updateBackForwardButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
	if (coverView) {
		[coverView removeFromSuperview];
		coverView = nil;
	}
	titleLabel.text = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	actionButtonItem.enabled = YES;
	[self updateBackForwardButtons];
	
	NSString *currentURLString = [webView stringByEvaluatingJavaScriptFromString:@"window.location.href"];
	currentURLString = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)currentURLString, CFSTR("#"), CFSTR(""), CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	self.currentURL = [NSURL URLWithString:currentURLString];
	outlineButtonItem.enabled = ([self bookPathForURL:self.currentURL] != nil);
}

- (NSString *)bookPathForURL:(NSURL *)URL
{
	//TODO: This should probably also be a method of GenericDocSet...
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = [URL path];
	NSString *pathForBook = nil;
	while (path && ![path isEqual:@"/"]) {		
		NSString *possibleBookPath = [path stringByAppendingPathComponent:@"book.json"];
		BOOL bookExists = [fm fileExistsAtPath:possibleBookPath];
		if (bookExists) {
			pathForBook = possibleBookPath;
			break;
		}
		path = [path stringByDeletingLastPathComponent];
	}
	return pathForBook;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait;
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
