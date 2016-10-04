#import "FileSystemScenario.h"

@implementation FileSystemScenario

// Refer: File System Programming Guide
// https://developer.apple.com/library/content/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html

// Refer: iOS Data Storage Guidelines
// https://developer.apple.com/icloud/documentation/data-storage/index.html

+ (void)allScenario {
    [self documentsScenario];
    [self documentsInboxScenario];
    [self libraryScenario];
    [self libraryCacheScenario];
    [self tmpScenario];
}

+ (void)documentsScenario {
    // $APP_HOME/Documents/ (without Documents/Inbox)
    // User-generated data
    // Read         : OK
    // Write        : OK
    // Delete       : OK
    // iTunes backup: OK
    // Persistent   : OK

    // TODO: implement

    // TODO: "Do Not Backup" attribute
}

+ (void)documentsInboxScenario {
    // $APP_HOME/Documents/Inbox/
    // Received data from other applications
    // Read         : OK
    // Write        : NG
    // Delete       : OK
    // iTunes backup: OK
    // Persistent   : OK

    // TODO: implement
}

+ (void)libraryScenario {
    // $APP_HOME/Library/ (without Library/Cache)
    // Read         : OK
    // Write        : OK
    // Delete       : OK
    // iTunes backup: OK
    // Persistent   : OK

    // TODO: implement
}

+ (void)libraryCacheScenario {
    // $APP_HOME/Library/Cache/
    // Redownloadable or regeneratable data
    // Read         : OK
    // Write        : OK
    // Delete       : OK
    // iTunes backup: NG
    // Persistent   : NG (deletable anytime)

    // TODO: implement
}

+ (void)tmpScenario {
    // $APP_HOME/tmp/
    // Temporary data
    // Read         : OK
    // Write        : OK
    // Delete       : OK
    // iTunes backup: NG
    // Persistent   : NG (deletable when app is inactive)

    // TODO: implement
}

+ (NSData *)readFile:(NSString *)path {
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath: path];
    if (file == nil) {
        NSLog(@"Failed to open file %@", path);
        return nil;
    }
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    return data;
}

+ (void)writeFile:(NSString *)path contents:(NSData *)data {
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    [file writeData:data];
    [file closeFile];
}

@end
