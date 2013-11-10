//
//  AppleDepDocSet.m
//  DocSets
//
//  Created by Dennis Oberhoff on 09/11/13.
//
//

#import "AppleDepDocSet.h"

@implementation AppleDepDocSet

- (NSURL *)URLForNode:(NSManagedObject *)node
{
    NSString *nodePath = [node valueForKey:@"kPath"];
    NSString *fullPath = [[path stringByAppendingPathComponent:@"Contents/Resources/Documents"] stringByAppendingPathComponent:nodePath];
    NSURL *URL = [NSURL fileURLWithPath:fullPath];
    
    return URL;
}

- (NSURL *)webURLForNode:(NSManagedObject *)node
{
    NSString *nodePath = [node valueForKey:@"kPath"];
    if (nodePath) {
        return [fallbackURL URLByAppendingPathComponent:nodePath];
    } else {
        NSString *webURL = [node valueForKey:@"kURL"];
        if (webURL) {
            return [NSURL URLWithString:webURL];
        }
    }
    return nil;
}

-(NSString *)anchorForNode:(NSManagedObject*)node{

    return [node valueForKey:@"kAnchor"];

}

- (NSURL *)webURLForLocalURL:(NSURL *)localURL
{
    NSString *URLString = [localURL absoluteString];
    NSUInteger anchorLocation = [URLString rangeOfString:@"#"].location;
    NSString *anchor = nil;
    if (anchorLocation != NSNotFound) {
        anchor = [URLString substringFromIndex:anchorLocation];
        URLString = [URLString substringToIndex:anchorLocation];
    }
    if ([[URLString lowercaseString] hasSuffix:@"__cached__.html"]) {
        URLString = [[URLString substringToIndex:URLString.length - [@"__cached__.html" length]] stringByAppendingFormat:@".html"];
    }
    if (anchor) {
        URLString = [URLString stringByAppendingString:anchor];
    }
    NSRange prefixRange = [URLString rangeOfString:@"Contents/Resources/Documents/"];
    NSString *URLPath = [URLString substringFromIndex:prefixRange.location + prefixRange.length];
    NSURL *webURL = [NSURL URLWithString:[[fallbackURL absoluteString] stringByAppendingFormat:@"/%@", URLPath]];
    return webURL;
}

@end
