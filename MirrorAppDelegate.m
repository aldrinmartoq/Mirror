//
//  MirrorAppDelegate.m
//  Mirror
//
//  Created by Aldrin Martoq on 7/27/10.
//  Copyright 2010 Aldrin Martoq. All rights reserved.
//

#import "MirrorAppDelegate.h"
#import "capture.h"

@implementation MirrorAppDelegate

@synthesize windowList;

static NSColor *black = nil;
static NSColor *white = nil;
static NSImage *desktopImage = nil;

static CGFloat border = 30.0;
static CGFloat textSize = 20.0;

static NSFont *textFont = nil;
static NSColor *textColor = nil;
static NSDictionary *textAttrs = nil;

static NSUInteger oldMirrorWindowStyle = 0;
static NSRect oldMirrorWindowFrame;

+ (void)initialize {
	black = [[NSColor blackColor] retain];
	white = [[NSColor whiteColor] retain];
	desktopImage = [NSImage imageNamed:@"Desktop.png"];
	
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
	[style setAlignment:NSCenterTextAlignment];
	textFont = [[NSFont boldSystemFontOfSize:textSize] retain];
	textColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.8] retain];
	textAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
				 textFont, NSFontAttributeName,
				 textColor, NSForegroundColorAttributeName,
				 style, NSParagraphStyleAttributeName,
				 nil];	
}


- (void) capture:(NSTimer*)timer {	
	CGWindowListOption listOption = kCGWindowListOptionIncludingWindow; 
	CGWindowImageOption imageOption = kCGWindowImageDefault;
	if ([defaults boolForKey:@"ignoreFraming"]) {
		imageOption |= kCGWindowImageBoundsIgnoreFraming;
	}
	if ([defaults boolForKey:@"includeWindowsAbove"]) {
		listOption |= kCGWindowListOptionOnScreenAboveWindow;
	}
	
//	CGImageRef imageRef = CGWindowListCreateImage(windowBounds, listOption, windowID, imageOption);
	
	CGDirectDisplayID display = kCGNullDirectDisplay;
	CGRect srcRect;
	srcRect.origin.x = 0;
	srcRect.origin.y = 0;
	srcRect.size.width = 1680;
	srcRect.size.height = 1050;
	
	CGImageRef imageRef = grabViaOpenGL(display, srcRect);
	if (imageRef != NULL) {
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
		
		if (1) {
			NSSize bitmapSize = [bitmap size];
			NSScreen *mainScreen = [NSScreen mainScreen];
			NSRect mainScreenFrame = [mainScreen frame];
			NSPoint mouse = [NSEvent mouseLocation];
			
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
			
			NSUInteger pressed = [NSEvent pressedMouseButtons];
			if (pressed == 0) {
				[[NSColor colorWithCalibratedWhite:0.7 alpha:0.4] setFill];
			} else {
				[[NSColor redColor] setFill];
			}
			NSRect rect;
			rect.size.width = 40;
			rect.size.height = 40;
			rect.origin.x = (mouse.x - windowBounds.origin.x - rect.size.width / 2) * windowBounds.size.width / bitmapSize.width;
			rect.origin.y = bitmapSize.height - (mainScreenFrame.size.height - mouse.y - windowBounds.origin.y + rect.size.height / 2) * windowBounds.size.height / bitmapSize.height;
			
			NSBezierPath *path = [NSBezierPath bezierPath];
			[path appendBezierPathWithOvalInRect:rect];
			
			[path stroke];
			[path fill];
			[NSGraphicsContext restoreGraphicsState];
		}
		NSImage *image = [[NSImage alloc] init];
		[image addRepresentation:bitmap];
		[mirrorImageDesktop setImage:image];
		[image release];
		[bitmap release];
	}
	
	CGImageRelease(imageRef);
}

- (IBAction) updateApplicationList:(id)sender {
//	self.windowList = (NSArray *)CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
	
	CFArrayRef list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
	NSMutableArray *arr = [NSMutableArray array];
	for (NSDictionary *entry in (NSArray *)list) {
		NSString *winName = [entry valueForKey:(id)kCGWindowName];
		NSString *appName = [entry valueForKey:(id)kCGWindowOwnerName];
		if (winName != nil && ![winName isEqual:@""] && ![appName isEqual:@""]) {
			NSMutableDictionary *newEntry = [NSMutableDictionary dictionaryWithDictionary:entry];
			[newEntry setValue:[NSString stringWithFormat:@"%@/%@",appName,winName] forKey:(id)kCGWindowName];
			[arr addObject:newEntry];
		} else {
			NSLog(@"omitted: %@", entry);
//			NSLog(@"omitted: [%@]\t\t[%@]", appName, winName);
		}
	}
	CFRelease(list);
	self.windowList = arr;
}


- (void)resetCapture {
	int hztable[5] = {5,10,15,20,30};
	NSInteger f = [defaults integerForKey:@"captureFrequency"];
	if (f < 0 || f > 4) {
		return;
	}
	int hz = hztable[f];
	NSLog(@"CAPTURE FREQUENCY: %d Hz", hz);
	
	[captureTimer invalidate];
	captureTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
											interval:1.0/hz
											  target:self
											selector:@selector(capture:)
											userInfo:nil
											 repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:captureTimer forMode:NSDefaultRunLoopMode];	
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqual:@"captureFrequency"]) {
		[self resetCapture];
	} else {
		NSDictionary *entry = [object selection];
		NSLog(@"selected: %@", entry);
		NSNumber *winID = [entry valueForKey:@"kCGWindowNumber"];
		NSDictionary *bounds = [entry valueForKey:@"kCGWindowBounds"];
		if (winID != nil) {
			windowID = [winID intValue];
			windowBounds.origin.x = [[bounds valueForKey:@"X"] intValue];
			windowBounds.origin.y = [[bounds valueForKey:@"Y"] intValue];
			windowBounds.size.width = [[bounds valueForKey:@"Width"] intValue];
			windowBounds.size.height = [[bounds valueForKey:@"Height"] intValue];
		}
	}
}

- (IBAction) toggleMirrorWindowStyle:(id)sender {
	if ([mirrorWindow styleMask] == NSBorderlessWindowMask) {
		[mirrorWindow setStyleMask:oldMirrorWindowStyle];
		[mirrorWindow setFrame:oldMirrorWindowFrame display:YES animate:NO];
	} else {
		oldMirrorWindowStyle = [mirrorWindow styleMask];
		oldMirrorWindowFrame = [mirrorWindow frame];
		[mirrorWindow setStyleMask:NSBorderlessWindowMask];
		[mirrorWindow setFrame:oldMirrorWindowFrame display:YES animate:YES];
	}
}

- (void) drawFrame {
	NSRect frameBounds = [mirrorImageFrame frame];
	CGFloat w = frameBounds.size.width;
	CGFloat h = frameBounds.size.height;
	NSImage *image = [[NSImage alloc] initWithSize:frameBounds.size];
	[image lockFocus];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	// clean
	NSRectFill(NSMakeRect(0, 0, w, h));
	
	// draw background
	[desktopImage drawInRect:NSMakeRect(border + 1, border + 1, w - border * 2 - 2, h - border * 2 - 2)
					fromRect:NSZeroRect
				   operation:NSCompositeSourceOver
					fraction:0.8];
	
	// draw frame text
	NSString *text = [defaults stringForKey:@"defaultFrameText"];
	[text drawWithRect:NSMakeRect(border, (border - textSize) / 2, w - border * 2, 0)
			   options:NSStringDrawingUsesLineFragmentOrigin
			attributes:textAttrs];
	
	// draw frame
	[white setStroke];
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:2.0];
	[path appendBezierPathWithRoundedRect:NSMakeRect(2, 2, w - 4, h - 4)
								  xRadius:border
								  yRadius:border];
	[path setLineWidth:1.0];
	[path appendBezierPathWithRect:NSMakeRect(border, border, w - border * 2, h - border * 2)];
	[path stroke];
	
	[image unlockFocus];
	[mirrorImageFrame setImage:image];
	
	// resize desktop imageview
	[mirrorImageDesktop setFrame:NSMakeRect(border + 1, border + 1, w - border * 2 - 2, h - border * 2 - 2)];
}

- (void)windowDidResize:(NSNotification *)notification {
	[self drawFrame];
	NSLog(@"Did resize");
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"1", @"captureFrequency",
								 @"NO", @"includeWindowsAbove",
								 @"NO", @"ignoreFraming",
								 @"Mirror by @aldrinmartoq", @"defaultFrameText",
								 nil];
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:appDefaults];
	[defaults synchronize];
	[defaults addObserver:self forKeyPath:@"captureFrequency" options:NSKeyValueObservingOptionNew context:NULL];
	
//	[mirrorWindow setBackgroundColor:[NSColor blackColor]];
//	[mirrorWindow zoom:nil];

	[self drawFrame];

	[windowListController addObserver:self forKeyPath:@"selection" options:(NSKeyValueObservingOptionNew |
																			NSKeyValueObservingOptionOld) context:NULL];
	[self updateApplicationList:nil];
	[self resetCapture];
}

@end
