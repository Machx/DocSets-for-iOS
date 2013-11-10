//
//  AppleDocSet.m
//  DocSets
//
//  Created by Dennis Oberhoff on 10/11/13.
//
//

#import "AppleDocSet.h"

@implementation AppleDocSet

- (NSURL *)URLForNode:(NSManagedObject *)node
{
    
	NSManagedObject *pathNode = [self pathForNode:node];
    NSString *nodePath = [pathNode valueForKey:@"path"];
    
	NSString *fullPath = [[path stringByAppendingPathComponent:@"Contents/Resources/Documents"] stringByAppendingPathComponent:nodePath];
	NSURL *URL = [NSURL fileURLWithPath:fullPath];
	
    return URL;
}

-(NSString *)anchorForNode:(NSManagedObject*)node{
    
    NSManagedObject *pathNode = [self pathForNode:node];
    return [pathNode valueForKey:@"anchor"];
    
}

-(NSManagedObject*)pathForNode:(NSManagedObject*)node{
    
    NSString *nodeID = [node valueForKey:@"kID"];
    
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *urlNodeRequest = [NSFetchRequest fetchRequestWithEntityName:@"NodeURL"];
    [urlNodeRequest setPredicate:[NSPredicate predicateWithFormat:@"node.kID == %@", nodeID]];
    [urlNodeRequest setFetchLimit:1];
    
    NSArray *nodeURL = [moc executeFetchRequest:urlNodeRequest error:NULL];
	NSManagedObject *pathNode = nodeURL[0];
    
    return pathNode;
    
}

- (NSURL *)webURLForNode:(NSManagedObject *)node
{
    
    NSManagedObject *pathNode = [self pathForNode:node];
    
	NSString *nodePath = [pathNode valueForKey:@"path"];
	if (nodePath) {
		return [fallbackURL URLByAppendingPathComponent:nodePath];
	} else {
		NSString *webURL = [pathNode valueForKey:@"baseURL"];
		if (webURL) {
			return [NSURL URLWithString:webURL];
		}
	}
	return nil;
}

@end
