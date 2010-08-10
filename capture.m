//
//  capture.m
//  Mirror
//
//  Created by Aldrin Martoq on 7/27/10.
//  Copyright 2010 Aldrin Martoq. Source code licensed under the "MIT" License.
//	This code is based on Apple's glGrab.c and it fullfils the original license.
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

#import "capture.h"



#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>

/*
 * perform an in-place swap from Quadrant 1 to Quadrant III format
 * (upside-down PostScript/GL to right side up QD/CG raster format)
 * We do this in-place, which requires more copying, but will touch
 * only half the pages.  (Display grabs are BIG!)
 *
 * Pixel reformatting may optionally be done here if needed.
 */
static void swizzleBitmap(void * data, int rowBytes, int height)
{
    int top, bottom;
    void * buffer;
    void * topP;
    void * bottomP;
    void * base;
	
    top = 0;
    bottom = height - 1;
    base = data;
    buffer = malloc(rowBytes);
	
    while (top < bottom)
    {
        topP = (void *)((top * rowBytes) + (intptr_t)base);
        bottomP = (void *)((bottom * rowBytes) + (intptr_t)base);
		
        /*
		 * Save and swap scanlines.
		 *
		 * This code does a simple in-place exchange with a temp
		 buffer.
		 * If you need to reformat the pixels, replace the first two
		 bcopy()
		 * calls with your own custom pixel reformatter.
		 */
        bcopy(topP, buffer, rowBytes);
        bcopy(bottomP, topP, rowBytes);
        bcopy(buffer, bottomP, rowBytes);
		
        ++top;
        --bottom;
    }
    free(buffer);
}

/*
 * Given a display ID and a rectangle on that display, generate a
 CGImageRef
 * containing the display contents.
 *
 * srcRect is display-origin relative.
 *
 * This function uses a full screen OpenGL read-only context.
 * By using OpenGL, we can read the screen using a DMA transfer
 * when it's in millions of colors mode, and we can correctly read
 * a microtiled full screen OpenGL context, such as a game or full
 * screen video display.
 *
 * Returns a CGImageRef.  When you are done with the CGImageRef,
 release it
 * using CFRelease().
 * Returns NULL on an error.
 */
CGImageRef grabViaOpenGL(CGDirectDisplayID display, CGRect srcRect)
{
    CGContextRef    bitmap;
    CGImageRef        image;
    void *            data;
    long            bytewidth;
    GLint            width, height;
	//long            bytes;
    CGColorSpaceRef cSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	
    CGLContextObj    glContextObj;
    CGLPixelFormatObj pixelFormatObj ;
    GLint numPixelFormats ;
    CGLPixelFormatAttribute attribs[] =
    {
        kCGLPFAFullScreen,
        kCGLPFADisplayMask,
        0,    /* Display mask bit goes here */
        0
    } ;
	
    if (display == kCGNullDirectDisplay)
        display = CGMainDisplayID();
    attribs[2] = CGDisplayIDToOpenGLDisplayMask(display);
	
    /* Build a full-screen GL context */
    CGLChoosePixelFormat(attribs, &pixelFormatObj, &numPixelFormats);
    if (pixelFormatObj == NULL) {
		CFRelease(cSpace);
		// No full screen context support
        return NULL;
	}
    CGLCreateContext(pixelFormatObj, NULL, &glContextObj);
    CGLDestroyPixelFormat(pixelFormatObj);
    if (glContextObj == NULL) {
		CFRelease(cSpace);
        return NULL;
	}
	
	CGLSetCurrentContext(glContextObj);
	CGLSetFullScreen(glContextObj);
	
	
    glReadBuffer(GL_FRONT);
	
    width = srcRect.size.width;
    height = srcRect.size.height;
	
    bytewidth = width * 4;                // Assume 4 bytes/pixel for now
	bytewidth = (bytewidth + 3) & ~3;    // Align to 4 bytes
    //bytes = bytewidth * height;            // width * height
	
    /* Build bitmap context */
    data = malloc(height * bytewidth);
    if ( data == NULL )
    {
		CFRelease(cSpace);
        CGLSetCurrentContext(NULL);
        CGLClearDrawable(glContextObj);    // disassociate from full screen
        CGLDestroyContext(glContextObj);    // and destroy the context
        return NULL;
    }
    bitmap = CGBitmapContextCreate(data, width, height, 8, bytewidth,
								   cSpace,
								   kCGImageAlphaNoneSkipFirst /* XRGB */);
    CFRelease(cSpace);
	
    /* Read framebuffer into our bitmap */
    glFinish();                /* Finish all OpenGL commands */
    glPixelStorei(GL_PACK_ALIGNMENT, 4);    /* Force 4-byte
											 alignment */
    glPixelStorei(GL_PACK_ROW_LENGTH, 0);
    glPixelStorei(GL_PACK_SKIP_ROWS, 0);
    glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
	
    /*
	 * Fetch the data in XRGB format, matching the bitmap context.
	 */
    glReadPixels((GLint)srcRect.origin.x, (GLint)srcRect.origin.y,
				 width, height,
				 GL_BGRA,
				 //				 GL_UNSIGNED_INT_8_8_8_8_REV,
				 GL_UNSIGNED_INT_8_8_8_8,
				 data);
    /*
	 * glReadPixels generates a quadrant I raster, with origin in
	 the lower left
	 * This isn't a problem for signal processing routines such as
	 compressors,
	 * as they can simply use a negative 'advance' to move between
	 scanlines.
	 * CGImageRef and CGBitmapContext assume a quadrant III raster,
	 though, so we need to
	 * invert it.  Pixel reformatting can also be done here.
	 */
    swizzleBitmap(data, bytewidth, height);
	
    /* Make an image out of our bitmap; does a cheap vm_copy of the
	 bitmap */
    image = CGBitmapContextCreateImage(bitmap);
	
    /* Get rid of bitmap */
    CFRelease(bitmap);
    free(data);
	
    /* Get rid of GL context */
    CGLSetCurrentContext(NULL);
    CGLClearDrawable(glContextObj);    // disassociate from full screen
    CGLDestroyContext(glContextObj);    // and destroy the context
	
    /* Returned image has a reference count of 1 */
    return image;
}