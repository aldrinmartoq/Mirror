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

static NSColor *black = nil;
static NSColor *white = nil;
static NSColor *gray = nil;
static NSColor *red = nil;
static NSImage *desktopImage = nil;

static CGFloat textSize = 20.0;
static CGFloat mouseSize = 25.0;
static NSFont *textFont = nil;
static NSColor *textColor = nil;
static NSDictionary *textAttrs = nil;

static NSUInteger oldMirrorWindowStyle = 0;
static NSInteger oldMirrorWindowLevel = 0;
static NSRect oldMirrorWindowFrame;

static MirrorAppDelegate* appDelegate;

OSStatus hotkeyHandler(EventHandlerCallRef nextHandler, EventRef eventRef, void *userData) {
	EventHotKeyID hkCom;
	GetEventParameter(eventRef, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkCom), NULL, &hkCom);
	switch (hkCom.id) {
		case 1:
			[appDelegate toggleFollowCurrentApplication];
			break;
	}
	
	return noErr;
}

OSStatus appFrontSwitchedHandler(EventHandlerCallRef inHandlerRef, EventRef eventRef, void *userData) {
	[appDelegate frontApplicationSwitched];
	return noErr;
}

+ (void)initialize {
	black = [[NSColor blackColor] retain];
	white = [[NSColor whiteColor] retain];
	gray = [[NSColor colorWithCalibratedWhite:0.7 alpha:0.4] retain];
	red = [[NSColor colorWithCalibratedRed:1.0
									 green:0.0
									  blue:0.0
									 alpha:0.6] retain];
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
	
	eventType.eventClass = kEventClassApplication;
	eventType.eventKind = kEventAppFrontSwitched;
	InstallApplicationEventHandler(NewEventHandlerUPP(appFrontSwitchedHandler), 1, &eventType, NULL, NULL);
}


- (void) capture:(NSTimer*)timer {
	// obtain display and shot sizes
	NSPoint mousePos = [NSEvent mouseLocation];
	NSUInteger mouseBut = [NSEvent pressedMouseButtons];
	CGDirectDisplayID mainDisplay = CGMainDisplayID();
	CGRect rect;
	
	// determine capture rect
	if (follow && currentAppRect.size.width > 0 && currentAppRect.size.height > 0) {
		rect = currentAppRect;
	} else {
		rect = CGDisplayBounds(mainDisplay);
	}
	
	// zoom the capture rect
	if (zoom) {
		float rax = rect.origin.x;
		float ray = rect.origin.y;
		float rbx = rax + rect.size.width;
		float rby = ray + rect.size.height;
		
		float w = rect.size.width / zoomlevel;
		float h = rect.size.height / zoomlevel;
		float ax = zoomPoint.x;
		float ay = zoomPoint.y;
		ax = (ax < rax ? rax : ax);
		ay = (ay < ray ? ray : ay);
		float bx = ax + w;
		float by = ay + h;
		float max = mousePos.x - mouseSize;
		float may = mousePos.y - mouseSize;
		float mbx = mousePos.x + mouseSize;
		float mby = mousePos.y + mouseSize;
		
		if (max < ax) {
			ax = (max < rax ? rax : max);
			bx = ax + w;
		}
		if (may < ay) {
			ay = (may < ray ? ray : may);
			by = ay + h;
		}
		if (mbx > bx) {
			bx = (mbx > rbx ? rbx : mbx);
			ax = bx - w;
		}
		if (mby > by) {
			by = (mby > rby ? rby : mby);
			ay = by - h;
		}
		
		zoomPoint.x = ax;
		zoomPoint.y = ay;
		rect.origin.x = ax;
		rect.origin.y = ay;
		rect.size.width = w;
		rect.size.height = h;
		NSLog(@"ax:%4.0f ay:%4.0f bx:%4.0f by:%4.0f h:%4.0f y:%4.0f", ax, ay, bx, by, h, rect.origin.y);
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
		CGFloat x = (mousePos.x - rect.origin.x - mouseSize / 2);
		CGFloat y = mousePos.y - rect.origin.y - mouseSize / 2;
		NSBezierPath *path = [NSBezierPath bezierPath];
		[path appendBezierPathWithOvalInRect:NSMakeRect(x, y, mouseSize, mouseSize)];
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
	
	if (follow) {
		captureCounter++;
		if (captureCounter > captureFrequency) {
			captureCounter = 0;
			[self followCurrentApplication];
		}
	}
}

- (void) toggleFollowCurrentApplication {
	[defaults setObject:(follow ? @"NO" : @"YES") forKey:@"follow"];
}

- (void) frontApplicationSwitched {
	NSDictionary *activeApp = [[NSWorkspace sharedWorkspace] activeApplication];
	NSString *appName = [activeApp valueForKey:@"NSApplicationName"];
	if ([blacklistedApps containsObject:appName]) {
		NSLog(@"switched to app: %@ (blacklisted)", appName);
	} else {
		[currentAppName release];
		currentAppName = [[activeApp valueForKey:@"NSApplicationName"] retain];
		NSLog(@"switched to app: %@", currentAppName);
		captureCounter = captureFrequency * 7/8;
	}
	if (follow) {
		[mirrorImageDesktop setImageScaling:NSImageScaleProportionallyUpOrDown];
	} else {
		[mirrorImageDesktop setImageScaling:NSImageScaleAxesIndependently];
	}
}

- (void) followCurrentApplication {
	/* assume main screen capture */ 
	CGDirectDisplayID mainDisplay = CGMainDisplayID();
	CGRect maindisplayBounds = CGDisplayBounds(mainDisplay);
	
	/* find biggest rect that contains all windows for current app */
	CFArrayRef winList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
	NSPoint a, b;
	BOOL found = NO;
	for (NSDictionary *entry in (NSArray *)winList) {
		// check app match current app name
		NSString *appName = [entry valueForKey:(id)kCGWindowOwnerName];
		if ([blacklistedApps containsObject:appName]) {
			continue;
		}
		// check win name is not empty
		NSString *winName = [entry valueForKey:(id)kCGWindowName];
		if (winName == nil || [winName length] == 0) {
			continue;
		}
		// check there is no window over our app
		if (![appName isEqual:currentAppName]) {
			break;
		}

		
		// retrieve window sizes
		NSDictionary *bounds = [entry valueForKey:(id)kCGWindowBounds];
		float w = [[bounds valueForKey:@"Width"] floatValue];
		float h = [[bounds valueForKey:@"Height"] floatValue];
		float ax = [[bounds valueForKey:@"X"] floatValue];
		float ay = [[bounds valueForKey:@"Y"] floatValue];
		float bx = ax + w;
		float by = ay + h;
		float max = maindisplayBounds.origin.x;
		float may = maindisplayBounds.origin.y;
		float mbx = max + maindisplayBounds.size.width;
		float mby = may + maindisplayBounds.size.height;
		
		// skip windows outside mainscreen
		if ((ax < max && bx < max) ||
			(ax > mbx && bx > mbx) ||
			(ay < may && by < may) ||
			(ay > mby && by > mby)) {
			continue;
		}
		ax = (ax < max ? max : ax);
		ay = (ay < may ? may : ay);
		bx = (bx > mbx ? mbx : bx);
		by = (by > mby ? mby : by);
				
		// capture all known windows
		if (! found) {
			a.x = ax;
			a.y = ay;
			b.x = bx;
			b.y = by;
			found = YES;
		} else {
			a.x = (ax < a.x ? ax : a.x);
			a.y = (ay < a.y ? ay : a.y);
			b.x = (bx > b.x ? bx : b.x);
			b.y = (by > b.y ? by : b.y);
		}
	}
	
	if (found) {
		currentAppRect.origin.x = a.x;
		currentAppRect.origin.y = maindisplayBounds.size.height - b.y;
		currentAppRect.size.width = b.x - a.x;
		currentAppRect.size.height = b.y - a.y;
		[mirrorImageDesktop setImageScaling:NSImageScaleProportionallyUpOrDown];
	} else {
		currentAppRect = maindisplayBounds;
		[mirrorImageDesktop setImageScaling:NSImageScaleAxesIndependently];
	}
	CFRelease(winList);
}

- (void)applyChangesFrequency {
	if (! [defaults boolForKey:@"capture"]) {
		return;
	}
	
	int hztable[5] = {5,10,15,20,24};
	NSInteger f = [defaults integerForKey:@"frequency"];
	if (f < 0 || f > 4) {
		return;
	}
	captureFrequency = hztable[f];
	NSLog(@"CAPTURE FREQUENCY: %d Hz", captureFrequency);
	
	captureCounter = 0;
	[captureTimer invalidate];
	captureTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
											interval:1.0/captureFrequency
											  target:self
											selector:@selector(capture:)
											userInfo:nil
											 repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:captureTimer forMode:NSDefaultRunLoopMode];	
}


- (void) mirrorWindowMoveToSecondaryDisplay:(CGRect)d {
	if (![mirrorWindow styleMask] != NSBorderlessWindowMask) {
		oldMirrorWindowStyle = [mirrorWindow styleMask];
		oldMirrorWindowFrame = [mirrorWindow frame];
		[mirrorWindow setStyleMask:NSBorderlessWindowMask];
		[mirrorWindow setFrame:NSMakeRect(d.origin.x, d.origin.y, d.size.width, d.size.height)
					   display:YES
					   animate:YES];
		[mirrorWindow setCanHide:NO];
		// this should avoid exposé on this window
		[mirrorWindow setLevel:kCGDesktopWindowLevelKey]; 
	}
}

- (void) mirrorWindowRestore {
	if ([mirrorWindow styleMask] == NSBorderlessWindowMask) {
		[mirrorWindow setLevel:oldMirrorWindowLevel];
		[mirrorWindow setStyleMask:oldMirrorWindowStyle];
		[mirrorWindow setFrame:oldMirrorWindowFrame
					   display:YES
					   animate:YES];
		[mirrorWindow setCanHide:YES];
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
	NSString *text = [defaults stringForKey:@"text"];
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

- (void) applyChangesAutoplace {
	[buttonAutoplace setEnabled:NO];
	
	CGError err = CGDisplayNoErr;
	CGDisplayCount displayCount = 0;
	
	err = CGGetActiveDisplayList(0, NULL, &displayCount);
	if (err != CGDisplayNoErr || displayCount <= 1) {
		NSLog(@"Error or displaycount: %d %d", err, displayCount);
		[self mirrorWindowRestore];
		return;
	}

	[buttonAutoplace setEnabled:YES];
	
	if (![defaults boolForKey:@"autoplace"]) {
		NSLog(@"Disabling autoplace...");
		[self mirrorWindowRestore];
		return;
	}
	
	CGDirectDisplayID displays[displayCount];
	err = CGGetActiveDisplayList(displayCount, displays, &displayCount);
	if (err != CGDisplayNoErr) return;
	CGDirectDisplayID mainDisplayID = CGMainDisplayID();
	for (int i = 0; i < displayCount; i++) {
		NSLog(@"display: %d", displays[i]);
		if (displays[i] == mainDisplayID) continue;
		CGRect d = CGDisplayBounds(displays[i]);
		CGRect m = CGDisplayBounds(mainDisplayID);
		d.origin.y = m.size.height - d.size.height;
		NSLog(@"Enabling autoplace on secondary display %d x: %f y: %f w: %f h: %f", displays[i], d.origin.x, d.origin.y, d.size.width, d.size.height);
		[self mirrorWindowMoveToSecondaryDisplay:d];
	}
}

- (void) applyChangesFollow {
	follow = [defaults boolForKey:@"follow"];
	[self frontApplicationSwitched];
	NSLog(@"follow: %d black list: %@", follow, blacklistedApps);
}

- (void) applyChangesBorder {
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

- (void) applyChangesText {
	[self drawFrame];
}

- (void) applyChangesCapture {
	BOOL capture = [defaults boolForKey:@"capture"];
	NSLog(@"capture: %d", capture);
	if (capture) {
		[self applyChangesFrequency];
	} else {
		[captureTimer invalidate];
		[captureTimer release];
		captureTimer = nil;
		NSImage *image = [[[NSImage alloc] init] autorelease];
		[mirrorImageDesktop setImage:image];
	}
}

- (void) applyChangesZoom {
	zoom = [defaults boolForKey:@"zoom"];
	NSLog(@"zoom %@ %1.1f x", (zoom ? @"YES":@"NO"), zoomlevel);
}

- (void) applyChangesZoomlevel {
	zoomlevel = [defaults floatForKey:@"zoomlevel"];
	NSLog(@"zoom %@ %1.1f x", (zoom ? @"YES":@"NO"), zoomlevel);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if ([keyPath isEqual:@"text"]) {
		[self applyChangesText];
	} else if ([keyPath isEqual:@"border"]) {
		[self applyChangesBorder];
	} else if ([keyPath isEqual:@"capture"]) {
		[self applyChangesCapture];
	} else if ([keyPath isEqual:@"frequency"]) {
		[self applyChangesFrequency];
	} else if ([keyPath isEqual:@"follow"]) {
		[self applyChangesFollow];
	} else if ([keyPath isEqual:@"autoplace"]) {
		[self applyChangesAutoplace];
	} else if ([keyPath isEqual:@"zoom"]) {
		[self applyChangesZoom];
	} else if ([keyPath isEqual:@"zoomlevel"]) {
		[self applyChangesZoomlevel];
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {	
	// setup blacklisted app names
	blacklistedApps = [[NSArray arrayWithObjects:@"Mirror", @"Dock", @"Window Server", nil] retain];
	
	// setup app defaults and observe them
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"Mirror by @aldrinmartoq", @"text",
								 @"30", @"border",
								 @"NO", @"capture",
								 @"1", @"frequency",
								 @"NO", @"zoom",
								 @"1.5", @"zoomlevel",
								 @"YES", @"autoplace",
								 @"NO", @"follow",
								 nil];
	defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:appDefaults];
	[defaults synchronize];
	for (NSString *keyPath in appDefaults) {
		[defaults addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	}
	
	// setup everything from defaults
	[self applyChangesAutoplace];
	[self applyChangesFollow];
	[self applyChangesBorder];
	[self applyChangesCapture];
	[self applyChangesZoom];
	[self applyChangesZoomlevel];
	
	// setup carbon delegate
	appDelegate = self;	
}

@end
