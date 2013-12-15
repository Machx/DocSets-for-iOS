//
//  DocSetDownloadManager.m
//  DocSets
//
//  Created by Ole Zorn on 22.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "DocSetDownloadManager.h"
#import "AppleDeprecatedDocSet.h"
#import "AppleDocSet.h"
#import "CocoaDocSet.h"
#import "xar.h"
#include <sys/xattr.h>

@interface DocSetDownloadManager () <NSXMLParserDelegate>

- (void)startNextDownload;
- (void)reloadDownloadedDocSets;
- (void)downloadFinished:(DocSetDownload *)download;
- (void)downloadFailed:(DocSetDownload *)download;

@end


@implementation DocSetDownloadManager

@synthesize downloadedDocSets=_downloadedDocSets, downloadedDocSetNames=_downloadedDocSetNames, availableDownloads=_availableDownloads, currentDownload=_currentDownload, lastUpdated=_lastUpdated, neverDisableIdleTimer = _neverDisableIdleTimer;

- (id)init
{
	self = [super init];
	if (self) {
		[self reloadAvailableDocSets];
		_downloadsByURL = [NSMutableDictionary new];
		_downloadQueue = [NSMutableArray new];
		[self reloadDownloadedDocSets];
	}
	return self;
}

- (void)reloadAvailableDocSets
{
	NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
	NSString *cachedAvailableDownloadsPath = [cachesPath stringByAppendingPathComponent:@"AvailableDocSets.plist"];
	NSFileManager *fm = [[NSFileManager alloc] init];
	if (![fm fileExistsAtPath:cachedAvailableDownloadsPath]) {
		NSString *bundledAvailableDocSetsPlistPath = [[NSBundle mainBundle] pathForResource:@"AvailableDocSets" ofType:@"plist"];
		[fm copyItemAtPath:bundledAvailableDocSetsPlistPath toPath:cachedAvailableDownloadsPath error:NULL];
	}
	self.lastUpdated = [[fm attributesOfItemAtPath:cachedAvailableDownloadsPath error:NULL] fileModificationDate];
	_availableDownloads = [[NSDictionary dictionaryWithContentsOfFile:cachedAvailableDownloadsPath] objectForKey:@"DocSets"];
}

- (void)updateAvailableDocSetsFromWeb
{
	if (_updatingAvailableDocSetsFromWeb) return;
	_updatingAvailableDocSetsFromWeb = YES;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSURL *availableDocSetsURL = [NSURL URLWithString:@"https://raw.github.com/omz/DocSets-for-iOS/master/Resources/AvailableDocSet.plist"];
		NSHTTPURLResponse *response = nil;
		NSData *updatedDocSetsData = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:availableDocSetsURL] returningResponse:&response error:NULL];
		if (response.statusCode == 200) {
			NSDictionary *plist = [NSPropertyListSerialization propertyListFromData:updatedDocSetsData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
			if (plist && [plist objectForKey:@"DocSets"]) {
				NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
				NSString *cachedAvailableDownloadsPath = [cachesPath stringByAppendingPathComponent:@"AvailableDocSets.plist"];
				[updatedDocSetsData writeToFile:cachedAvailableDownloadsPath atomically:YES];
			} else {
				//Downloaded file is somehow not a valid plist...
			}	
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			_updatingAvailableDocSetsFromWeb = NO;
			[self reloadAvailableDocSets];
			[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerAvailableDocSetsChangedNotification object:self];
		});
	});
}

- (void)reloadDownloadedDocSets
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSArray *documents = [fm contentsOfDirectoryAtPath:docPath error:NULL];
	NSMutableArray *loadedSets = [NSMutableArray array];
    
	for (NSString *path in documents) {
		if ([[[path pathExtension] lowercaseString] isEqual:@"docset"]) {
			NSString *fullPath = [docPath stringByAppendingPathComponent:path];
			u_int8_t b = 1;
			setxattr([fullPath fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);

            NSString *infoPath = [fullPath stringByAppendingPathComponent:@"Contents/Info.plist"];
            NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPath];

            GenericDocSet *docSet;
            
            NSString *xcodeVersion = infoDict[@"DocSetMinimumXcodeVersion"];
            BOOL *isDashDocset = [infoDict[@"isDashDocset"] boolValue];
            
            if (xcodeVersion && !isDashDocset) {
                NSInteger xcodeMajorVersion = [[xcodeVersion componentsSeparatedByString:@"."][0] integerValue];
                NSString *vendor = infoDict[@"DocSetPublisherName"];
                
                if (![vendor isEqualToString:@"Apple"]) {
                    docSet = [[CocoaDocSet alloc] initWithPath:fullPath];
                } else if (xcodeMajorVersion >= 5) {
                    docSet = [[AppleDocSet alloc] initWithPath:fullPath];
                } else {
                    docSet = [[AppleDeprecatedDocSet alloc] initWithPath:fullPath];
                }
            }
            
            else if (isDashDocset) {
            //    docSet = [[DashDocSet alloc] initWithPath:fullPath];
            }
        
            if (docSet) [loadedSets addObject:docSet];

		}
	}


	self.downloadedDocSets = [NSArray arrayWithArray:loadedSets];
	self.downloadedDocSetNames = [NSSet setWithArray:documents];
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerUpdatedDocSetsNotification object:self];
}

+ (id)sharedDownloadManager
{
	static id sharedDownloadManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedDownloadManager = [[self alloc] init];
	});
	return sharedDownloadManager;
}

- (DocSetDownload *)downloadForURL:(NSString *)URL
{
	return [_downloadsByURL objectForKey:URL];
}

- (void)stopDownload:(DocSetDownload *)download
{
	if (download.status == DocSetDownloadStatusWaiting) {
		[_downloadQueue removeObject:download];
		[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
	} else if (download.status == DocSetDownloadStatusDownloading) {
		[download cancel];
		self.currentDownload = nil;
		[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
		[self startNextDownload];
	} else if (download.status == DocSetDownloadStatusExtracting) {
		download.shouldCancelExtracting = YES;
	}
    [self toggleIdleTimerIfNeeded];
}

- (void)downloadDocSetAtURL:(NSString *)URL
{
	if ([_downloadsByURL objectForKey:URL]) {
		//already downloading
		return;
	}
	
	DocSetDownload *download = [[DocSetDownload alloc] initWithURL:[NSURL URLWithString:URL]];
	[_downloadQueue addObject:download];
	[_downloadsByURL setObject:download forKey:URL];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerStartedDownloadNotification object:self];
	
	[self startNextDownload];
    [self toggleIdleTimerIfNeeded];
}

-(void)downloadDocSetFromAtom:(NSURL*)URL{
    
    NSString *originalURL = [[URL.absoluteString stringByRemovingPercentEncoding] stringByReplacingOccurrencesOfString:@"docs-for-xcode://" withString:@""];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:originalURL]];
    NSOperationQueue *queue = [NSOperationQueue new];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        
                               GDataXMLDocument *parser = [[GDataXMLDocument alloc] initWithData:data encoding:NSUTF8StringEncoding error:NULL];
                               
                               GDataXMLElement *entryElement = [parser.rootElement elementsForName:@"entry"][0];
                               GDataXMLElement *linkElement = [entryElement elementsForName:@"link"][0];
                               
                               NSString *downloadURL = [linkElement attributeForName:@"href"].stringValue;
                               [self downloadDocSetAtURL:downloadURL];

     }];
    
    
}


- (void)deleteDocSet:(GenericDocSet *)docSetToDelete
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetWillBeDeletedNotification object:docSetToDelete userInfo:nil];
	[[NSFileManager defaultManager] removeItemAtPath:docSetToDelete.path error:NULL];
	[self reloadDownloadedDocSets];
}

- (GenericDocSet *)downloadedDocSetWithName:(NSString *)docSetName
{
	for (GenericDocSet *docSet in _downloadedDocSets) {
		if ([[docSet.path lastPathComponent] isEqualToString:docSetName]) {
			return docSet;
		}
	}
	return nil;
}

- (void)startNextDownload
{
	if ([_downloadQueue count] == 0) {
		[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
		return;
	}
	if (self.currentDownload != nil) return;
	
	self.currentDownload = [_downloadQueue objectAtIndex:0];
	[_downloadQueue removeObjectAtIndex:0];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	[self.currentDownload start];
}

- (void)downloadFinished:(DocSetDownload *)download
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
	
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSArray *extractedItems = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:download.extractedPath error:NULL];
    
    for (NSString *file in extractedItems) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"docset"]) {
            NSString *fullPath = [download.extractedPath stringByAppendingPathComponent:file];
            NSString *targetPath = [docPath stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] moveItemAtPath:fullPath toPath:targetPath error:NULL];
            NSLog(@"Moved downloaded docset to %@", targetPath);
        }
    }
    
	[self reloadDownloadedDocSets];
	
	[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];	
	self.currentDownload = nil;
	[self startNextDownload];
    [self toggleIdleTimerIfNeeded];
}

- (void)downloadFailed:(DocSetDownload *)download
{
	[[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadFinishedNotification object:download];
	[_downloadsByURL removeObjectForKey:[download.URL absoluteString]];	
	self.currentDownload = nil;
	[self startNextDownload];
    [self toggleIdleTimerIfNeeded];
	
	[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Download Failed", nil) 
								 message:NSLocalizedString(@"An error occured while trying to download the GenericDocSet.", nil)
								delegate:nil 
					   cancelButtonTitle:NSLocalizedString(@"OK", nil) 
					   otherButtonTitles:nil] show];
}

- (void)toggleIdleTimerIfNeeded
{
    BOOL shouldDisableIdleTimer = NO;
    if (self.currentDownload && !self.neverDisableIdleTimer) {
        shouldDisableIdleTimer = YES;
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:shouldDisableIdleTimer];
    [[NSNotificationCenter defaultCenter] postNotificationName:DocSetDownloadManagerIdleTimerToggledNotification object:self];
}

- (void)setNeverDisableIdleTimer:(BOOL)neverDisableIdleTimer
{
    _neverDisableIdleTimer = neverDisableIdleTimer;
    [self toggleIdleTimerIfNeeded];
}

@end



@implementation DocSetDownload

@synthesize connection=_connection, URL=_URL, fileHandle=_fileHandle, downloadTargetPath=_downloadTargetPath, extractedPath=_extractedPath, progress=_progress, status=_status, shouldCancelExtracting = _shouldCancelExtracting;
@synthesize downloadSize, bytesDownloaded;

- (id)initWithURL:(NSURL *)URL
{
	self = [super init];
	if (self) {
		_URL = URL;
		self.status = DocSetDownloadStatusWaiting;
	}
	return self;
}

- (void)start
{
	if (self.status != DocSetDownloadStatusWaiting) {
		return;
	}
	
	_backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
	
	self.status = DocSetDownloadStatusDownloading;
	
	self.downloadTargetPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"download.xar"];
	[@"" writeToFile:self.downloadTargetPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.downloadTargetPath];
	
	bytesDownloaded = 0;
	self.connection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:self.URL] delegate:self];


    [[NSRunLoop currentRunLoop] run];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    
}

- (void)cancel
{
	if (self.status == DocSetDownloadStatusDownloading) {
		[self.connection cancel];
		self.status = DocSetDownloadStatusFinished;
		if (_backgroundTask != UIBackgroundTaskInvalid) {
			[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
	downloadSize = [[headers objectForKey:@"Content-Length"] integerValue];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	bytesDownloaded += [data length];
	if (downloadSize != 0) {
		self.progress = (float)bytesDownloaded / (float)downloadSize;
		//NSLog(@"Download progress: %f", self.progress);
	}
	[self.fileHandle writeData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.fileHandle closeFile];
	self.fileHandle = nil;
	
	self.status = DocSetDownloadStatusExtracting;
	self.progress = 0.0;
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSFileManager *fm = [[NSFileManager alloc] init];
        
        NSString *fileType = [self.downloadTargetPath pathExtension];
        NSString *extractionTargetPath = [[self.downloadTargetPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"extract"];
        self.extractedPath = extractionTargetPath;
        [fm createDirectoryAtPath:extractionTargetPath withIntermediateDirectories:YES attributes:nil error:NULL];
        
        if ([fileType isEqualToString:@"dmg"]) {
            
            // extract dmg and pkg
            
            
        }
        else if ([fileType isEqualToString:@"xar"]) {
          
            const char *xar_path = [self.downloadTargetPath fileSystemRepresentation];
            xar_t x = xar_open(xar_path, READ);
            
            xar_iter_t i = xar_iter_new();
            xar_file_t f = xar_file_first(x, i);
            NSInteger numberOfFiles = 1;
            do {
                f = xar_file_next(i);
                if (f != NULL) {
                    numberOfFiles += 1;
                }
            } while (f != NULL);
            xar_iter_free(i);
            
            chdir([extractionTargetPath fileSystemRepresentation]);
            
            if (x == NULL) {
                NSLog(@"Could not open archive");
                [self fail];
            } else {
                xar_iter_t i = xar_iter_new();
                xar_file_t f = xar_file_first(x, i);
                NSInteger filesExtracted = 0;
                do {
                    if (self.shouldCancelExtracting) {
                        NSLog(@"Extracting cancelled");
                        break;
                    }
                    if (f) {
                        const char *name = NULL;
                        xar_prop_get(f, "name", &name);
                        int32_t extractResult = xar_extract(x, f);
                        if (extractResult != 0) {
                            NSLog(@"Could not extract file: %s", name);
                        }
                        f = xar_file_next(i);
                        
                        filesExtracted++;
                        float extractionProgress = (float)filesExtracted / (float)numberOfFiles;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.progress = extractionProgress;
                        });
                    }
                } while (f != NULL);
                xar_iter_free(i);
                
                if (self.shouldCancelExtracting) {
                    // Cleanup: delete all files that have already been extracted
                    NSFileManager *fm = [[NSFileManager alloc] init];
                    [fm removeItemAtPath:extractionTargetPath error:NULL];
                }
            }
            xar_close(x);
        }
        else if  ([fileType isEqualToString:@"tgz"]) {
            
            NSData *dashDocSetDownload = [NSData dataWithContentsOfFile:self.downloadTargetPath];
            [dashDocSetDownload writeToFile:extractionTargetPath options:NSDataWritingFileProtectionNone error:nil];
            
        }
        
		
		[fm removeItemAtPath:self.downloadTargetPath error:NULL];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			self.status = DocSetDownloadStatusFinished;
			[[DocSetDownloadManager sharedDownloadManager] downloadFinished:self];
			
			if (_backgroundTask != UIBackgroundTaskInvalid) {
				[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
			}
		});
	});
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self fail];
}

- (void)fail
{
	[[DocSetDownloadManager sharedDownloadManager] downloadFailed:self];
	if (_backgroundTask != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
	}
}



@end