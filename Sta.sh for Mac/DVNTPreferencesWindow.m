//
//  DVNTPreferencesWindow.m
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 15/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import "DVNTPreferencesWindow.h"
#import "DVNTAPI.h"
#import "MASShortcutView+UserDefaults.h"
#import "MASShortcut+UserDefaults.h"
#import "MASShortcut+Monitoring.h"
#import "DVNTAppDelegate.h"
#import <Sparkle/Sparkle.h>

@interface DVNTPreferencesWindow () {
}

@property (nonatomic) BOOL isShowingUpdater;
@property (nonatomic) NSInteger currentViewTag;

@end

@implementation DVNTPreferencesWindow

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // observe for update check changes.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCheckUpdateLabel:) name:@"didFinishLoadingAppcast" object:nil];
    
    // set the last view back
    [self setLastView];
}

- (void)updateCheckUpdateLabel:(NSNotification *)notification {
    if(self.isShowingUpdater) {
        [self selectUpdate:nil];
    }
}

// bring the window to the top and set the last view back to it
- (void)makeKeyAndOrderFront:(id)sender {
    [super makeKeyAndOrderFront:sender];
    
    [self setLastView];
}

- (void)setLastView {
    // 0 = account, 1 = preferences, 2 = updates, 3 = about
    // sets the last viewed tab back to be set if the window is visible
    if([self isVisible]) {
        switch (self.currentViewTag) {
            case 0: {
                [self selectAccount:nil];
                break;
            }
                
            case 1: {
                [self selectPreferences:nil];
                break;
            }
                
            case 2: {
                [self selectUpdate:nil];
                break;
            }
                
            case 3: {
                [self selectAbout:nil];
                break;
            }
                
            default: {
                [self selectAccount:nil];
                break;
            }
        }
        
        [self.toolbar setSelectedItemIdentifier:[(NSToolbarItem *)self.toolbar.items[self.currentViewTag] itemIdentifier]];
    }
}


// Select Account Tab
- (IBAction)selectAccount:(id)sender {
    // clear any old views in the window
    [self clearSubviews];
    
    // set the tag for the current view to 0
    self.currentViewTag = 0;
    
    // resize the window to the right size
    [self resizeWindow:300];
    
    // the title label
    NSTextField *textLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-130, self.frame.size.width, 30)];
    [textLabel setStringValue:@"Store, privately share, and publish your files to your deviantART Sta.sh."];
    [textLabel setEditable:NO];
    [textLabel setBezeled:NO];
    [textLabel setBackgroundColor:[NSColor clearColor]];
    [textLabel setAlignment:kCTTextAlignmentCenter];
    [textLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:textLabel];
    
    // if the app has credentials we show the user;s details
    if([DVNTAPIClient hasCredential]) {
        // image view for the avatar
        NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect((self.frame.size.width-75)/2, self.frame.size.height-205, 75, 75)];
        [imageView setImageFrameStyle:NSImageFrameGrayBezel];
        [self.contentView addSubview:imageView];
        
        // label for their username
        NSTextField *accountNameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-240, self.frame.size.width, 30)];
        [accountNameLabel setStringValue:@""];
        [accountNameLabel setEditable:NO];
        [accountNameLabel setBezeled:NO];
        [accountNameLabel setBackgroundColor:[NSColor clearColor]];
        [accountNameLabel setAlignment:kCTTextAlignmentCenter];
        [accountNameLabel setFont:[NSFont boldSystemFontOfSize:13]];
        [self.contentView addSubview:accountNameLabel];
        
        // usage label
        NSTextField *smallTextLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-260, self.frame.size.width, 30)];
        [smallTextLabel setStringValue:@"- GB available out of - GB"];
        [smallTextLabel setEditable:NO];
        [smallTextLabel setBezeled:NO];
        [smallTextLabel setBackgroundColor:[NSColor clearColor]];
        [smallTextLabel setTextColor:[NSColor lightGrayColor]];
        [smallTextLabel setAlignment:kCTTextAlignmentCenter];
        [smallTextLabel setFont:[NSFont systemFontOfSize:11]];
        [self.contentView addSubview:smallTextLabel];
        
        // if no cached data we load it, else show it immediately
        if(![[NSUserDefaults standardUserDefaults] objectForKey:@"username"]) {
            // load the whoami request
            [DVNTAPIRequest whoAmIWithSuccess:^(NSURLSessionDataTask *task, id JSON) {
                // account name label text is your username, also store it for later
                [accountNameLabel setStringValue:JSON[@"username"]];
                [[NSUserDefaults standardUserDefaults] setObject:JSON[@"username"] forKey:@"username"];
                
                // dispatch a queue to load the user icon
                dispatch_queue_t downloadQueue = dispatch_queue_create("thumbnailImage", NULL);
                dispatch_async(downloadQueue, ^{
                    // lod the image
                    NSData *tmpImageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:JSON[@"usericonurl"]]];
                    
                    // store in user defaults
                    [[NSUserDefaults standardUserDefaults] setObject:tmpImageData forKey:@"imageData"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    // set the image if we have one to the image view
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(tmpImageData) {
                            imageView.image = [[NSImage alloc] initWithData:tmpImageData];
                        } else {
                            imageView.image = [NSImage imageNamed:@"logo"];
                        }
                    });
                });
                
            } failure:^(NSURLSessionDataTask *task, NSError *error) {
                // if we failt to load the whoamo data, we show the dA logo and no username
                [accountNameLabel setStringValue:@""];
                imageView.image = [NSImage imageNamed:@"logo"];
            }];
        } else {
            [accountNameLabel setStringValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"username"]];
            NSData *tmpImageData = [[NSUserDefaults standardUserDefaults] dataForKey:@"imageData"];
            imageView.image = [[NSImage alloc] initWithData:tmpImageData];
        }
    
        
        // load the user's space.
        [DVNTAPIRequest spaceWithSuccess:^(NSURLSessionDataTask *task, id JSON) {
            double total = [JSON[@"total_space"] doubleValue];
            double available = [JSON[@"available_space"] doubleValue];
            
            // convert the numbers to a nicely formatted value
            NSString *formattedAvailable = [NSByteCountFormatter stringFromByteCount:available countStyle:NSByteCountFormatterCountStyleBinary];
            NSString *formattedTotal = [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleBinary];
            
            // set the label text
            NSString *dataUsed = [NSString stringWithFormat:@"%@ available out of %@", formattedAvailable, formattedTotal];
            [smallTextLabel setStringValue:dataUsed];
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            // if the API call fails, set the usage label to be blank
            [smallTextLabel setStringValue:@""];
        }];
        
        /// button to allow the user to sign out
        NSButton *signOutButton = [[NSButton alloc] initWithFrame:NSMakeRect((self.frame.size.width-90)/2, self.frame.size.height-285, 90, 30)];
        [signOutButton setTitle:@"Sign out"];
        [signOutButton setButtonType:NSMomentaryPushInButton];
        [signOutButton setBezelStyle:NSRoundedBezelStyle];
        [signOutButton setAction:@selector(signOut:)];
        [self.contentView addSubview:signOutButton];
    } else {
        // if the app has no credentials we show the sign in view here
        // logo of dA.
        NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect((self.frame.size.width-75)/2, self.frame.size.height-205, 75, 75)];
        imageView.image = [NSImage imageNamed:@"logo"];
        [imageView setImageFrameStyle:NSImageFrameGrayBezel];
        [self.contentView addSubview:imageView];
        
        // button to sign in with
        NSButton *signinButton = [[NSButton alloc] initWithFrame:NSMakeRect((self.frame.size.width-170)/2, self.frame.size.height-250, 170, 30)];
        [signinButton setTitle:@"Sign in with deviantART"];
        [signinButton setButtonType:NSMomentaryPushInButton];
        [signinButton setBezelStyle:NSRoundedBezelStyle];
        [signinButton setAction:@selector(signin:)];
        [self.contentView addSubview:signinButton];
        
        // small text label with some info about sta.sh
        NSTextField *smallTextLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-285, self.frame.size.width, 30)];
        [smallTextLabel setStringValue:@"Get 2GB of free space in your Sta.sh"];
        [smallTextLabel setEditable:NO];
        [smallTextLabel setBezeled:NO];
        [smallTextLabel setBackgroundColor:[NSColor clearColor]];
        [smallTextLabel setTextColor:[NSColor lightGrayColor]];
        [smallTextLabel setAlignment:kCTTextAlignmentCenter];
        [smallTextLabel setFont:[NSFont systemFontOfSize:11]];
        [self.contentView addSubview:smallTextLabel];
    }
   
}

// sign in action
- (IBAction)signin:(id)sender {
    // use DVNTAPIClient to authenticate, presents the window with the auth form.
    [DVNTAPIClient authenticateWithScope:@"basic" completionHandler:^(NSError *error) {
        // when successful we do the whoami request and load in the data.
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
        
        // we then select the account tab
        [self selectAccount:self];
    }];
}

// sign out action
- (IBAction)signOut:(id)sender {
    // sign out using DVNTAPIClient and select account tab
    [DVNTAPIClient unauthenticate];
    [self selectAccount:nil];
}

// Select Preferences
- (IBAction)selectPreferences:(id)sender {
    // clear the old subviews
    [self clearSubviews];
    
    // set the current view tag to 1
    self.currentViewTag = 1;
    
    // resize the window as needed
    [self resizeWindow:360];
    
    // upload clipboard label
    NSTextField *clipboardLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-130, 180, 30)];
    [clipboardLabel setStringValue:@"Upload Clipboard:"];
    [clipboardLabel setEditable:NO];
    [clipboardLabel setBezeled:NO];
    [clipboardLabel setBackgroundColor:[NSColor clearColor]];
    [clipboardLabel setAlignment:kCTTextAlignmentRight];
    [clipboardLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:clipboardLabel];
    
    // shortcut view for said shortcut, allows easy shortcut creation
    MASShortcutView *clipboardShortCutView = [[MASShortcutView alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-120, 100, 19)];
    clipboardShortCutView.associatedUserDefaultsKey = @"UploadClipboardStashKey";
    [self.contentView addSubview:clipboardShortCutView];
    
    // take screenshot label
    NSTextField *screenshotLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-170, 180, 30)];
    [screenshotLabel setStringValue:@"Take Screenshot:"];
    [screenshotLabel setEditable:NO];
    [screenshotLabel setBezeled:NO];
    [screenshotLabel setBackgroundColor:[NSColor clearColor]];
    [screenshotLabel setAlignment:kCTTextAlignmentRight];
    [screenshotLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:screenshotLabel];
    
     // shortcut view for said shortcut, allows easy shortcut creation
    MASShortcutView *screenshotShortCutView = [[MASShortcutView alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-160, 100, 19)];
    screenshotShortCutView.associatedUserDefaultsKey = @"TakeScreenshotStashKey";
    [self.contentView addSubview:screenshotShortCutView];
    
    // uploading label
    NSTextField *uploadingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-210, 180, 30)];
    [uploadingLabel setStringValue:@"Uploading:"];
    [uploadingLabel setEditable:NO];
    [uploadingLabel setBezeled:NO];
    [uploadingLabel setBackgroundColor:[NSColor clearColor]];
    [uploadingLabel setAlignment:kCTTextAlignmentRight];
    [uploadingLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:uploadingLabel];
    
    // check button for uploading screenshots automatically
    NSButton *uploadScreenshots = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-205, 250, 30)];
    [uploadScreenshots setButtonType:NSSwitchButton];
    [uploadScreenshots setTitle:@"Upload screenshots automatically"];
    [uploadScreenshots setAction:@selector(toggleAutoUpload:)];
    [self setStateForButton:uploadScreenshots withSetting:@"autoUpload"];
    [self.contentView addSubview:uploadScreenshots];
    
    // check button for deleting screenshots after upload
    NSButton *deleteScreenshots = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-230, 250, 30)];
    [deleteScreenshots setButtonType:NSSwitchButton];
    [deleteScreenshots setTitle:@"Delete screenshots after upload"];
    [deleteScreenshots setAction:@selector(toggleDeleteAfterUpload:)];
    [self setStateForButton:deleteScreenshots withSetting:@"deleteAfterUpload"];
    [self.contentView addSubview:deleteScreenshots];
    
    // after stashing label
    NSTextField *stashingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-270, 180, 30)];
    [stashingLabel setStringValue:@"After stashing:"];
    [stashingLabel setEditable:NO];
    [stashingLabel setBezeled:NO];
    [stashingLabel setBackgroundColor:[NSColor clearColor]];
    [stashingLabel setAlignment:kCTTextAlignmentRight];
    [stashingLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:stashingLabel];
    
    // cehck button for copying the link after upload
    NSButton *copyLink = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-265, 250, 30)];
    [copyLink setButtonType:NSSwitchButton];
    [copyLink setAction:@selector(toggleCopyLink:)];
    [copyLink setTitle:@"Automatically copy link to clipboard"];
    [self setStateForButton:copyLink withSetting:@"copyLink"];
    [self.contentView addSubview:copyLink];
    
    // check button for showing a notification in notification center after upload
    NSButton *showNotification = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-290, 250, 30)];
    [showNotification setButtonType:NSSwitchButton];
    [showNotification setAction:@selector(toggleShowNotification:)];
    [showNotification setTitle:@"Show notification"];
    [self setStateForButton:showNotification withSetting:@"showNotification"];
    [self.contentView addSubview:showNotification];
    
    // check button for playing sound on successful upload
    NSButton *playSound = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-315, 250, 30)];
    [playSound setButtonType:NSSwitchButton];
    [playSound setTitle:@"Play"];
    [playSound setAction:@selector(toggleSound:)];
    [self setStateForButton:playSound withSetting:@"playSound"];
    [self.contentView addSubview:playSound];
    
    // sounds to list
    NSArray *sounds = @[@"Basso", @"Blow", @"Bottle", @"Frog", @"Funk", @"Glass", @"Hero", @"Morse", @"Ping", @"Pop", @"Purr", @"Sosumi", @"Submarine", @"Tink"];
    
    // pop up menu for selecting sound to play on upload
    NSPopUpButton *soundMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(245, self.frame.size.height-315, 80, 30) pullsDown:NO];
    [soundMenu setAction:@selector(changedSound:)];
    [soundMenu addItemsWithTitles:sounds];
    
    // check if sound file was previously set, if so set it in the menu by default
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"soundFile"]) {
        [soundMenu selectItemWithTitle:[[NSUserDefaults standardUserDefaults] objectForKey:@"soundFile"]];
    }
    
    [self.contentView addSubview:soundMenu];
    
    // startup options label
    NSTextField *startupLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-355, 180, 30)];
    [startupLabel setStringValue:@"Startup:"];
    [startupLabel setEditable:NO];
    [startupLabel setBezeled:NO];
    [startupLabel setBackgroundColor:[NSColor clearColor]];
    [startupLabel setAlignment:kCTTextAlignmentRight];
    [startupLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:startupLabel];
    
    // check button to launch the app on login or not
    NSButton *launchLogin = [[NSButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-350, 250, 30)];
    [launchLogin setButtonType:NSSwitchButton];
    [launchLogin setTitle:@"Launch at login"];
    [launchLogin setAction:@selector(toggleLaunchLogin:)];
    [self setStateForButton:launchLogin withSetting:@"launchLogin"];
    [self.contentView addSubview:launchLogin];

}

// sets the button state to on or off based on NSUserDefautls result
- (void)setStateForButton:(NSButton *)button withSetting:(NSString *)setting {
    if([[NSUserDefaults standardUserDefaults] boolForKey:setting]) {
        [button setState:NSOnState];
    } else {
        [button setState:NSOffState];
    }
}

// toggle auotupload on and off, switches the screenshot query on/off.
- (IBAction)toggleAutoUpload:(id)sender {
    NSButton *button = (NSButton *)sender;
    DVNTAppDelegate *delegate = [NSApp delegate];
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"autoUpload"];
        [delegate doScreenshotQuery:YES];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"autoUpload"];
         [delegate doScreenshotQuery:NO];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// toggle deletion of screenshtos after upload
- (IBAction)toggleDeleteAfterUpload:(id)sender {
    NSButton *button = (NSButton *)sender;
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"deleteAfterUpload"];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"deleteAfterUpload"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// toggle copying of the items link to the clipboard after upload
- (IBAction)toggleCopyLink:(id)sender {
    NSButton *button = (NSButton *)sender;
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"copyLink"];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"copyLink"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// toggle showing the ntoification after upload
- (IBAction)toggleShowNotification:(id)sender {
    NSButton *button = (NSButton *)sender;
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"showNotification"];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"showNotification"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// toggle sound playing on upload
- (IBAction)toggleSound:(id)sender {
    NSButton *button = (NSButton *)sender;
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"playSound"];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"playSound"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// change the sound set via the menu
- (IBAction)changedSound:(id)sender {
    NSPopUpButton *soundMenu = (NSPopUpButton *)sender;
    [[NSSound soundNamed:soundMenu.selectedItem.title] play];
    [[NSUserDefaults standardUserDefaults] setObject:soundMenu.selectedItem.title forKey:@"soundFile"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// toggle launch on login
- (IBAction)toggleLaunchLogin:(id)sender {
    NSButton *button = (NSButton *)sender;
    DVNTAppDelegate *delegate = [NSApp delegate];
    
    if(button.state == NSOnState) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"launchLogin"];
        [delegate launchOnLogin:YES];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"launchLogin"];
        [delegate launchOnLogin:NO];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Select Update Tab
- (IBAction)selectUpdate:(id)sender {
    // clear out the old subviews
    [self clearSubviews];
    
    // set the current view tag to 2
    self.currentViewTag = 2;
    
    // is showing the updater view
    self.isShowingUpdater = YES;
    
    // resize the window
    [self resizeWindow:210];
    
    // check for updates label
    NSTextField *checkUpdatesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-130, 180, 30)];
    [checkUpdatesLabel setStringValue:@"Check for Updates:"];
    [checkUpdatesLabel setEditable:NO];
    [checkUpdatesLabel setBezeled:NO];
    [checkUpdatesLabel setBackgroundColor:[NSColor clearColor]];
    [checkUpdatesLabel setAlignment:kCTTextAlignmentRight];
    [checkUpdatesLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:checkUpdatesLabel];
    
    // options to choose from
    NSArray *options = @[@"Automatically", @"Manually"];
    
    // menu to drop down
    NSPopUpButton *optionsMenu = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(195, self.frame.size.height-125, 170, 30) pullsDown:NO];
    [optionsMenu setAction:@selector(changedUpdateOptions:)];
    [optionsMenu addItemsWithTitles:options];
    
    // set the default option of the menu when shown
    if([[SUUpdater sharedUpdater] automaticallyChecksForUpdates]) {
        [optionsMenu selectItemWithTitle:@"Automatically"];
    } else {
        [optionsMenu selectItemWithTitle:@"Manually"];
    }
    
    [self.contentView addSubview:optionsMenu];
    
    // button to allow force checking for udpates
    NSButton *checkUpdateButton = [[NSButton alloc] initWithFrame:NSMakeRect((self.frame.size.width-110)/2, self.frame.size.height-165, 110, 30)];
    [checkUpdateButton setTitle:@"Check Now"];
    [checkUpdateButton setButtonType:NSMomentaryPushInButton];
    [checkUpdateButton setBezelStyle:NSRoundedBezelStyle];
    [checkUpdateButton setAction:@selector(checkForUpdate:)];
    [self.contentView addSubview:checkUpdateButton];
    
    // label for showing the last time it was checked
    NSTextField *lastCheckLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-205, self.frame.size.width, 30)];
    
    NSDate *lastCheckDate = [[SUUpdater sharedUpdater] lastUpdateCheckDate];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMMM dd, yyyy H:mm a"];
    
    NSString *dateString = [dateFormatter stringFromDate:lastCheckDate];
    
    [lastCheckLabel setStringValue:[NSString stringWithFormat:@"Last Checked: %@", dateString]];
    [lastCheckLabel setEditable:NO];
    [lastCheckLabel setBezeled:NO];
    [lastCheckLabel setBackgroundColor:[NSColor clearColor]];
    [lastCheckLabel setTextColor:[NSColor lightGrayColor]];
    [lastCheckLabel setAlignment:kCTTextAlignmentCenter];
    [lastCheckLabel setFont:[NSFont systemFontOfSize:11]];
    [self.contentView addSubview:lastCheckLabel];
}


// set the update option
- (IBAction)changedUpdateOptions:(id)sender {
    NSPopUpButton *soundMenu = (NSPopUpButton *)sender;
    
    // no = manually, yes = auto
    BOOL updateOption = NO;
    if([soundMenu.selectedItem.title isEqualToString:@"Automatically"]) {
        updateOption = YES;
    }
    
    [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:updateOption];
}

// check for updates using Sparkle
- (IBAction)checkForUpdate:(id)sender {
    [[SUUpdater sharedUpdater] checkForUpdates:nil];
}

// Select About Tab
- (IBAction)selectAbout:(id)sender {
    // clear out the old subviews
    [self clearSubviews];
    
    // set the current view tag to 2
    self.currentViewTag = 3;
    
    // resize the window
    [self resizeWindow:210];
    
    // app title
    NSTextField *textLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-130, self.frame.size.width, 30)];
    [textLabel setStringValue:@"Sta.sh for Mac"];
    [textLabel setEditable:NO];
    [textLabel setBezeled:NO];
    [textLabel setBackgroundColor:[NSColor clearColor]];
    [textLabel setAlignment:kCTTextAlignmentCenter];
    [textLabel setFont:[NSFont systemFontOfSize:13]];
    [self.contentView addSubview:textLabel];
    
    // label for build and version numbers
    NSTextField *versionLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-152, self.frame.size.width, 30)];
    
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    
    [versionLabel setStringValue:[NSString stringWithFormat:@"Version %@ (Build %@)", version, build]];
    [versionLabel setEditable:NO];
    [versionLabel setBezeled:NO];
    [versionLabel setBackgroundColor:[NSColor clearColor]];
    [versionLabel setTextColor:[NSColor lightGrayColor]];
    [versionLabel setAlignment:kCTTextAlignmentCenter];
    [versionLabel setFont:[NSFont systemFontOfSize:11]];
    [self.contentView addSubview:versionLabel];
    
    // copyright to dA.
    NSTextField *copyrightLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, self.frame.size.height-169, self.frame.size.width, 30)];
    
    // get the current year
    NSDate *today = [NSDate date];
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:(NSYearCalendarUnit) fromDate:today];
    NSInteger year = [components year];
    
    [copyrightLabel setStringValue:[NSString stringWithFormat:@"Copyright ©%ld deviantART", (long)year]];
    [copyrightLabel setEditable:NO];
    [copyrightLabel setBezeled:NO];
    [copyrightLabel setBackgroundColor:[NSColor clearColor]];
    [copyrightLabel setTextColor:[NSColor lightGrayColor]];
    [copyrightLabel setAlignment:kCTTextAlignmentCenter];
    [copyrightLabel setFont:[NSFont systemFontOfSize:11]];
    [self.contentView addSubview:copyrightLabel];
    
    // button to open the dA website
    NSButton *websiteButton = [[NSButton alloc] initWithFrame:NSMakeRect((self.frame.size.width-110)/2, self.frame.size.height-194, 110, 30)];
    [websiteButton setTitle:@"View Website"];
    [websiteButton setButtonType:NSMomentaryPushInButton];
    [websiteButton setBezelStyle:NSRoundedBezelStyle];
    [websiteButton setAction:@selector(visitWebsite:)];
    [self.contentView addSubview:websiteButton];

}

// opens the dA website
- (IBAction)visitWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://deviantart.com/"]];
}

// clears out the old subviews and sets false to showing the updater view
- (void)clearSubviews {
    self.isShowingUpdater = NO;
    [self.contentView setSubviews:[NSArray array]];
}


// computes difference in window height and keeps window pinned in top of left when changing height.
- (void)resizeWindow:(NSInteger)height {
    NSRect frame = self.frame;
    
    NSInteger currentHeight = self.frame.size.height;
    
    NSInteger difference = height-currentHeight;
    
    frame.origin.y -= difference;
    frame.size.height += difference;
    
    [self setFrame:frame display:YES animate:YES];
}

@end
