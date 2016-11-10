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

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    // write
    NSString *path = [documentsPath stringByAppendingPathComponent:@"ababa.txt"];

    NSData *data;

//    data = [self dataFromString:@"last text synced"];
//    [self assertFileIfExists:path contents:data];

    data = [self dataFromString:@""];
    [self writeAndAssertFile:path contents:data];

    data = [self dataFromString:@"test text"];
    [self writeAndAssertFile:path contents:data];

    data = [self dataFromLength:1024 * 1024];
    [self writeAndAssertFile:path contents:data];

    data = [self dataFromString:@"test text"];
    [self writeAndAssertFile:path contents:data];

    data = [self dataFromString:@"last text synced"];
    [self writeAndAssertFile:path contents:data];

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
    if (file == nil) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
    } else {
        [file writeData:data];
        [file truncateFileAtOffset:[data length]];
        [file closeFile];
    }
}

+ (void)assertFile:(NSString *)path contents:(NSData *)data {
    NSString *errorMessage = [NSString stringWithFormat:@"%@ is different", path];
    NSAssert([[self readFile:path] isEqualToData:data], errorMessage);
}

+ (void)assertFileIfExists:(NSString *)path contents:(NSData *)data {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self assertFile:path contents:data];
    }
}

+ (void)writeAndAssertFile:(NSString *)path contents:(NSData *)data {
    [self writeFile:path contents:data];
    [self assertFile:path contents:data];
}

+ (NSData *)dataFromString:(NSString *)str {
    return [str dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSData *)dataFromLength:(NSUInteger)length {
    NSString *seed = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
    NSMutableString *result = [NSMutableString stringWithCapacity:length];

    for (NSUInteger i = 0; i < length; i++) {
        unichar r = [seed characterAtIndex:(arc4random() % [seed length])];
        [result appendFormat:@"%C", r];
    }
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

@end
