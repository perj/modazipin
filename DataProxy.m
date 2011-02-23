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

#import "DataProxy.h"


@implementation DataProxy

+ (id)dataProxyForURL:(NSURL*)url
{
	return [[self alloc] initWithURL:url];
}

+ (id)dataProxyForURL:(NSURL*)url range:(NSRange)r
{
	return [[self alloc] initWithURL:url range:r];
}

- (id)initWithURL:(NSURL*)url
{
	self = [super init];
	
	if (self)
		dataUrl = url;
	return self;
}

- (id)initWithURL:(NSURL*)url range:(NSRange)r
{
	self = [self initWithURL:url];
	
	if (self)
	{
		range = r;
		hasRange = YES;
	}
	return self;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
	if (!data)
	{
		data = [NSData dataWithContentsOfURL:dataUrl];
		if (hasRange)
			data = [data subdataWithRange:range];
	}
	return data;
}

@end
