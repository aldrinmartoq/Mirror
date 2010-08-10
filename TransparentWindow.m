//
//  TransparentWindow.m
//  Mirror
//
//  Created by Aldrin Martoq on 8/10/10.
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

#import "TransparentWindow.h"

@implementation TransparentView

- (void) setRect:(NSRect)newRect {
	// draw only if changed
	if (NSEqualRects(rect, newRect)) {
		return;
	}
	NSLog(@"DRAWING");
	rect = newRect;
	[[self window] display];
}

- (void) drawRect:(NSRect)dirtyRect {
	// clear
	[[NSColor blackColor] set];
	NSRectFill([self frame]);
	[[NSColor clearColor] set];
	NSRectFill(rect);
	
	float border = 6.0;
	NSRect r = rect;
	r.origin.x -= border;
	r.origin.y -= border;
	r.size.width += border*2;
	r.size.height += border*2;
	
	[[NSColor redColor] set];
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:border];
	[path appendBezierPathWithRoundedRect:r xRadius:border yRadius:border];
	[path stroke];
}

@end


@implementation TransparentWindow

- (id)initWithContentRect:(NSRect)contentRect {
	self = [super initWithContentRect:contentRect
							styleMask:NSBorderlessWindowMask 
							  backing:NSBackingStoreBuffered
								defer:NO];
	if (self) {
		[self setBackgroundColor:[NSColor blackColor]];
		[self setAlphaValue:0.3];
		[self setOpaque:NO];
		[self setHasShadow:NO];
		
		[self setReleasedWhenClosed:YES];
		[self setHidesOnDeactivate:NO];
		[self setCanHide:NO];
		[self setIgnoresMouseEvents:YES];
		[self setLevel:NSScreenSaverWindowLevel];
		
		[self setContentView:[[TransparentView alloc] init]];
	}
	return self;
}

- (void)setRect:(NSRect) aRect {
	[[self contentView] setRect:aRect];
}

+ (TransparentWindow *) windowForMainScreen {
	NSRect mainScreenRect = [[NSScreen mainScreen] frame];
	TransparentWindow *transparentWindow = [[self alloc] initWithContentRect:mainScreenRect];
	
	return [transparentWindow autorelease];
}

@end
