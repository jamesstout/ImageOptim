//
//  NSFileManager+AppSupp.m
//  ImageOptim
//
//  Created by James on 24/5/13.
//
//

#import "NSFileManager+AppSupp.h"

@implementation NSFileManager (AppSupp)

- (NSString *)appSuppPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //application support folder
            path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
            
            //append application name 
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
            path = [path stringByAppendingPathComponent:identifier];
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path])
            {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

@end
