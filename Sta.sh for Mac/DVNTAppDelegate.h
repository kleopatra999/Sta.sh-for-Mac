//
//  DVNTAppDelegate.h
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 15/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DVNTPreferencesWindow.h"
#import "DVNTStashManager.h"
#import <HockeySDK/HockeySDK.h>

@interface DVNTAppDelegate : NSObject <NSApplicationDelegate, NSMetadataQueryDelegate, NSUserNotificationCenterDelegate, DVNTStashManagerDelegate, BITHockeyManagerDelegate>

@property (assign) IBOutlet DVNTPreferencesWindow *prefsWindow;
@property (nonatomic) IBOutlet NSMenu *menu;
@property (nonatomic) IBOutlet NSMenu *mainMenu;
@property (nonatomic) IBOutlet NSStatusItem *menuStatusItem;
@property (nonatomic) IBOutlet NSMenuItem *uploadStatusItem;
@property (nonatomic) IBOutlet NSMenuItem *openStashStatusItem;
@property (nonatomic) IBOutlet NSMenuItem *prefsStatusItem;
@property (nonatomic) IBOutlet NSMenuItem *disableUploadsStatusItem;

@property (nonatomic) DVNTStashManager *manager;
@property (nonatomic) BOOL disabledUploads;

- (void)uploadFilesWithPaths:(NSArray *)filePaths folderName:(NSString *)folderName;
- (void)launchOnLogin:(BOOL)launch;
- (void)doScreenshotQuery:(BOOL)runQuery;

@end
