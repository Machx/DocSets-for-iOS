//
//  DocSet.h
//  DocSets
//
//  Created by Dennis Oberhoff on 10/11/13.
//
//

#import <Foundation/Foundation.h>

@protocol DocSet <NSObject>

@required
- (NSURL *)URLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForLocalURL:(NSURL *)localURL;
- (NSString *)anchorForNode:(NSManagedObject*)node;
@end

#define DocSetWillBeDeletedNotification                @"DocSetWillBeDeletedNotification"

#define kNodeSectionNodes                                        @"nodes"
#define kNodeSectionTitle                                        @"title"

typedef void(^DocSetSearchCompletionHandler)(NSString *searchTerm, NSArray *results);

@interface DocSet : NSObject {
    
    NSString *path;
    NSString *title;
    NSString *copyright;
    NSString *bundleID;
    NSURL *fallbackURL;
    
    NSManagedObjectContext *managedObjectContext;
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    
    dispatch_queue_t searchQueue;
    BOOL loadingTokens;
    NSArray *tokens;
    NSArray *nodeInfos;
}

@property (nonatomic, strong, readonly) NSString *path;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *copyright;
@property (nonatomic, strong, readonly) NSString *bundleID;
@property (nonatomic, readonly) NSString *ipadCSS;
@property (nonatomic, readonly) NSString *iphoneCSS;
@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (id)initWithPath:(NSString *)docSetPath;
- (NSArray *)nodeSectionsForRootNode:(NSManagedObject *)rootNode;
- (BOOL)nodeIsExpandable:(NSManagedObject *)node;
- (void)prepareSearch;
- (void)searchForNodesMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion;
- (void)searchForTokensMatching:(NSString *)searchTerm completion:(DocSetSearchCompletionHandler)completion;

- (NSURL *)URLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForNode:(NSManagedObject *)node;
- (NSURL *)webURLForLocalURL:(NSURL *)localURL;

- (NSString *)anchorForNode:(NSManagedObject*)node;

@end
