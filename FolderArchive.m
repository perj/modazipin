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

#import "FolderArchive.h"

static NSArray *resourceKeys;

@implementation FolderArchiveMember

- (id)initWithWrapper:(FolderArchive*)w URL:(NSURL*)u level:(NSUInteger)l encoding:(NSStringEncoding)enc error:(NSError**)error
{
	self = [super init];
	
	if (self)
	{
		wrapper = w;
		encoding = enc;
		url = u;
		dataAvailable = YES;
		data = nil;
		resources = [url resourceValuesForKeys:resourceKeys error:error];
		if (!resources)
			return nil;
	}
	
	return self;
}

- (BOOL)pathnameAvailable
{
	if (!url)
		return [super pathnameAvailable];
	
	return YES;
}

- (NSString*)pathname
{
	if (!url)
		return [super pathname];
	
	NSArray *comps = [url pathComponents];
	NSRange r = {[comps count] - level - 1, level + 1};
	
	return [NSString pathWithComponents:[comps subarrayWithRange:r]];
}

- (const char*)cPathname
{
	if (!url)
		return [super cPathname];
	
	return [[self pathname] cStringUsingEncoding:encoding];
}

- (BOOL)sizeAvailable
{
	if (!url)
		return [super sizeAvailable];
	
	return [[resources objectForKey:NSURLIsRegularFileKey] boolValue];
}

- (int64_t)size
{
	if (!url)
		return [super size];
	
	if (![[resources objectForKey:NSURLIsRegularFileKey] boolValue])
		[NSException raise:ArchiveMemberInfoNotAvailableException format:@"size is only available for regular files"];
	
	return [[resources objectForKey:NSURLFileSizeKey] longLongValue];
}

- (BOOL)fetchDataWithError:(NSError **)error
{
	if (!url)
		return [super fetchDataWithError:error];
	
	if (data)
	{
		if (error)
			*error = nil;
		return YES;
	}
	
	if (!dataAvailable)
	{
		if (error)
			*error = nil;
		
		return NO;
	}
	
	[self willChangeValueForKey:@"data"];
	data = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:error];
	[self didChangeValueForKey:@"data"];
	
	if (wrapper)
		wrapper.uncompressedOffset += [data length];
	return data != nil;
}

- (BOOL)skipDataWithError:(NSError **)error
{
	if (!url)
		return [super skipDataWithError:error];
	
	if (data)
	{
		if (error)
			*error = nil;
		return NO;
	}
	
	[self willChangeValueForKey:@"dataAvailable"];
	dataAvailable = NO;
	[self didChangeValueForKey:@"dataAvailable"];
	
	if (wrapper)
		wrapper.uncompressedOffset += [[resources objectForKey:NSURLFileSizeKey] longLongValue];

	return YES;
}

- (BOOL)extractToURL:(NSURL *)dst createDirectories:(BOOL)create error:(NSError **)error
{
	if (url && !data && dataAvailable)
	{
		if (![self fetchDataWithError:error])
			return NO;
	}
	return [super extractToURL:dst createDirectories:create error:error];
}

@end


@implementation FolderArchive

+ (void)initialize
{
	if (!resourceKeys)
		resourceKeys = [NSArray arrayWithObjects:
						NSURLIsRegularFileKey,
						NSURLFileSizeKey,
						nil];
}

- (id)initForReadingFromURL:(NSURL *)url encoding:(NSStringEncoding)enc error:(NSError **)error
{
	if ([url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil] && [isDir boolValue])
	{
		self = [self init];
		
		if (self)
		{
			errPtr = nil;
			enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url
											  includingPropertiesForKeys:resourceKeys
																 options:NSDirectoryEnumerationSkipsHiddenFiles
															errorHandler:^(NSURL *u, NSError *err) { if (errPtr) *errPtr = err; return NO; }];
			encoding = enc;
		}
	}
	else
		self = [super initForReadingFromURL:url encoding:enc error:error];
	
	return self;
}

- (ArchiveMember *)nextMemberWithError:(NSError**)error
{
	if (!isDir || ![isDir boolValue])
		return [super nextMemberWithError:error];
	
	errPtr = error;
	NSURL *url = [enumerator nextObject];
	
	if (!url)
		return nil;
	
	if (![enumerator level])
		return [self nextMemberWithError:error];
	
	return [[[self memberClass] alloc] initWithWrapper:self URL:url level:[enumerator level] encoding:encoding error:error];
}

@end
