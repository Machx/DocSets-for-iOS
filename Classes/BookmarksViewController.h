//
//  BookmarksViewController.h
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@class DocSet, DetailViewController, BookmarksViewController;

@protocol BookmarksViewControllerDelegate <NSObject>

- (void)bookmarksViewController:(BookmarksViewController *)viewController didSelectBookmark:(NSDictionary *)bookmark;

@end

@interface BookmarksViewController : UITableViewController <MFMailComposeViewControllerDelegate, UIAlertViewDelegate> {

	DocSet *docSet;
	__weak id <BookmarksViewControllerDelegate> delegate;
}

@property (nonatomic, weak) id <BookmarksViewControllerDelegate> delegate;
@property (nonatomic, retain) UIBarButtonItem *syncInfoButtonItem;

- (id)initWithDocSet:(DocSet *)selectedDocSet;

@end
