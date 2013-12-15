//
//  BookmarksViewController.h
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@class GenericDocSet, DetailViewController, BookmarksViewController;

@protocol BookmarksViewControllerDelegate <NSObject>

- (void)bookmarksViewController:(BookmarksViewController *)viewController didSelectBookmark:(NSDictionary *)bookmark;

@end

@interface BookmarksViewController : UITableViewController <MFMailComposeViewControllerDelegate, UIAlertViewDelegate> {

	GenericDocSet *docSet;
	__weak id <BookmarksViewControllerDelegate> delegate;
}

@property (nonatomic, weak) id <BookmarksViewControllerDelegate> delegate;
@property (nonatomic, retain) UIBarButtonItem *syncInfoButtonItem;

- (id)initWithDocSet:(GenericDocSet *)selectedDocSet;

@end
