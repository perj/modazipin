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
	[NSImageRep registerImageRepClass:[MagickImageRep self]];
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

+ (NSArray *)imageRepsWithData:(NSData *)data
{
	return [NSArray arrayWithObject:[self imageRepWithData:data]];
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
	
	size_t sz;
	unsigned char *blob = ImageToBlob(info, image, &sz, exception);
	
	if (!blob)
	{
		DestroyImage(image);
		DestroyImageInfo(info);
		DestroyExceptionInfo(exception);
		return nil;
	}
	
	unsigned char **blobs = malloc(sizeof(*blobs));
	if (!blobs)
	{
		RelinquishMagickMemory(blob);
		DestroyImage(image);
		DestroyImageInfo(info);
		DestroyExceptionInfo(exception);
		return nil;
	}
	
	*blobs = blob;
	
	MagickImageRep *res = [[MagickImageRep alloc] initWithBitmapDataPlanes:blobs pixelsWide:image->columns pixelsHigh:image->rows bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:image->columns * 4 bitsPerPixel:8 * 4];
	
	DestroyImage(image);
	DestroyImageInfo(info);
	DestroyExceptionInfo(exception);
	return res;
}

- (id)initWithBitmapDataPlanes:(unsigned char **)pns pixelsWide:(NSInteger)width pixelsHigh:(NSInteger)height bitsPerSample:(NSInteger)bps samplesPerPixel:(NSInteger)spp hasAlpha:(BOOL)alpha isPlanar:(BOOL)isPlanar colorSpaceName:(NSString *)colorSpaceName bytesPerRow:(NSInteger)rBytes bitsPerPixel:(NSInteger)pBits
{
	self = [super initWithBitmapDataPlanes:pns pixelsWide:width pixelsHigh:height bitsPerSample:bps samplesPerPixel:spp hasAlpha:alpha isPlanar:isPlanar colorSpaceName:colorSpaceName bytesPerRow:rBytes bitsPerPixel:pBits];
	if (self)
	{
		planes = pns;
		if (isPlanar)
			nplanes = spp;
		else
			nplanes = 1;
	}
	return self;
}

- (void)finalize
{
	NSInteger i;
	
	for (i = 0 ; i < nplanes ; i++)
		RelinquishMagickMemory(planes[i]);
	free(planes);
	[super finalize];
}

@end
