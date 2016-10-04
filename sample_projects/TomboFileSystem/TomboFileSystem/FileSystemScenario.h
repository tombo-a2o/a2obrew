#import <Foundation/Foundation.h>

@interface FileSystemScenario : NSObject

+ (void)allScenario;
+ (void)documentsScenario;
+ (void)documentsInboxScenario;
+ (void)libraryScenario;
+ (void)libraryCacheScenario;
+ (void)tmpScenario;
+ (NSData *)readFile:(NSString *)path;
+ (void)writeFile:(NSString *)path contents:(NSData *)data;

@end
