//
//  BookmarksManager2.h
//  DocSets
//
//  Created by Ole Zorn on 22.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

#define BookmarksManagerDidLoadBookmarksNotification	@"BookmarksManagerDidLoadBookmarksNotification"
#define BookmarksManagerDidLogSyncEventNotification		@"BookmarksManagerDidLogSyncEventNotification"

#define kBookmarkSyncLogTitle	@"title"
#define kBookmarkSyncLogLevel	@"level"
#define kBookmarkSyncLogDate	@"date"

@class DocSet;

@interface BookmarksManager : NSObject

@property (strong) NSMutableDictionary *bookmarks;
@property (assign) BOOL iCloudEnabled;
@property (strong) NSMutableArray *syncLog;
@property (strong) NSDate *bookmarksModificationDate;
@property (strong) NSString *lastSavedDeviceName;

+ (id)sharedBookmarksManager;

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet;
- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet;
- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet;
- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex;

- (NSData *)bookmarksDataForSharingSyncLog;

@end
