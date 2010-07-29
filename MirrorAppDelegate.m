//
//  MirrorAppDelegate.m
//  Mirror
//
//  Created by Aldrin Martoq on 7/27/10.
//  Copyright 2010 Aldrin Martoq. Source code licensed under the "MIT" License.
//
/*
 Copyright (c) 2010 Aldrin Martoq <aldrin@martoq.cl>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "MirrorAppDelegate.h"
#import "capture.h"
#import <Carbon/Carbon.h>

@implementation MirrorAppDelegate

@synthesize windowList;

static NSColor *black = nil;
static NSColor *white = nil;
static NSColor *gray = nil;
static NSColor *red = nil;
static NSImage *desktopImage = nil;

static CGFloat textSize = 20.0;

static NSFont *textFont = nil;
static NSColor *textColor = nil;
static NSDictionary *textAttrs = nil;

static NSUInteger oldMirrorWindowStyle = 0;
static NSRect oldMirrorWindowFrame;

static MirrorAppDelegate* appDelegate;

OSStatus hotkeyHandler(EventHandlerCallRef nextHandler, EventRef eventRef, void *userData) {
	EventHotKeyID hkCom;
	GetEventParameter(eventRef, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkCom), NULL, &hkCom);
	switch (hkCom.id) {
		case 1:
			[appDelegate toggleAppZoom];
			break;
	}
	
	return noErr;
}

+ (void)initialize {
	black = [[NSColor blackColor] retain];
	white = [[NSColor whiteColor] retain];
	gray = [[NSColor colorWithCalibratedWhite:0.7 alpha:0.4] retain];
	red = [[NSColor redColor] retain];
	desktopImage = [NSImage imageNamed:@"Desktop.png"];
	
	textColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.8] retain];
	EventTypeSpec eventType;
	eventType.eventClass = kEventClassKeyboard;
	eventType.eventKind = kEventHotKeyPressed;
	InstallApplicationEventHandler(&hotkeyHandler, 1, &eventType, NULL, NULL);
	
	EventHotKeyRef hotKeyRef;
	EventHotKeyID hotKeyID;
	
	hotKeyID.signature='htk1';
	hotKeyID.id = 1;
	
	RegisterEventHotKey(49, controlKey+optionKey+cmdKey, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef);
}


- (void) capture:(NSTimer*)timer {
	// obtain display and shot sizes
	CGDirectDisplayID mainDisplay = CGMainDisplayID();
	CGRect maindisplayBounds = CGDisplayBounds(mainDisplay);
	NSPoint mousePos = [NSEvent mouseLocation];
	NSUInteger mouseBut = [NSEvent pressedMouseButtons];
	CGRect rect;
	
	if (currentAppTitle == nil) {
		rect = maindisplayBounds;
	} else {
		rect = captureRect;
	}
	if (zoomLevel > 0) {
		rect.size.width = maindisplayBounds.size.width / zoomLevel;
		rect.size.height = maindisplayBounds.size.height / zoomLevel;
		if (mousePos.x < rect.origin.x)
			rect.origin.x = mousePos.x;
		if (mousePos.x > (rect.origin.x + rect.size.width))
			rect.origin.x = mousePos.x - rect.size.width;
		if (mousePos.y < rect.origin.y)
			rect.origin.y = mousePos.y;
		if (mousePos.y > (rect.origin.y + rect.size.height))
			rect.origin.y = mousePos.y - rect.size.height;
	}
	
	// capture screen image via OpenGL
	CGImageRef imageRef = grabViaOpenGL(mainDisplay, rect);
	
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
		CGFloat x = (mousePos.x - rect.origin.x - border / 2);
		CGFloat y = mousePos.y - rect.origin.y - border / 2;
		
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

- (void) toggleAppZoom {
	[currentAppTitle release];
	currentAppTitle = nil;
	NSPoint mousePos = [NSEvent mouseLocation];
	CFArrayRef list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
	for (NSDictionary *entry in (NSArray *)list) {
		NSString *winName = [entry valueForKey:(id)kCGWindowName];
		NSString *appName = [entry valueForKey:(id)kCGWindowOwnerName];
		NSDictionary *bounds = [entry valueForKey:(id)kCGWindowBounds];
		NSLog(@"%@ \t %@ %f %f \t%@", appName, winName, mousePos.x, mousePos.y, bounds);
		if (winName != nil && ![winName isEqual:@""] && ![appName isEqual:@""] && ![appName isEqual:@"Window Server"] && ![appName isEqual:@"Dock"] && ![appName isEqual:@"Mirror"]) {
			CGDirectDisplayID mainDisplay = CGMainDisplayID();
			CGRect maindisplayBounds = CGDisplayBounds(mainDisplay);
			captureRect.size.width = [[bounds valueForKey:@"Width"] floatValue];
			captureRect.size.height = [[bounds valueForKey:@"Height"] floatValue];
			captureRect.origin.x = [[bounds valueForKey:@"X"] floatValue];
			captureRect.origin.y = [[bounds valueForKey:@"Y"] floatValue];
			captureRect.origin.y = maindisplayBounds.size.height - captureRect.origin.y - captureRect.size.height;
			
			if (mousePos.x >= captureRect.origin.x && mousePos.x <= (captureRect.origin.x + captureRect.size.width) &&
				mousePos.y >= captureRect.origin.y && mousePos.y <= (captureRect.origin.y + captureRect.size.height)) {
				currentAppTitle = [appName retain];
				NSLog(@"capturerect: %@ %f %f", bounds, maindisplayBounds.size.height, captureRect.origin.y);
				break;
			}
		}
	}
	CFRelease(list);
	if (currentAppTitle != nil) {
		[mirrorImageDesktop setImageScaling:NSImageScaleProportionallyUpOrDown];
	} else {
		[mirrorImageDesktop setImageScaling:NSImageScaleAxesIndependently];
	}
	NSLog(@"Current App: %@", currentAppTitle);
	[self drawFrame];
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
	
	if (! [defaults boolForKey:@"capture"]) {
		return;
	}
	
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
	NSImage *image = [[[NSImage alloc] initWithSize:frameBounds.size] autorelease];
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
	NSString *text = (currentAppTitle != nil ? currentAppTitle : [defaults stringForKey:@"frameText"]);
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

- (void) checkBorder {
	border = [defaults floatForKey:@"border"];
	textSize = border * 2 / 3;
	NSLog(@"border: %f textSize: %f", border, textSize);
	
	NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	textFont = [NSFont boldSystemFontOfSize:textSize];
	textAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
				 textFont, NSFontAttributeName,
				 textColor, NSForegroundColorAttributeName,
				 style, NSParagraphStyleAttributeName,
				 nil];
	
	[self drawFrame];
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
		NSImage *image = [[[NSImage alloc] init] autorelease];
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
	} else if ([keyPath isEqual:@"border"]) {
		[self checkBorder];
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// setup app defaults and observe them
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"1", @"captureFrequency",
								 @"Mirror by @aldrinmartoq", @"frameText",
								 @"NO", @"capture",
								 @"NO", @"zoom",
								 @"1", @"zoomLevel",
								 @"30", @"border",
								 nil];
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:appDefaults];
	[defaults synchronize];
	for (NSString *keyPath in appDefaults) {
		[defaults addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	}
	
	// setup border, capturing, zoom, hotkey
	[self checkBorder];
	[self checkCapturing];
	[self checkZoom];
	appDelegate = self;
	
	//	[NSEvent addGlobalMonitorForEventsMatchingMask:NSMouseMovedMask
	//										   handler:^(NSEvent *event){
	//											   NSLog(@"event: %@", event);
	//										   }];
}

@end
