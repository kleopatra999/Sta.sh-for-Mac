//
//  DVNTDragStatusItem.h
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 15/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// enum for images
typedef enum {
    DVNTDragStatusItemDefault,
    DVNTDragStatusItemOffline,
    DVNTDragStatusItemUploading,
    DVNTDragStatusItemHighlighted
} DVNTDragStatusItemStatus;


@interface DVNTDragStatusItem : NSView <NSMenuDelegate>

// Sets the status of the item, swaps image and current mode
- (void)setStatus:(DVNTDragStatusItemStatus)status;

// The status item that this view is contained within
@property (nonatomic) NSStatusItem *statusItem;

@end
