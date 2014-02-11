//
//  DVNTDragStatusItem.m
//  Sta.sh for Mac
//
//  Created by Aaron Pearce on 15/01/14.
//  Copyright (c) 2014 deviantART. All rights reserved.
//

#import "DVNTDragStatusItem.h"
#import "DVNTAppDelegate.h"

@interface DVNTDragStatusItem () {
}

@property (nonatomic) BOOL isDragging;
@property (nonatomic) BOOL isHighlighted;
@property (nonatomic) BOOL isUploading;
@property (nonatomic) BOOL isOffline;

@end
@implementation DVNTDragStatusItem

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //register for drags
        [self registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType, nil]];
    }
    
    return self;
}

// set the status of the item, switches the booleans to the right values then redraws
- (void)setStatus:(DVNTDragStatusItemStatus)status {
    // reset all bools
    self.isHighlighted = NO;
    self.isOffline = NO;
    self.isUploading = NO;
    
    // based on status, switch bools
    switch (status) {
        case DVNTDragStatusItemHighlighted:
            self.isHighlighted = YES;
            break;
        case DVNTDragStatusItemUploading:
            self.isUploading = YES;
            break;
        case DVNTDragStatusItemOffline:
            self.isOffline = YES;
            break;
        default:
            break;
    }
    
    // redraw so we get the new image
    [self setNeedsDisplay:YES];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    // if drag has entered the item's bounds we set isDragging to true and redraw
    self.isDragging = YES;
	[self setNeedsDisplay:YES];
    
    // return the drag operation and pasteboard if there is one.
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    NSDragOperation dragOperationMask = [sender draggingSourceOperationMask];
    
    if ( [[pasteboard types] containsObject:NSFilenamesPboardType] ) {
        if (dragOperationMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
	
	return NSDragOperationNone;
}

// if drawing ends, we set isDragging to false and redraw
- (void)draggingExited:(id <NSDraggingInfo>)sender {
	self.isDragging = NO;
	[self setNeedsDisplay:YES];
}

//
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    // drag has ended and we are performing the operation so we end it and redraw
	self.isDragging = NO;
	[self setNeedsDisplay:YES];
	
    // get the pasteboard and dragOperation
	NSPasteboard *pasteboard = [sender draggingPasteboard];
    NSDragOperation dragOperationMask = [sender draggingSourceOperationMask];
    
	// if pasteboard contains filenames, run upload
    if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
        // get the files
        NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
		
        // if the drag operation is correct, upload the files.
        if (dragOperationMask & NSDragOperationLink) {
			DVNTAppDelegate *delegate = [NSApp delegate];
            
            [delegate uploadFilesWithPaths:files folderName:@"Desktop Uploads"];
        }
    }
	
	return YES;
}

// mousedown and show the menu, redraw for this
- (void)mouseDown:(NSEvent *)event {
    [[self.statusItem menu] setDelegate:self];
    [self.statusItem popUpStatusItemMenu:[self.statusItem menu]];
    
	[self setNeedsDisplay:YES];
}

// right mouse does the same as left.
- (void)rightMouseDown:(NSEvent *)event {
    [self mouseDown:event];
}

// when menu opens we redraw to highlighted state
- (void)menuWillOpen:(NSMenu *)menu {
    self.isHighlighted = YES;
    [self setNeedsDisplay:YES];
}

// when clsoed we redraw to normal
- (void)menuDidClose:(NSMenu *)menu {
    self.isHighlighted = NO;
    [menu setDelegate:nil];
    [self setNeedsDisplay:YES];
}

// draw the correct image in the status bar
- (void)drawRect:(NSRect)rect {
    [self.statusItem drawStatusBarBackgroundInRect:[self bounds] withHighlight:self.isHighlighted];
	
	NSImage *image;
	NSRect rectangle = NSMakeRect(0,0,16,17);
	
    // get the right image for the current state
	if (self.isOffline) {
		image = [NSImage imageNamed:@"status-offline"];
	} else {
		if (self.isHighlighted) {
			image = [NSImage imageNamed:@"status-click"];
		} else {
			if (self.isUploading) {
				image = [NSImage imageNamed:@"status-uploading"];
				rectangle = NSMakeRect(0,0,21,17);
			} else if (self.isDragging) {
				image = [NSImage imageNamed:@"status-busy"];
			} else {
                image = [NSImage imageNamed:@"status-idle"];
			}
		}
	}
	
    // draw the image
	[image drawAtPoint:NSMakePoint(7, 2) fromRect:rectangle operation:NSCompositeSourceOver fraction:1.0];
}


@end
