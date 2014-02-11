//
//  DVNTStashManager.hs
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 16/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import <Foundation/Foundation.h>

// enum of upload status
typedef enum {
    DVNTUploadStatusDefault,
    DVNTUploadStatusUploading
} DVNTUploadStatus;

// delegate methods
@protocol DVNTStashManagerDelegate <NSObject>
@required
- (void)uploadCompleted:(NSDictionary *)file;
- (void)updateStatus:(DVNTUploadStatus)status remaining:(NSInteger)remaining;
@end

@interface DVNTStashManager : NSObject

- (void)uploadFilesWithPaths:(NSArray *)filePaths folderName:(NSString *)folderName;

@property (nonatomic) id <DVNTStashManagerDelegate> delegate;
@property (nonatomic) NSMutableDictionary *screenshotUploads;
@end
