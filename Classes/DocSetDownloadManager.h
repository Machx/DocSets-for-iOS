//
//  DocSetDownloadManager.h
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DocSetDownloadManagerAvailableDocSetsChangedNotification	@"DocSetDownloadManagerAvailableDocSetsChangedNotification"
#define DocSetDownloadManagerStartedDownloadNotification			@"DocSetDownloadManagerStartedDownloadNotification"
#define DocSetDownloadManagerUpdatedDocSetsNotification				@"DocSetDownloadManagerUpdatedDocSetsNotification"
#define DocSetDownloadManagerIdleTimerToggledNotification           @"DocSetDownloadManagerIdleTimerToggledNotification"
#define DocSetDownloadFinishedNotification							@"DocSetDownloadFinishedNotification"

@class GenericDocSet, DocSetDownload;

@interface DocSetDownloadManager : NSObject {

	NSArray *_downloadedDocSets;
	NSSet *_downloadedDocSetNames;
	
	NSArray *_availableDownloads;
	NSMutableDictionary *_downloadsByURL;
	DocSetDownload *_currentDownload;
	NSMutableArray *_downloadQueue;
	
	NSDate *_lastUpdated;
	BOOL _updatingAvailableDocSetsFromWeb;
    
    BOOL _neverDisableIdleTimer;
}

@property (nonatomic, strong) NSArray *downloadedDocSets;
@property (nonatomic, strong) NSSet *downloadedDocSetNames;
@property (nonatomic, strong) NSArray *availableDownloads;
@property (nonatomic, strong) DocSetDownload *currentDownload;
@property (nonatomic, strong) NSDate *lastUpdated;
@property (nonatomic, assign) BOOL neverDisableIdleTimer;

+ (id)sharedDownloadManager;
- (void)reloadAvailableDocSets;
- (void)updateAvailableDocSetsFromWeb;
- (void)downloadDocSetAtURL:(NSString *)URL;
- (void)downloadDocSetFromAtom:(NSURL *)URL;
- (void)deleteDocSet:(GenericDocSet *)docSetToDelete;
- (DocSetDownload *)downloadForURL:(NSString *)URL;
- (void)stopDownload:(DocSetDownload *)download;
- (GenericDocSet *)downloadedDocSetWithName:(NSString *)docSetName;

@end

typedef enum DocSetDownloadStatus {
	DocSetDownloadStatusWaiting = 0,
	DocSetDownloadStatusDownloading,
	DocSetDownloadStatusExtracting,
	DocSetDownloadStatusFinished
} DocSetDownloadStatus;


@interface DocSetDownload : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {

	UIBackgroundTaskIdentifier _backgroundTask;
	NSURL *_URL;
	NSURLConnection *_connection;
	NSFileHandle *_fileHandle;
	NSString *_downloadTargetPath;
	NSString *_extractedPath;
    
	DocSetDownloadStatus _status;
	float _progress;
    BOOL _shouldCancelExtracting;
	NSUInteger bytesDownloaded;
	NSInteger downloadSize;
}

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSURLConnection *connection;
@property (strong) NSString *downloadTargetPath;
@property (nonatomic, strong) NSString *extractedPath;
@property (nonatomic, assign) DocSetDownloadStatus status;
@property (nonatomic, assign) float progress;
@property (atomic, assign) BOOL shouldCancelExtracting; // must be atomic
@property (readonly) NSUInteger bytesDownloaded;
@property (readonly) NSInteger downloadSize;

- (id)initWithURL:(NSURL *)URL;
- (void)start;
- (void)cancel;
- (void)fail;

@end