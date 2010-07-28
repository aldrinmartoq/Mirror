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
static NSColor *gray = nil;
static NSColor *red = nil;
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
	gray = [[NSColor colorWithCalibratedWhite:0.7 alpha:0.4] retain];
	red = [[NSColor redColor] retain];
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
	// obtain display and shot sizes
	CGDirectDisplayID mainDisplay = CGMainDisplayID();
	CGRect maindisplayBounds = CGDisplayBounds(mainDisplay);
	NSPoint mousePos = [NSEvent mouseLocation];
	NSUInteger mouseBut = [NSEvent pressedMouseButtons];
	
	if (zoomLevel > 0) {
		captureRect.size.width = maindisplayBounds.size.width / zoomLevel;
		captureRect.size.height = maindisplayBounds.size.height / zoomLevel;
		if (mousePos.x < captureRect.origin.x)
			captureRect.origin.x = mousePos.x;
		if (mousePos.x > (captureRect.origin.x + captureRect.size.width))
			captureRect.origin.x = mousePos.x - captureRect.size.width;
		if (mousePos.y < captureRect.origin.y)
			captureRect.origin.y = mousePos.y;
		if (mousePos.y > (captureRect.origin.y + captureRect.size.height))
			captureRect.origin.y = mousePos.y - captureRect.size.height;
	} else {
		captureRect = maindisplayBounds;
	}
	
	// capture screen image via OpenGL
	CGImageRef imageRef = grabViaOpenGL(mainDisplay, captureRect);
	
	// convert and put into mirror image view
	if (imageRef != NULL) {
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
		
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
		
		// draw mouse circle
		if (mouseBut == 0) {
			[gray setFill];
		} else {
			[red setFill];
		}
		CGFloat x = (mousePos.x - captureRect.origin.x - border / 2);
		CGFloat y = mousePos.y - captureRect.origin.y - border / 2;
		
		NSBezierPath *path = [NSBezierPath bezierPath];
		[path appendBezierPathWithOvalInRect:NSMakeRect(x, y, border, border)];
		[path stroke];
		[path fill];
		[NSGraphicsContext restoreGraphicsState];
		
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


- (void)resetCaptureTimer {
	int hztable[5] = {5,10,15,30,60};
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
	NSString *text = [defaults stringForKey:@"frameText"];
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

- (void) checkCapturing {
	BOOL capture = [defaults boolForKey:@"capture"];
	NSLog(@"capture: %d", capture);
	if (capture) {
		[self resetCaptureTimer];
	} else {
		[captureTimer invalidate];
		[captureTimer release];
		captureTimer = nil;
		NSImage *image = [[NSImage alloc] init];
		[mirrorImageDesktop setImage:image];
	}
}

- (void) checkZoom {
	if (! [defaults boolForKey:@"zoom"]) {
		zoomLevel = 0.0;
	} else {
		zoomLevel = 1 + 0.5 * [defaults floatForKey:@"zoomLevel"];
	}
	NSLog(@"zoomLevel: %f", zoomLevel);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqual:@"captureFrequency"]) {
		[self resetCaptureTimer];
	} else if ([keyPath isEqual:@"frameText"]) {
		[self drawFrame];
	} else if ([keyPath isEqual:@"capture"]) {
		[self checkCapturing];
	} else if ([keyPath isEqual:@"zoom"] || [keyPath isEqual:@"zoomLevel"]) {
		[self checkZoom];
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"1", @"captureFrequency",
								 @"Mirror by @aldrinmartoq", @"frameText",
								 @"NO", @"capture",
								 @"NO", @"zoom",
								 @"1", @"zoomLevel",
								 nil];
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:appDefaults];
	[defaults synchronize];
	[defaults addObserver:self forKeyPath:@"captureFrequency" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"frameText" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"capture" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"zoom" options:NSKeyValueObservingOptionNew context:NULL];
	[defaults addObserver:self forKeyPath:@"zoomLevel" options:NSKeyValueObservingOptionNew context:NULL];

	[self drawFrame];
	[self checkCapturing];
	[self checkZoom];
}

@end
