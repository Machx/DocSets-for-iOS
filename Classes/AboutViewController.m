//
//  AboutViewController.m
//  DocSets
//
//  Created by Ole Zorn on 11.03.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "AboutViewController.h"

@implementation AboutViewController

@synthesize webView=_webView;

- (void)loadView
{
    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.title = NSLocalizedString(@"About DocSets", nil);
	self.webView = [[UIWebView alloc] initWithFrame:contentView.bounds];
	self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.webView.delegate = self;
	self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
	[contentView addSubview:self.webView];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    
    self.view = contentView;
}

- (void)done:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	NSURL *aboutPageURL = [[NSBundle mainBundle] URLForResource:@"About" withExtension:@"html"];
	[self.webView loadRequest:[NSURLRequest requestWithURL:aboutPageURL]];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:request.URL];
		return NO;
	}
	return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc
{
	_webView.delegate = nil;
}

@end
