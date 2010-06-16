/* Copyright (c) 2010 Per Johansson, per at morth.org
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "MagickImageRep.h"
#import <AppKit/NSBitmapImageRep.h>

@implementation MagickImageRep

+ (void)load
{
	[self registerImageRepClass:self];
	MagickCoreGenesis([[[NSBundle mainBundle] bundlePath] fileSystemRepresentation], MagickFalse);
}

+ (BOOL)canInitWithData:(NSData *)data
{
	/* XXX check if there is a more efficient way to do this. */
	ExceptionInfo *exception = AcquireExceptionInfo();
	ImageInfo *info = CloneImageInfo(NULL);
	Image *image = BlobToImage(info, [data bytes], [data length], exception);
	
	if (image)
		DestroyImage(image);
	DestroyImageInfo(info);
	DestroyExceptionInfo(exception);
	
	return image ? YES : NO;
}

+ (id)imageRepWithData:(NSData*)data
{
	ExceptionInfo *exception = AcquireExceptionInfo();
	ImageInfo *info = CloneImageInfo(NULL);
	Image *image = BlobToImage(info, [data bytes], [data length], exception);
	
	if (!image)
	{
		DestroyExceptionInfo(exception);
		DestroyImageInfo(info);
		return nil;
	}
	
	strlcpy(image->magick, "rgba", sizeof (image->magick));
	
	size_t sz = 1024 * 1024; /* XXX arbitrary */
	unsigned char *blob = ImageToBlob(info, image, &sz, exception);
	
	if (!blob)
	{
		DestroyImage(image);
		DestroyImageInfo(info);
		DestroyExceptionInfo(exception);
		return nil;
	}
	
	NSBitmapImageRep *res = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&blob pixelsWide:image->columns pixelsHigh:image->rows bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:image->columns * 4 bitsPerPixel:8 * 4];
	//free(blob); XXX leaking memory here.
	
	DestroyImage(image);
	DestroyImageInfo(info);
	DestroyExceptionInfo(exception);
	return res;
}

@end
