//
//  AppleDeprecatedDocSet.m
//  DocSets
//
//  Created by Dennis Oberhoff on 09/11/13.
//
//

#import "AppleDeprecatedDocSet.h"

@implementation AppleDeprecatedDocSet

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

-(NSString*)ipadCSS{
    return @"<style>body { font-size: 16px !important; } pre { white-space: pre-wrap !important; }</style>";
}

-(NSString*)iphoneCSS{
    return @"<meta name = \"viewport\" content = \"width = device-width, initial-scale=1.0\"><style>body { font-size: 15px !important; padding: 15px !important; } pre { white-space: pre-wrap !important; } h1 {font-size: 22px !important;} h2 { font-size: 20px !important; } h3 { font-size: 18px !important; } .dtsDocNumber {font-size: 22px !important;} .specbox { margin-left: 0 !important; } #feedbackForm { display: none; }</style>";
}

@end
