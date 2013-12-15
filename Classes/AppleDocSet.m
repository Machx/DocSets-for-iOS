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

-(NSString*)ipadCSS
{
    return self.iphoneCSS;
}

-(NSString*)iphoneCSS{
    
    return @"<style>html { -webkit-text-size-adjust: 100%; } #scrollable { overflow-y: auto; -webkit-overflow-scrolling: touch; } body { font-size: 13px; padding: 15px } pre { white-space: pre-wrap !important; } h1 {font-size: 17px !important;} h2 { font-size: 15px !important; } h3 { font-size: 13px !important; } html { font-family: Lucida Grande; } #pageTitle { text-align:center; } .pageNavigationLinks, .tooltip, .hideOnPrint, .copyright, #header, #feedbackForm , #xcode_leave_feedback{ display: none; } img{ max-width:100% ;height: auto; display: block;} #pageTitle { color : #000; } .jump{ margin-top: 1.75em; color: #3c4c6c; padding-bottom: 2px; } .ul{ list-style: disc outside; margin: 0 0 .833em 1.35em; padding: 0 0 .5em; display: block; list-style-type: disc; } a { color: rgba(51,102,204,1.0); text-decoration: none; } </style>";
    
}

@end
