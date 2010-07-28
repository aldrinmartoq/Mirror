//
//  MirrorAppDelegate.h
//  Mirror
//
//  Created by Aldrin Martoq on 7/27/10.
//  Copyright 2010 Aldrin Martoq. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MirrorAppDelegate : NSObject <NSApplicationDelegate> {
	IBOutlet NSWindow *mirrorWindow;
	IBOutlet NSImageView *mirrorImageFrame;
	IBOutlet NSImageView *mirrorImageDesktop;
	
	IBOutlet NSArrayController *windowListController;
	
	NSTimer *captureTimer;
	NSTimer *winlistTimer;
	
	NSArray *windowList;
	CGWindowID windowID;
	NSUserDefaults *defaults;
	NSArray *frequencies;
	CGRect windowBounds;
}

@property (retain) NSArray *windowList;

- (IBAction) updateApplicationList:(id)sender;
- (IBAction) toggleMirrorWindowStyle:(id)sender;

@end
