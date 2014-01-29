//
//  BookmarksManager2.m
//  DocSets
//
//  Created by Ole Zorn on 22.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarksManager.h"
#import "DocSet.h"
#import "NSString+RelativePath.h"

@interface BookmarksManager ()

@property (nonatomic, strong) NSMetadataQuery *query;
@property (assign) BOOL movingToUbiquityContainer;

- (void)log:(NSString *)message withLevel:(int)level;
- (void)postChangeNotification;
- (void)resolveConflictAtURL:(NSURL *)fileURL;
- (NSData *)dataFromBookmarks:(NSMutableDictionary *)bookmarksDict error:(NSError *__autoreleasing *)outError;
- (NSMutableDictionary *)bookmarksFromData:(NSData *)bookmarksData;
- (NSString *)relativeBookmarkPathWithBookmarkURL:(NSString *)bookmarkURL inDocSetWithPath:(NSString *)docSetPath;
- (NSURL *)localBookmarksURL;
- (NSMutableDictionary *)legacyBookmarks;
- (void)removeLegacyBookmarks;
- (BOOL)migrateLocalBookmarksAndSave:(BOOL)save;
- (BOOL)removeLocalBookmarks;

@end

@implementation BookmarksManager

@synthesize query=_query, bookmarks=_bookmarks, bookmarksModificationDate=_bookmarksModificationDate, movingToUbiquityContainer=_movingToUbiquityContainer, iCloudEnabled=_iCloudEnabled;
@synthesize syncLog=_syncLog, lastSavedDeviceName=_lastSavedDeviceName;

- (id)init
{
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidUpdateNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		
		_syncLog = [NSMutableArray new];
		
		[self checkForICloudAvailability];
	}
	return self;
}

+ (id)sharedBookmarksManager
{
	static id sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

- (void)log:(NSString *)message withLevel:(int)level
{
	dispatch_async(dispatch_get_main_queue(), ^{
		//NSLog(@"%@", message);
		NSDictionary *logEntry = [NSDictionary dictionaryWithObjectsAndKeys:
								  message, kBookmarkSyncLogTitle, 
								  [NSNumber numberWithInt:level], kBookmarkSyncLogLevel, 
								  [NSDate date], kBookmarkSyncLogDate,
								  nil];
		[self.syncLog addObject:logEntry];
		if (self.syncLog.count > 100) {
			[self.syncLog removeObjectAtIndex:0];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:BookmarksManagerDidLogSyncEventNotification object:self];
	});
}

- (void)checkForICloudAvailability
{
	BOOL iCloudWasEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"iCloudEnabled"];
	self.iCloudEnabled = ([[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil] != nil);
	if (self.iCloudEnabled != iCloudWasEnabled) {
		[[NSUserDefaults standardUserDefaults] setBool:self.iCloudEnabled forKey:@"iCloudEnabled"];
		if (self.iCloudEnabled) {
			[self log:@"iCloud became available." withLevel:0];
		} else {
			[self log:@"iCloud became unavailable." withLevel:2];
		}	
		if (self.iCloudEnabled) {
			self.bookmarksModificationDate = nil;
			self.bookmarks = nil;
		}
		[self postChangeNotification];
	}
	
	if (self.iCloudEnabled) {
		[self startICloudQuery];
	} else {
		self.query = nil;
		[self log:@"Loading local bookmarks." withLevel:0];
		NSURL *localBookmarksURL = [self localBookmarksURL];
		NSData *bookmarksData = [NSData dataWithContentsOfURL:localBookmarksURL];
		if (bookmarksData) {
			self.bookmarks = [self bookmarksFromData:bookmarksData];
		} else {
			self.bookmarks = [NSMutableDictionary dictionary];
		}
	}
}

- (void)startICloudQuery
{
	if (!self.query) {
		[self log:@"Searching for bookmarks in iCloud..." withLevel:1];
		self.query = [[NSMetadataQuery alloc] init];
		[_query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDataScope, nil]];
		[_query setPredicate:[NSPredicate predicateWithFormat:@"%K == 'Bookmarks.plist'", NSMetadataItemFSNameKey]];
		[_query startQuery];
	}
}

- (void)iCloudFileListReceived:(NSNotification *)notification
{
	[self.query disableUpdates];
	
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSURL *localDocumentsURL = [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
	
	NSArray *queryResults = [self.query results];
	if (queryResults.count == 0) {
		if (!self.movingToUbiquityContainer) {
			self.movingToUbiquityContainer = YES;
			
			NSMutableDictionary *legacyBookmarks = [self legacyBookmarks];
			if (legacyBookmarks.count > 0) {
				[self log:@"Migrating old bookmarks..." withLevel:1];
				self.bookmarks = legacyBookmarks;
				[self removeLegacyBookmarks];
			} else {
				[self log:@"Initializing bookmarks..." withLevel:1];
				self.bookmarks = [NSMutableDictionary dictionary];
			}
			
			[self log:@"Moving bookmarks to iCloud..." withLevel:1];
			
			NSURL *tempBookmarksURL = [localDocumentsURL URLByAppendingPathComponent:@"TempBookmarks.plist"];
			
			BOOL localBookmarksMigrated = [self migrateLocalBookmarksAndSave:NO];
			if (localBookmarksMigrated) {
				[self log:@"Migrating local bookmarks." withLevel:0];
			}
			
			NSData *bookmarksData = [self dataFromBookmarks:self.bookmarks error:NULL];
			[bookmarksData writeToURL:tempBookmarksURL atomically:YES];
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSURL *ubiquityContainerURL = [fm URLForUbiquityContainerIdentifier:nil];
				NSError *setUbiquitousError = nil;
				NSURL *destinationURL = [ubiquityContainerURL URLByAppendingPathComponent:@"Bookmarks.plist"];
				BOOL success = [fm setUbiquitous:YES itemAtURL:tempBookmarksURL destinationURL:destinationURL error:&setUbiquitousError];
				if (!success) {
					[self log:[NSString stringWithFormat:@"Could not move bookmarks to iCloud container (%@).", setUbiquitousError] withLevel:2];
					[fm removeItemAtURL:tempBookmarksURL error:NULL];
				} else {
					[self log:@"Bookmarks successfully moved to iCloud." withLevel:0];
					[self removeLocalBookmarks];
				}
				self.movingToUbiquityContainer = NO;
			});
		}
	} else {
		NSMetadataItem *metadataItem = [queryResults objectAtIndex:0];
		NSDate *modificationDate = [metadataItem valueForAttribute:NSMetadataItemFSContentChangeDateKey];
		NSURL *fileURL = [metadataItem valueForAttribute:NSMetadataItemURLKey];
		
		NSArray *conflictVersions = [NSFileVersion otherVersionsOfItemAtURL:fileURL];
		if (conflictVersions.count > 0) {
			[self resolveConflictAtURL:fileURL];
		} else {
			if (![modificationDate isEqual:self.bookmarksModificationDate]) {
				[self log:@"Loading bookmarks..." withLevel:1];
				self.bookmarksModificationDate = modificationDate;
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
					NSError *coordinatorError = nil;
					[coordinator coordinateReadingItemAtURL:fileURL options:0 error:&coordinatorError byAccessor:^(NSURL *newURL) {
						NSData *bookmarksData = [NSData dataWithContentsOfURL:newURL];
						if (bookmarksData) {
							NSMutableDictionary *loadedBookmarks = [self bookmarksFromData:bookmarksData];
							if (loadedBookmarks) {
								self.bookmarks = loadedBookmarks;
								NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:fileURL];
								self.lastSavedDeviceName = [currentVersion localizedNameOfSavingComputer];
								[self postChangeNotification];
								[self log:[NSString stringWithFormat:@"Bookmarks loaded (from %@).", self.lastSavedDeviceName] withLevel:0];
								dispatch_async(dispatch_get_main_queue(), ^{
									[self migrateLocalBookmarksAndSave:YES];
									[self removeLocalBookmarks];
								});
							}
						}
					}];
					if (coordinatorError) {
						[self log:[NSString stringWithFormat:@"Could not load bookmarks from iCloud (%@).", [coordinatorError localizedDescription]] withLevel:2];
						self.bookmarksModificationDate = nil;
					}
				});
			}
		}
	}
	[self.query enableUpdates];
}

- (NSData *)dataFromBookmarks:(NSMutableDictionary *)bookmarksDict error:(NSError *__autoreleasing *)outError
{
	return [NSPropertyListSerialization dataWithPropertyList:bookmarksDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:outError];
}

- (NSMutableDictionary *)bookmarksFromData:(NSData *)bookmarksData
{
	NSMutableDictionary *loadedBookmarks = [NSPropertyListSerialization propertyListWithData:bookmarksData options:NSPropertyListMutableContainers format:NULL error:NULL];
	return loadedBookmarks;
}

- (NSData *)bookmarksDataForSharingSyncLog
{
	if (self.bookmarks) {
		return [self dataFromBookmarks:self.bookmarks error:NULL];
	}
	return nil;
}

- (NSMutableDictionary *)mergedBookmarksFromVersions:(NSArray *)bookmarksVersions
{
	//Merge multiple versions of the bookmarks by forming a union of all bookmarks in all versions.
	//NOTE: This will cause bookmarks that were deleted in just one version to re-appear, 
	//      but this is better than having added bookmarks disappear.
	
	NSMutableDictionary *mergedBookmarks = [NSMutableDictionary dictionary];
	
	NSMutableSet *allDocSetBundleIDs = [NSMutableSet set];
	for (NSMutableDictionary *bookmarksVersion in bookmarksVersions) {
		[allDocSetBundleIDs addObjectsFromArray:[bookmarksVersion allKeys]];
	}
	for (NSString *bundleID in allDocSetBundleIDs) {
		NSMutableSet *allBookmarkPaths = [NSMutableSet set];
		NSMutableArray *mergedBookmarksForBundleID = [NSMutableArray array];
		for (NSMutableDictionary *bookmarksVersion in bookmarksVersions) {
			NSMutableArray *bookmarksForBundleID = [bookmarksVersion objectForKey:bundleID];
			for (NSDictionary *bookmark in [bookmarksForBundleID reverseObjectEnumerator]) {
				NSString *bookmarkPath = [bookmark objectForKey:@"path"];
				if (![allBookmarkPaths containsObject:bookmarkPath]) {
					[allBookmarkPaths addObject:bookmarkPath];
					[mergedBookmarksForBundleID insertObject:bookmark atIndex:0];
				}
			}
		}
		[mergedBookmarks setObject:mergedBookmarksForBundleID forKey:bundleID];
	}
	return mergedBookmarks;
}

- (void)resolveConflictAtURL:(NSURL *)fileURL
{
	NSArray *conflictVersions = [NSFileVersion otherVersionsOfItemAtURL:fileURL];
	[self log:[NSString stringWithFormat:@"Merging %i conflicting versions...", conflictVersions.count + 1] withLevel:1];
	NSMutableArray *allVersions = [NSMutableArray arrayWithArray:conflictVersions];
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:fileURL];
	if (currentVersion) {
		[allVersions insertObject:currentVersion atIndex:0];
	}
	
	//Read the bookmarks dictionary from all versions:
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableArray *bookmarksVersions = [NSMutableArray array];
		for (NSFileVersion *conflictVersion in allVersions) {
			NSURL *versionURL = conflictVersion.URL;
			if (versionURL) {
				NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
				[coordinator coordinateReadingItemAtURL:versionURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
					NSData *data = [NSData dataWithContentsOfURL:versionURL];
					if (data) {
						NSMutableDictionary *bookmarks = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainers format:NULL error:NULL];
						if (bookmarks) {
							[bookmarksVersions addObject:bookmarks];
						}
					}
				}];
			}
		}
		
		//Merge all the versions into one dictionary:
		NSMutableDictionary *mergedBookmarks = [self mergedBookmarksFromVersions:bookmarksVersions];
		
		//Write the dictionary to the document's file URL:
		NSFileCoordinator *writeCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[writeCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForReplacing error:NULL byAccessor:^(NSURL *newURL) {
			NSData *mergedBookmarksData = [self dataFromBookmarks:mergedBookmarks error:NULL];
			if (mergedBookmarksData) {
				[mergedBookmarksData writeToURL:newURL atomically:YES];
			}
		}];
		
		//Remove the conflict versions and mark all conflicts as resolved:
		[NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:NULL];
		NSArray *remainingConflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
		for (NSFileVersion* fileVersion in remainingConflictVersions) {
			fileVersion.resolved = YES;
		}
		self.bookmarks = mergedBookmarks;
		
		//Finished resolving conflict.
		[self postChangeNotification];
		[self log:@"Conflict resolved." withLevel:0];
	});
}

- (void)saveBookmarks
{
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSData *bookmarksData = [self dataFromBookmarks:self.bookmarks error:NULL];
	if (self.iCloudEnabled) {
		[self log:@"Saving bookmarks..." withLevel:1];
		NSURL *ubiquityContainerURL = [fm URLForUbiquityContainerIdentifier:nil];
		NSURL *destinationURL = [ubiquityContainerURL URLByAppendingPathComponent:@"Bookmarks.plist"];
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
			NSError *coordinatorError = nil;
			[coordinator coordinateWritingItemAtURL:destinationURL options:0 error:&coordinatorError byAccessor:^(NSURL *newURL) {
				[bookmarksData writeToURL:newURL atomically:YES];
				NSDate *modificationDate = nil;
				[destinationURL getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:NULL];
				if (modificationDate) {
					self.bookmarksModificationDate = modificationDate;
				}
			}];
			if (coordinatorError) {
				[self log:[NSString stringWithFormat:@"Could not save bookmarks to iCloud (%@).", [coordinatorError localizedDescription]] withLevel:2];
			} else {
				[self log:@"Bookmarks saved." withLevel:0];
			}
		});
	} else {
		NSURL *localBookmarksURL = [self localBookmarksURL];
		[bookmarksData writeToURL:localBookmarksURL atomically:YES];
	}
}

- (NSURL *)localBookmarksURL
{
	NSFileManager *fm = [NSFileManager new];
	NSURL *localDocumentsURL = [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
	NSURL *localBookmarksURL = [localDocumentsURL URLByAppendingPathComponent:@"Bookmarks.plist"];
	return localBookmarksURL;
}

- (void)postChangeNotification
{
	//Ensure that notifications for the UI are delivered on the main thread:
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:BookmarksManagerDidLoadBookmarksNotification object:self];
	});
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	[self checkForICloudAvailability];
	[self.query enableUpdates];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	[self.query disableUpdates];
}

#pragma mark -

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return nil;
	NSMutableArray *bookmarksForDocSet = [self.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
	}
	return bookmarksForDocSet;
}

- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return NO;
	
	NSString *relativePath = [self relativeBookmarkPathWithBookmarkURL:bookmarkURL inDocSetWithPath:docSet.path];
	
	NSMutableArray *bookmarksForDocSet = [self.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
	}
	NSInteger existingBookmarkIndex = NSNotFound;
	NSInteger i = 0;
	for (NSDictionary *existingBookmark in bookmarksForDocSet) {
		if ([[existingBookmark objectForKey:@"path"] isEqualToString:relativePath]) {
			existingBookmarkIndex = i;
			break;
		}
		i++;
	}
	if (existingBookmarkIndex != NSNotFound) {
		[self moveBookmarkAtIndex:existingBookmarkIndex inDocSet:docSet toIndex:0];
	} else {
		NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:relativePath, @"path", bookmarkTitle, @"title", subtitle, @"subtitle", nil];
		[bookmarksForDocSet insertObject:bookmark atIndex:0];
		[self saveBookmarks];
	}
	return YES;
}

- (NSString *)relativeBookmarkPathWithBookmarkURL:(NSString *)bookmarkURL inDocSetWithPath:(NSString *)docSetPath
{
	NSString *fragment = [[NSURL URLWithString:bookmarkURL] fragment];
	if (!fragment) fragment = @"";
	NSString *bookmarkPath = [[NSURL URLWithString:bookmarkURL] path];
	NSString *relativePath = [bookmarkPath relativePathFromBaseDirPath:docSetPath];
	if (fragment.length > 0) {
		relativePath = [relativePath stringByAppendingFormat:@"#%@", fragment];
	}
	return relativePath;
}

- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet
{
	NSString *relativeBookmarkPath = [bookmark objectForKey:@"path"];
	NSString *docSetPath = docSet.path;
	NSString *bookmarkURLString = [[[NSURL fileURLWithPath:docSetPath] absoluteString] stringByAppendingString:relativeBookmarkPath];
	if ([bookmarkURLString rangeOfString:@"__cached__"].location != NSNotFound) {
		bookmarkURLString = [bookmarkURLString stringByReplacingOccurrencesOfString:@"__cached__" withString:@""];
	}
	NSURL *bookmarkURL = [NSURL URLWithString:bookmarkURLString];
	return bookmarkURL;
}

- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet
{
	NSURL *localBookmarkURL = [self URLForBookmark:bookmark inDocSet:docSet];
	return [docSet webURLForLocalURL:localBookmarkURL];
}

- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return NO;
	NSMutableArray *bookmarks = [self bookmarksForDocSet:docSet];
	[bookmarks removeObjectAtIndex:bookmarkIndex];
	[self saveBookmarks];
	return YES;
}

- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex
{
	if (!self.bookmarks) return NO;
	
	NSMutableArray *bookmarks = [self.bookmarks objectForKey:docSet.bundleID];
	NSDictionary *movedBookmark = [bookmarks objectAtIndex:fromIndex];
	[bookmarks removeObjectAtIndex:fromIndex];
	if (toIndex >= [bookmarks count]) {
		[bookmarks addObject:movedBookmark];
	} else {
		[bookmarks insertObject:movedBookmark atIndex:toIndex];
	}
	[self saveBookmarks];
	return YES;
}

#pragma mark -

- (BOOL)migrateLocalBookmarksAndSave:(BOOL)save
{
	NSURL *localBookmarksURL = [self localBookmarksURL];
	NSData *localBookmarksData = [NSData dataWithContentsOfURL:localBookmarksURL];
	if (localBookmarksData) {
		NSMutableDictionary *localBookmarks = [self bookmarksFromData:localBookmarksData];
		if (localBookmarks.count > 0) {
			[self log:@"Migrating local bookmarks." withLevel:0];
			self.bookmarks = [self mergedBookmarksFromVersions:[NSArray arrayWithObjects:localBookmarks, self.bookmarks, nil]];
			[self postChangeNotification];
			if (save) {
				[self saveBookmarks];
			}
			return YES;
		}
	}
	return NO;
}

- (BOOL)removeLocalBookmarks
{
	NSFileManager *fm = [NSFileManager new];
	NSURL *localBookmarksURL = [self localBookmarksURL];
	BOOL localBookmarksRemoved = [fm removeItemAtURL:localBookmarksURL error:NULL];
	if (localBookmarksRemoved) {
		[self log:@"Removed local bookmarks." withLevel:0];
		return YES;
	}
	return NO;
}

#pragma mark - Legacy Bookmark Migration

- (NSMutableDictionary *)legacyBookmarks
{
	NSMutableDictionary *allLegacyBookmarks = [NSMutableDictionary dictionary];
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docPath error:NULL];
	for (NSString *item in items) {
		if ([[item pathExtension] isEqualToString:@"docset"]) {
			NSString *docSetPath = [docPath stringByAppendingPathComponent:item];
			NSString *legacyBookmarksPath = [docSetPath stringByAppendingPathComponent:@"Bookmarks.plist"];
			NSString *infoPlistPath = [docSetPath stringByAppendingPathComponent:@"Contents/Info.plist"];
			NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
			NSString *docSetBundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];
			NSArray *legacyBookmarksForDocSet = [NSArray arrayWithContentsOfFile:legacyBookmarksPath];
			NSMutableArray *bookmarksForDocSet = [NSMutableArray array];
			if (legacyBookmarksForDocSet && docSetBundleID) {
				for (NSDictionary *legacyBookmark in legacyBookmarksForDocSet) {
					NSString *legacyBookmarkURL = [legacyBookmark objectForKey:@"URL"];
					NSString *legacyBookmarkTitle = [legacyBookmark objectForKey:@"title"];
					NSString *bookmarkPath = [self relativeBookmarkPathWithBookmarkURL:legacyBookmarkURL inDocSetWithPath:docSetPath];
					NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
											  legacyBookmarkTitle, @"title", 
											  @"", @"subtitle",
											  bookmarkPath, @"path", nil];
					[bookmarksForDocSet addObject:bookmark];
				}
			}
			if (bookmarksForDocSet.count > 0) {
				[allLegacyBookmarks setObject:bookmarksForDocSet forKey:docSetBundleID];
			}
		}
	}
	return allLegacyBookmarks;
}

- (void)removeLegacyBookmarks
{
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docPath error:NULL];
	NSFileManager *fm = [NSFileManager new];
	for (NSString *item in items) {
		if ([[item pathExtension] isEqualToString:@"docset"]) {
			NSString *docSetPath = [docPath stringByAppendingPathComponent:item];
			NSString *legacyBookmarksPath = [docSetPath stringByAppendingPathComponent:@"Bookmarks.plist"];
			[fm removeItemAtPath:legacyBookmarksPath error:NULL];
		}
	}
}


@end
