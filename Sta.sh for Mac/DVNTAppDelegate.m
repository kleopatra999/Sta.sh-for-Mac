//
//  DVNTAppDelegate.m
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 15/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import "DVNTAppDelegate.h"
#import "DVNTAPI.h"
#import "DVNTDragStatusItem.h"
#import "NSString+TruncateToWidth.h"
#import "NSString+Base36.h"
#import "MASShortcut.h"
#import "MASShortcut+UserDefaults.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Sparkle/Sparkle.h>

@interface DVNTAppDelegate () {
}

@property (nonatomic) NSInteger originalMenuCount;
@property (nonatomic) NSMetadataQuery *screenshotQuery;
@property (nonatomic) NSInteger lastScreenshotQuerySize;

@end

@implementation DVNTAppDelegate


#pragma mark - App Delegate Methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // register our default settings
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
    
    // setup API client with ID and secret
    [DVNTAPIClient setClientID:@"__CHANGE_ME__" clientSecret:@"__CHANGE_ME__"];
    
    // register for hockeyapp
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"__CHANGE_ME__" companyName:@"__CHANGE_ME__" delegate:self];
    [[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport: YES];
    [[BITHockeyManager sharedHockeyManager] startManager];
    
    // send some analytics
    [[SUUpdater sharedUpdater] setSendsSystemProfile:YES];
    [[SUUpdater sharedUpdater] setDelegate:self];
    
    // track usage time
    NSNotificationCenter *dnc = [NSNotificationCenter defaultCenter];
    BITSystemProfile *bsp = [BITSystemProfile sharedSystemProfile];
    [dnc addObserver:bsp selector:@selector(startUsage) name:NSApplicationDidBecomeActiveNotification object:nil];
    [dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillTerminateNotification object:nil];
    [dnc addObserver:bsp selector:@selector(stopUsage) name:NSApplicationWillResignActiveNotification object:nil];
    
    // register and setup basic app functions
    if(![self isLaunchAtStartup] && [[NSUserDefaults standardUserDefaults] boolForKey:@"launchLogin"]) {
        // Register for login
        [self launchOnLogin:YES];
    }
    
    // if allowed, start the screenshot query system
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"autoUpload"]) {
        [self doScreenshotQuery:YES];
    }
    
    // regiister for the users clipboard shortcut
    [self registerShortcuts];
    
    // setup the upload to stash manager
    self.manager = [[DVNTStashManager alloc] init];
    self.manager.delegate = self;
    
    // set uptemp disabled upload boolean
    self.disabledUploads = NO;
    
    // status menu item, shown in menu bar
    self.menuStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    NSImage *statusImage = [NSImage imageNamed:@"stash-status-idle"];
    [self.menuStatusItem setImage:statusImage];
    [self.menuStatusItem setHighlightMode:YES];
    
    // the view to put in the status bar
    DVNTDragStatusItem *item = [[DVNTDragStatusItem alloc] initWithFrame:NSMakeRect(0, 0, 26, 26)];
    item.statusItem = self.menuStatusItem;
    [self.menuStatusItem setMenu:self.menu];
    [self.menuStatusItem setView:item];
    
    // original menu count for tracking when adding new items
    self.originalMenuCount = [self.menu numberOfItems];
    
    // Set the main menu to be the one with edit and quit.
    [NSApp setMainMenu:self.mainMenu];
    
    // hook up the IBactions for the menu items
    [self.openStashStatusItem setAction:@selector(openStash:)];
    [self.disableUploadsStatusItem setAction:@selector(disableUploads:)];
    [self.prefsStatusItem setAction:@selector(openPreferences:)];

    // authorize the user to the API
    [DVNTAPIClient authenticateWithScope:@"basic" completionHandler:^(NSError *error) {
        if(!error) {
            // if successful grab their user data for caching
            [DVNTAPIRequest whoAmIWithSuccess:^(NSURLSessionDataTask *task, id JSON) {
                [[NSUserDefaults standardUserDefaults] setObject:JSON[@"username"] forKey:@"username"];
                
                dispatch_queue_t downloadQueue = dispatch_queue_create("thumbnailImage", NULL);
                dispatch_async(downloadQueue, ^{;
                    NSData *tmpImageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:JSON[@"usericonurl"]]];
                    
                    [[NSUserDefaults standardUserDefaults] setObject:tmpImageData forKey:@"imageData"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                });
                
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                NSLog(@"%@", error);
            }];
        }
    }];
    
    // regsiter for NSUserNotificationCenter delegate
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    // register to get reachability updates
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        // get view
        DVNTDragStatusItem *item = (DVNTDragStatusItem *)self.menuStatusItem.view;
        
        // based on status update status menu item style
        if(status == AFNetworkReachabilityStatusNotReachable || status == AFNetworkReachabilityStatusUnknown) {
            [item setStatus:DVNTDragStatusItemOffline];
        } else {
            [item setStatus:DVNTDragStatusItemDefault];
        }
    }];
}

// Sparkle analytics
- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile {
    return [[BITSystemProfile sharedSystemProfile] systemUsageData];
}

// forward update notificatons on if need be
- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"didFinishLoadingAppcast" object:nil];
}

#pragma mark - App Setup Methods
- (void)registerShortcuts {
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:@"UploadClipboardStashKey" handler:^{
        NSMutableArray *filePaths = [NSMutableArray array];
        
        // loop pasteboard items to upload
        for (NSPasteboardItem *item in [[NSPasteboard generalPasteboard] pasteboardItems]) {
            
            // we check if its text or is a file with a path, if a path we upload form that, if text we save to a temp file then upload that.
            NSString *fileURLString = nil;
            if([item.types containsObject:@"public.file-url"]) {
                // get file url and tidy it to be a real system URL
                fileURLString = [[[NSURL URLWithString:[item stringForType:@"public.file-url"]] filePathURL] absoluteString];
                fileURLString = [fileURLString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                fileURLString = [fileURLString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                
            } else if([item.types containsObject:@"public.utf8-plain-text"]){
                // as text from clipboard doesnt get handled right, we have to handle it here. We first create a .txt file containing said text in the app's support temp directory so we can upload it, then when it is uploaded, we delete it.
                
                // get the data of the text and write it to the filepath
                NSData *data = [item dataForType:@"public.utf8-plain-text"];
        
                fileURLString = [self writeData:data toTempDirWithExtension:@".txt"];
            } else if([item.types containsObject:@"public.tiff"]) {
                // supports copied images from the web. Because why not.
                // get the data of the text and write it to the filepath
                NSData *data = [item dataForType:@"public.tiff"];
                
                fileURLString = [self writeData:data toTempDirWithExtension:@".tiff"];
            }
            
            // check if fileURLString is not nil, if nil it will crash
            if(fileURLString) {
                [filePaths addObject:fileURLString];
            }
        }
        
        // check we actually have some filepaths to upload
        if(filePaths.count > 0) {
            // upload to the clipboard folder
            [self.manager uploadFilesWithPaths:filePaths folderName:@"Clipboard Uploads"];
        }
    }];
    
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:@"TakeScreenshotStashKey" handler:^{
        NSArray *args = [NSArray arrayWithObjects:@"-ict", @"png", nil];
        [[NSTask launchedTaskWithLaunchPath: @"/usr/sbin/screencapture" arguments: args] waitUntilExit];
        
        NSMutableArray *filePaths = [NSMutableArray array];
        
        for (NSPasteboardItem *item in [[NSPasteboard generalPasteboard] pasteboardItems]) {
            NSString *fileURLString = nil;
            if([item.types containsObject:@"public.png"]) {
                NSData *data = [item dataForType:@"public.png"];
                
                fileURLString = [self writeData:data toTempDirWithExtension:@".png"];
            }
            
            // check if fileURLString is not nil, if nil it will crash
            if(fileURLString) {
                [filePaths addObject:fileURLString];
            }
        }
        
        // check we actually have some filepaths to upload
        if(filePaths.count > 0) {
            // upload to the clipboard folder
            [self.manager uploadFilesWithPaths:filePaths folderName:@"Clipboard Uploads"];
        }
    }];
    
    [MASShortcut registerGlobalShortcutWithUserDefaultsKey:@"DisableUploadsStashKey" handler:^{
        NSMenuItem *item = [self.menu itemWithTitle:@"Disable Uploads"];
        [self disableUploads:item];
    }];
}

- (NSString *)writeData:(NSData *)data toTempDirWithExtension:(NSString *)extension {
    //Create App directory if not exists:
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSArray* urlPaths = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                            inDomains:NSUserDomainMask];
    
    // get application support directory url
    NSURL* appDirectory = [[urlPaths objectAtIndex:0] URLByAppendingPathComponent:bundleID isDirectory:YES];
    
    // append temp to it
    NSURL *dirPath = [appDirectory URLByAppendingPathComponent:@"temp"];
    
    // if it doesn't exist we create it and its intermediatery dirs
    if (![fileManager fileExistsAtPath:[dirPath path]]) {
        [fileManager createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // random file name of 20 letters
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:20];
    for (int i=0; i<20; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    
    // append it to the dirPath
    NSString *filePath = [[dirPath path] stringByAppendingString:[NSString stringWithFormat:@"/%@%@", randomString, extension]];
    
    
    if([data writeToFile:filePath options:NSDataWritingAtomic error:nil]) {
        return filePath;
    }
    
    return nil;
}


#pragma mark - Screenshot Query Processing

- (void)doScreenshotQuery:(BOOL)runQuery {
    // check if we wants to run or cancel  it
    if(runQuery) {
        // initalize it
        self.screenshotQuery = [[NSMetadataQuery alloc] init];
        
        // reset value of last query size to 0
        self.lastScreenshotQuerySize = 0;
        
        // register for notifcations about this query
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenshotQueryUpdated:) name:NSMetadataQueryDidUpdateNotification object:self.screenshotQuery];
        
        // set the delegate of the query
        [self.screenshotQuery setDelegate:self];
        
        // path to the screenshots we want, OSX defaults to Desktop
        NSString *screenshotsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
        
        // check if it is correct, if changed in settings we use that.
        NSDictionary *appleDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.screencapture"];
        
        if ([appleDefaults valueForKey:@"location"] != nil) {
            screenshotsPath = [appleDefaults valueForKey:@"location"];
        }
        
        // set the scope to the path
        [self.screenshotQuery setSearchScopes:[NSArray arrayWithObjects:screenshotsPath,nil]];
        
        // set our filter to be only screencaptures
        [self.screenshotQuery setPredicate:[NSPredicate predicateWithFormat:@"kMDItemIsScreenCapture = 1"]];
        
        // start the query
        [self.screenshotQuery startQuery];
    } else {
        // stop and nil the query
        [self.screenshotQuery stopQuery];
        self.screenshotQuery = nil;
    }
}

- (void)screenshotQueryUpdated:(NSNotification *)note {
    // get last size and store it in a variable then set new size to it
    NSInteger previousLastSize = self.lastScreenshotQuerySize;
    self.lastScreenshotQuerySize = [self.screenshotQuery resultCount];
    
    // if autoUpload is off, return now.
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"autoUpload"]) {
        return;
    }
    
    // run only if results has more than one
    if ([self.screenshotQuery resultCount] > 0) {
        
        // loop results
        for (long i = previousLastSize; i <= [self.screenshotQuery resultCount] - 1; i++) {
            // get all the data we need from it
            NSMetadataItem *mditem = [self.screenshotQuery resultAtIndex:i];
            NSString *filePath = [mditem valueForAttribute:(NSString *)kMDItemPath];
            NSError * err;
            NSDictionary * fileDict = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&err];
            NSDate * fileDate = [fileDict objectForKey:@"NSFileModificationDate"];
            
            // If file was last modified less than 10 seconds ago and hasn't been queued yet, we queue and upload it
            if ([fileDate timeIntervalSinceNow] > -10.0 && [self.manager.screenshotUploads valueForKey:filePath] == nil) {
                [self.manager.screenshotUploads setValue:filePath forKey: filePath];
                [self.manager uploadFilesWithPaths:@[filePath] folderName:@"Screenshot Uploads"];
            }
        }
    }
}


#pragma mark - App Methods

// use solely for the drag operation uploads
- (void)uploadFilesWithPaths:(NSArray *)filePaths folderName:(NSString *)folderName {
    [self.manager uploadFilesWithPaths:filePaths folderName:folderName];
}


- (void)addToMenu:(NSDictionary *)file {
    // text attributes
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSColor blackColor], NSForegroundColorAttributeName,
								[NSFont fontWithName:@"Lucida Grande" size:14.0], NSFontAttributeName, nil];
    
    // trunucate the title
    NSString *truncatedTitle = [file[@"title"] stringByTruncatingStringToWidth:165.0 withAttributes:attributes];
	
    // make a new menu item for it with action to open a link
	NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:truncatedTitle action:@selector(openLink:) keyEquivalent:@""];
    
    // make the title the style we want
	NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:truncatedTitle attributes:attributes];
	[menuItem setAttributedTitle:attributedTitle];
    
    // set the represented object to the file's URL so we can get it when clicked
	[menuItem setRepresentedObject:file[@"url"]];
	
    // insert a seperator if need be
	if ([self.menu numberOfItems] == self.originalMenuCount) {
		[self.menu insertItem:[NSMenuItem separatorItem] atIndex:3];
	}
    
    // insert our new item
	[self.menu insertItem:menuItem atIndex:3];
	
    // remove one if need be
	if ([self.menu numberOfItems] > self.originalMenuCount + 11) {
		[self.menu removeItemAtIndex:12];
	}
}

// open the menu items link in the browser
- (void)openLink:(id)sender {
	NSMenuItem *menuItem = sender;
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[menuItem representedObject]]];
}


#pragma mark - IBAction Methods

// open the website
- (IBAction)openStash:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sta.sh/"]];
}

- (IBAction)openPreferences:(id)sender {
    // bring the prefs window to the front of everything
    [self.prefsWindow makeKeyAndOrderFront:self];
    [self.prefsWindow center];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)disableUploads:(id)sender {
    NSMenuItem *item = (NSMenuItem *)sender;
    // disable uploads this sessions
    if(self.disabledUploads) {
        self.disabledUploads = NO;
        [item setState:NSOffState];
        
        // start query
        [self doScreenshotQuery:YES];
    } else {
        // enable it again
        self.disabledUploads = YES;
        [item setState:NSOnState];
        
        // stop query
        [self doScreenshotQuery:NO];
    }
}


#pragma mark - DVNTStashManagerDelegate Methods

- (void)uploadCompleted:(NSDictionary *)file {
    // if the file was a text file and is from our temp dir, we will now delete it as we no longer need it
    if([file[@"isTemp"] boolValue]) {
        // the file's path to delete
        NSString *filePath = file[@"filePath"];
        
        // if it exists, delete it
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            if(error) {
                NSLog(@"[Deleting Temp File] %@", error);
            }
        }
    }
    
    // add to the menu
    [self addToMenu:file];
}

- (void)updateStatus:(DVNTUploadStatus)status remaining:(NSInteger)remaining {
    // get the item's view to update
    DVNTDragStatusItem *item = (DVNTDragStatusItem *)self.menuStatusItem.view;
    
    // based on status update to right status on the item.
    if(status == DVNTUploadStatusDefault) {
        [item setStatus:DVNTDragStatusItemDefault];
        [self.uploadStatusItem setTitle:@"All files are up to date"];
    } else if(status == DVNTUploadStatusUploading) {
        [item setStatus:DVNTDragStatusItemUploading];
        NSString *uploadText = [NSString stringWithFormat:@"Uploading %lu file%@...", (unsigned long)remaining, (remaining > 1) ? @"s" : @""];
        [self.uploadStatusItem setTitle:uploadText];
    }
}


#pragma mark - NSUserNotificationCenter Delegate
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    // opens the URL as expected
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[@"url"]]];
}

// ensures it presents anytime even in background
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}


#pragma mark - Launch on Login Methods

- (BOOL)isLaunchAtStartup {
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);
    
    return isInList;
}

- (void)launchOnLogin:(BOOL)launch {
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (launch) {
        // Add the app to the LoginItems list.
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else {
        // Remove the app from the LoginItems list.
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
}

- (LSSharedFileListItemRef)itemRefInLoginItems {
    LSSharedFileListItemRef itemRef = nil;
    
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    
	// Create a reference to the shared file list.
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
	if (loginItems) {
		UInt32 seedValue;
		//Retrieve the list of Login Items and cast them to
		// a NSArray so that it will be easier to iterate.!
		NSArray  *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for(int i = 0; i< [loginItemsArray count]; i++){
			LSSharedFileListItemRef currentItemRef = (__bridge LSSharedFileListItemRef)[loginItemsArray
                                                                                        objectAtIndex:i];
			//Resolve the item with URL
			if (LSSharedFileListItemResolve(currentItemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString * urlPath = [(__bridge NSURL*)url path];
				if ([urlPath compare:appPath] == NSOrderedSame){
                    itemRef = currentItemRef;
				}
			}
		}
	}
    
    CFRelease(loginItems);
    return itemRef;
}

@end
