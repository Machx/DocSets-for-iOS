//
//  CocoaDocSet.m
//  DocSets
//
//  Created by Dennis Oberhoff on 11/11/13.
//
//

#import "CocoaDocSet.h"

@implementation CocoaDocSet

-(id)initWithPath:(NSString *)docSetPath{

    self = [super initWithPath:docSetPath];
    
    if (self) {
        NSString *infoPath = [path stringByAppendingPathComponent:@"Contents/Info.plist"];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
        title = [info objectForKey:@"DocSetFeedName"];
        
        
    }
    
    return self;
    
}

- (NSArray*)nodeSectionsForRootNode:(NSManagedObject *)rootNode
{
    
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *rootNodeRequest = [NSFetchRequest fetchRequestWithEntityName:@"Node"];
    [rootNodeRequest setPredicate:[NSPredicate predicateWithFormat:@"kNodeType == 'folder' AND orderedSelfs.@count > 0"]];
    [rootNodeRequest setSortDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"kName" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    NSArray *rootNodes = [moc executeFetchRequest:rootNodeRequest error:NULL];
    NSMutableArray *sections = [NSMutableArray array];
    
    for (NSManagedObject *rootNode in rootNodes) {
        NSArray *subnodes = [[rootNode valueForKey:@"orderedSubnodes"] sortedArrayUsingDescriptors:
                             [NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES]]];
        
        NSMutableArray *nodes = [NSMutableArray array];
        
        for (NSManagedObject *orderedNode in subnodes) {
            [nodes addObject:[orderedNode valueForKeyPath:@"node"]];
        }
        
        NSDictionary *section = [NSDictionary dictionaryWithObjectsAndKeys:
                                 nodes, kNodeSectionNodes,
                                 [rootNode valueForKey:@"kName"], kNodeSectionTitle,
                                 nil];
        
        [sections addObject:section];
    }
    
    return sections;
 
}

-(NSString*)ipadCSS{
    return @"<style>body { font-size: 16px !important; } pre { white-space: pre-wrap !important; }</style>";
}



-(NSString*)iphoneCSS{
    
    return @"<meta name = \"viewport\" content = \"width = device-width, initial-scale=1.0\"><style>body { font-size: 15px !important; padding: 15px !important; } pre { white-space: pre-wrap !important; } h1 {font-size: 22px !important;} h2 { font-size: 20px !important; } h3 { font-size: 18px !important; } .dtsDocNumber {font-size: 22px !important;} .specbox { margin-left: 0 !important; } #feedbackForm { display: none; }</style>";
}


@end
