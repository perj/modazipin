/* Copyright (c) 2011 Per Johansson, per at morth.org
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


#import "ContentProtocol.h"
#import "AddInsList.h"

@implementation ContentProtocol

+ (void)load
{
	static BOOL once = NO;
	
	if (!once)
	{
		[NSURLProtocol registerClass:self];
		once = YES;
	}
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	return [[[request URL] scheme] isEqualToString:@"content"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id < NSURLProtocolClient >)client
{
	self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
	if (self)
	{
		/* XXX Needed for GC project, but this leaks and seems to create a retain cycle, can't find any way around it. */
		CFRetain(client);
	}
	return self;
}

- (void)finalize
{
	NSLog(@"Content protocol released!");
	[super finalize];
}

- (void)startLoading
{
	NSURL *url = [[self request] URL];
	
	NSData *data = [[AddInsList sharedAddInsList] dataForContent:[url resourceSpecifier]];
	NSData *tiff = nil;
	
	if (data)
	{
		NSImage *img = [[NSImage alloc] initWithData:data];
		if (img)
		{
			NSSize sz = [img size];
			
			if (sz.width > 340)
			{
				sz.height *= 340. / sz.width;
				sz.width = 340;
				[img setSize:sz];
			}
			
			tiff = [img TIFFRepresentation];
			if (tiff)
			{
				NSURLResponse *resp = [[NSURLResponse alloc] initWithURL:url MIMEType:@"image/tiff" expectedContentLength:[tiff length] textEncodingName:nil];
				NSCachedURLResponse *cache;
				cache = [[NSCachedURLResponse alloc] initWithResponse:resp data:tiff];
				
				[[self client] URLProtocol:self didReceiveResponse:[cache response] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
				[[self client] URLProtocol:self didLoadData:[cache data]];
				[[self client] URLProtocolDidFinishLoading:self];
			}
		}
	}
	
	if (!tiff)
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil]];
}

- (void)stopLoading
{
}

@end
