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

@class GenericDocSet;

@interface BookmarksManager : NSObject

@property (strong) NSMutableDictionary *bookmarks;
@property (assign) BOOL iCloudEnabled;
@property (strong) NSMutableArray *syncLog;
@property (strong) NSDate *bookmarksModificationDate;
@property (strong) NSString *lastSavedDeviceName;

+ (id)sharedBookmarksManager;

- (NSMutableArray *)bookmarksForDocSet:(GenericDocSet *)docSet;
- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(GenericDocSet *)docSet;
- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(GenericDocSet *)docSet;
- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(GenericDocSet *)docSet;
- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(GenericDocSet *)docSet;
- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(GenericDocSet *)docSet toIndex:(NSInteger)toIndex;

- (NSData *)bookmarksDataForSharingSyncLog;

@end
