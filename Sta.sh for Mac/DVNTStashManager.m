//
//  DVNTStashManager.m
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 16/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import "DVNTStashManager.h"
#import "DVNTAPI.h"
#import "NSString+Base36.h"

@interface DVNTStashManager () {
}

@property (nonatomic) NSInteger currentUploadCount;
@property (nonatomic) NSString *lastFilePath;
@end

@implementation DVNTStashManager

- (instancetype)init {
    if(self = [super init]) {
        _currentUploadCount = 0;
        _lastFilePath = nil;
        self.screenshotUploads = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)uploadFilesWithPaths:(NSArray *)filePaths folderName:(NSString *)folderName {
    self.currentUploadCount += filePaths.count;
    
    [self.delegate updateStatus:DVNTUploadStatusUploading remaining:self.currentUploadCount];
    
    for (NSString *filePath in filePaths) {
        self.lastFilePath = filePath;
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && isDir) {
            NSMutableArray *realsubpaths = [[NSMutableArray alloc] init];
            NSArray *subpaths = [[NSFileManager defaultManager] subpathsAtPath:filePath];
            NSEnumerator *en = [subpaths objectEnumerator];
            NSString *subpath;
            while (subpath = [en nextObject]) {
                [realsubpaths addObject:[NSString stringWithFormat:@"%@/%@", filePath, subpath]];
            }
            
            [self uploadFilesWithPaths:realsubpaths folderName:folderName];
        } else {
            BOOL isTemp = NO;
            NSString *title = [[filePath lastPathComponent] stringByDeletingPathExtension];
            
            // if a user has set this, run it. Up to them to work out errors
            if([[NSUserDefaults standardUserDefaults] objectForKey:@"scriptName"]) {
                [self runScript:[[NSUserDefaults standardUserDefaults] objectForKey:@"scriptName"] withVariables:@{@"filepath": filePath}];
            }
            
            // we dont want the ugly 20 random characters names showing up for temp files, we'll rename them to Untitled
            if([filePath rangeOfString:@"com.deviantART.Sta-sh-for-Mac/temp/"].location != NSNotFound) {
                title = @"Untitled";
                isTemp = YES;
            }
            
            NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:@{@"title": title}];
            if(folderName) [mutableParameters setObject:folderName forKey:@"folder"];
            
            [DVNTAPIRequest uploadDataFromFilePath:filePath parameters:mutableParameters success:^(NSURLSessionDataTask *task, id JSON) {
                self.currentUploadCount -= 1;
                
                if([JSON[@"status"] isEqualToString:@"success"]) {
                    
                    NSString *base36URL = [[NSString stringWithFormat:@"%@", JSON[@"stashid"]] base36Encode];
                    
                    if(self.currentUploadCount == 0 ) {
                        if([[NSUserDefaults standardUserDefaults] boolForKey:@"showNotification"]) {
                            NSUserNotification *notification = [[NSUserNotification alloc] init];
                            notification.title = @"Successfully uploaded your items!";
                            notification.informativeText = @"Link has been copied to your clipboard.";
                            
                            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:notification.userInfo];
                            [userInfo setObject:[[NSString stringWithFormat:@"http://sta.sh/0%@", base36URL] lowercaseString] forKey:@"url"];
                            notification.userInfo = [NSDictionary dictionaryWithDictionary:userInfo];
                            
                            if([[NSUserDefaults standardUserDefaults] boolForKey:@"playSound"]) {
                                notification.soundName = [[NSUserDefaults standardUserDefaults] objectForKey:@"soundFile"];
                            }
                            
                            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                        } else if([[NSUserDefaults standardUserDefaults] boolForKey:@"playSound"]) {
                            [[NSSound soundNamed:[[NSUserDefaults standardUserDefaults] objectForKey:@"soundFile"]] play];
                        }
                        
                        [self.delegate updateStatus:DVNTUploadStatusDefault remaining:self.currentUploadCount];
                    } else {
                        [self.delegate updateStatus:DVNTUploadStatusUploading remaining:self.currentUploadCount];
                    }
                    
                    NSMutableDictionary *mutableJSON = [JSON mutableCopy];
                    [mutableJSON setObject:title forKey:@"title"];
                    [mutableJSON setObject:@(isTemp) forKey:@"isTemp"];
                    
                    // if temp we need the filepath
                    if(isTemp) {
                        [mutableJSON setObject:filePath forKey:@"filePath"];
                    }
                    
                    [mutableJSON setObject:[[NSString stringWithFormat:@"http://sta.sh/0%@", base36URL] lowercaseString] forKey:@"url"];
                    
                    
                    [self.delegate uploadCompleted:mutableJSON];
                    
                    if([[NSUserDefaults standardUserDefaults] boolForKey:@"copyLink"]) {
                        NSPasteboard *generalPasteboard = [NSPasteboard generalPasteboard];
                        [generalPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
                        [generalPasteboard clearContents];
                        [generalPasteboard setString:[[NSString stringWithFormat:@"http://sta.sh/0%@", base36URL] lowercaseString] forType:NSStringPboardType];
                    }
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"deleteAfterUpload"] && [self.screenshotUploads valueForKey:self.lastFilePath] != nil) {
                        NSError *err = nil;
                        [[NSFileManager defaultManager] removeItemAtPath:self.lastFilePath error:&err];
                    }
                } else {
                    
                    if([[NSUserDefaults standardUserDefaults] boolForKey:@"showNotification"]) {
                        NSUserNotification *notification = [[NSUserNotification alloc] init];
                        notification.title = @"Upload Failed";
                        notification.informativeText = [NSString stringWithFormat:@"A file did not upload as expected: %@", JSON[@"error_description"]];
                        
                        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                    }
                    
                    [self.delegate updateStatus:DVNTUploadStatusDefault remaining:self.currentUploadCount];
                }
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                
                if([[NSUserDefaults standardUserDefaults] boolForKey:@"showNotification"]) {
                    NSUserNotification *notification = [[NSUserNotification alloc] init];
                    notification.title = @"Upload Failed";
                    notification.informativeText = [NSString stringWithFormat:@"A file did not upload as expected: %@", error.localizedDescription];
                    
                    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                }
                
                [self.delegate updateStatus:DVNTUploadStatusDefault remaining:self.currentUploadCount];
            }];
        }
    }
}

// only run for people who can set the defualts.
- (BOOL)runScript:(NSString*)scriptName withVariables:(NSDictionary *)variables
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray* urlPaths = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                            inDomains:NSUserDomainMask];
    
    // get application support directory url
    NSURL* appDirectory = [[urlPaths objectAtIndex:0] URLByAppendingPathComponent:bundleID isDirectory:YES];

    NSString *appSupportPath = [[appDirectory absoluteString] stringByRemovingPercentEncoding];
    
    
    NSArray *arguments;
    NSString* newpath = [[NSString stringWithFormat:@"%@%@", appSupportPath, scriptName] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([[NSFileManager defaultManager] fileExistsAtPath:newpath]){
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: newpath];
        
        arguments = [NSArray arrayWithObjects:variables[@"filepath"], nil];
        [task setArguments: arguments];
        
        
        NSPipe *pipe;
        pipe = [NSPipe pipe];
        [task setStandardOutput: pipe];
        
        NSFileHandle *file;
        file = [pipe fileHandleForReading];
        
        [task launch];
        
        [task waitUntilExit];
            
        NSData *data;
        data = [file readDataToEndOfFile];
        
        NSString *string;
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
        return YES;
    } else {
        return NO;
    }
    
    return NO;
}


@end
