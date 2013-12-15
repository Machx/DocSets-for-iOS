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

- (NSString *)contentPath{
    return @"//html/body/article";
}

-(NSString*)ipadCSS{
    return self.iphoneCSS;
}

-(NSString*)iphoneCSS{
    
    return @"<style><![CDATA[html { -webkit-text-size-adjust: 100%; } #scrollable { overflow-y: auto; -webkit-overflow-scrolling: touch; } body { font-size: 13px; padding: 15px } pre { white-space: pre-wrap !important; } h1 {font-size: 17px !important;} h2 { font-size: 15px !important; } h3 { font-size: 13px !important; } html { font-family: Lucida Grande; } img{ max-width:100% ;height: auto; display: block;} #pageTitle { color : #000; } .jump{ margin-top: 1.75em; color: #3c4c6c; padding-bottom: 2px; } .ul{ list-style: disc outside; margin: 0 0 .833em 1.35em; padding: 0 0 .5em; display: block; list-style-type: disc; } a { color: rgba(51,102,204,1.0); text-decoration: none; } .main-navigation { display: none; }]]></style>";
}


@end
