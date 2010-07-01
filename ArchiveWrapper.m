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

#import "ArchiveWrapper.h"

#include <archive.h>
#include <archive_entry.h>

NSString * const ArchiveMemberInfoNotAvailableException = @"ArchiveMemberInfoNotAvailableException";
NSString * const ArchiveMemberDataNotAvailableException = @"ArchiveMemberDataNotAvailableException";

NSString * const ArchiveErrorDomain = @"ArchiveErrorDomain";

@interface ArchiveWrapper (Errors)

+ (NSError*)archiveError:(struct archive *)archive code:(NSInteger)code;
+ (NSError*)errorWithCode:(NSInteger)code eno:(int)eno string:(NSString*)str;

@end

@implementation ArchiveWrapper (Errors)

+ (NSError*)archiveError:(struct archive *)archive code:(NSInteger)code
{
	/*
	 * XXX NSASCIIStringEncoding is based on looking at libarchive source code.
	 * It's conceivable that they'll use catalogs sometime in the future, in case
	 * that might be wrong.
	 * I can't find a useable encoding for that, might not exist one.
	 */
	return [NSError errorWithDomain:ArchiveErrorDomain
							   code:code
						   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithInt:archive_errno(archive)], @"errno",
									 [NSString stringWithCString:archive_error_string (archive)
														encoding:NSASCIIStringEncoding], @"error_string",
									 nil]];
}

+ (NSError*)errorWithCode:(NSInteger)code eno:(int)eno string:(NSString*)str
{
	return [NSError errorWithDomain:ArchiveErrorDomain
							   code:code
						   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithInt:eno], @"errno",
									 str, @"error_string",
									 nil]];
}

@end


@implementation ArchiveMember

- (id)initWithWrapper:(ArchiveWrapper *)w archive:(struct archive *)a encoding:(NSStringEncoding)enc error:(NSError**)error
{
	self = [super init];
	
	if (self)
	{
		int r;
		
		wrapper = w;
		archive = a;
		encoding = enc;
		if ((r = archive_read_next_header(a, &entry)) != ARCHIVE_OK)
		{
			entry = NULL;
			if (error)
			{
				if (r == ARCHIVE_EOF)
					*error = nil;
				else
					*error = [ArchiveWrapper archiveError:archive code:r];
			}
			return nil;
		}
		entry = archive_entry_clone(entry);
		if (!entry)
		{
			if (error)
				*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
			return nil;
		}
		dataAvailable = YES;
		data = nil;
	}
	return self;
}

- (void)finalize
{
	archive_entry_free (entry);
	
	[super finalize];
}

@synthesize entry;
@synthesize encoding;

- (BOOL)pathnameAvailable
{
	return archive_entry_pathname (entry) != NULL;
}

- (NSString*)pathname
{
	const char *pn = archive_entry_pathname (entry);
	
	if (!pn)
		[NSException raise:ArchiveMemberInfoNotAvailableException format:@"pathname is not set"];
	
	return [NSString stringWithCString:pn encoding:encoding];
}

- (const char*)cPathname
{
	const char *pn = archive_entry_pathname (entry);
	
	if (!pn)
		[NSException raise:ArchiveMemberInfoNotAvailableException format:@"pathname is not set"];
	
	return pn;
}

- (BOOL)sizeAvailable
{
	return archive_entry_size_is_set (entry);
}

- (int64_t)size
{
	if (!archive_entry_size_is_set (entry))
		[NSException raise:ArchiveMemberInfoNotAvailableException format:@"size is not set"];
	
	return archive_entry_size (entry);
}

- (BOOL)fetchDataWithError:(NSError **)error
{
	NSMutableData *mutableData;
	const void *buf;
	size_t len;
	off_t offset;
	int r;
	
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
	
	if (self.sizeAvailable)
	{
		mutableData = [NSMutableData dataWithLength:(NSUInteger)self.size];
		
		int idx = 0;
		while ((r = archive_read_data_block (archive, &buf, &len, &offset)) == ARCHIVE_OK)
		{
			[mutableData replaceBytesInRange:(NSRange){(NSUInteger)offset, (NSUInteger)len} withBytes:buf];
		
			if (++idx % 300 == 0 && wrapper)
				wrapper.uncompressedOffset = archive_position_uncompressed(archive);
		}
	}
	else
	{
		mutableData = [NSMutableData data];
		
		int idx = 0;
		while ((r = archive_read_data_block (archive, &buf, &len, &offset)) == ARCHIVE_OK)
		{
			if (offset > (off_t)[data length])
				[mutableData increaseLengthBy:(NSUInteger)offset - [data length]];
			[mutableData appendBytes:buf length:len];
			
			if (++idx % 300 == 0 && wrapper)
				wrapper.uncompressedOffset = archive_position_uncompressed(archive);
		}
	}
	
	if (r != ARCHIVE_EOF && r != ARCHIVE_WARN)
	{
		if (error)
			*error = [ArchiveWrapper archiveError:archive code:r];
		
		return NO;
	}
	
	if (error)
	{
		if (r == ARCHIVE_WARN)
			*error = [ArchiveWrapper archiveError:archive code:r];
		else
			*error = nil;
	}
	
	[self willChangeValueForKey:@"data"];
	data = mutableData;
	[self didChangeValueForKey:@"data"];
	return YES;
}

- (BOOL)skipDataWithError:(NSError **)error
{
	int r;
	
	if (data)
	{
		if (error)
			*error = nil;
		return NO;
	}
	
	r = archive_read_data_skip (archive);
	
	[self willChangeValueForKey:@"dataAvailable"];
	dataAvailable = NO;
	[self didChangeValueForKey:@"dataAvailable"];
	
	if (wrapper)
		wrapper.uncompressedOffset = archive_position_uncompressed(archive);
	
	if (r != ARCHIVE_OK && r != ARCHIVE_WARN)
	{
		if (error)
			*error = [ArchiveWrapper archiveError:archive code:r];
		
		return NO;
	}
	
	if (r == ARCHIVE_WARN && error)
		*error = [ArchiveWrapper archiveError:archive code:r];
		
	return YES;
}

@synthesize dataAvailable;

- (NSData *)data
{
	if (!data)
	{
		NSError *err = nil;
		
		if (![self fetchDataWithError:&err])
		{
			if (!err)
				@throw [NSException exceptionWithName:ArchiveMemberDataNotAvailableException
											   reason:@"loadData failed"
											 userInfo:[NSDictionary dictionaryWithObject:err
																				  forKey:NSUnderlyingErrorKey]];
			return nil;
		}
	}
	
	return data;
}

- (BOOL)extractToURL:(NSURL *)dst createDirectories:(BOOL)create error:(NSError **)error
{
	if (!dataAvailable)
	{
		/* XXX Should probably use exception here. */
		if (error)
			*error = nil;
		
		return NO;
	}
	
	if (create)
	{
		NSURL *dir = [dst URLByDeletingLastPathComponent];
		
		if (![dir checkResourceIsReachableAndReturnError:nil])
		{
			if (![[NSFileManager defaultManager] createDirectoryAtPath:[dir path] withIntermediateDirectories:YES attributes:nil error:error])
				return NO;
		}
	}
	
	if (data)
		return [data writeToURL:dst options:NSDataWritingAtomic error:error];
	
	[[NSFileManager defaultManager] createFileAtPath:[dst path] contents:nil attributes:nil];
	NSFileHandle *fh = [NSFileHandle fileHandleForWritingToURL:dst error:error];
	int r;
	const void *buf;
	size_t len;
	off_t offset;
		
	if (!fh)
		return NO;
	
	[self willChangeValueForKey:@"dataAvailable"];
	dataAvailable = NO;
	[self didChangeValueForKey:@"dataAvailable"];
	
	int idx = 0;
	while ((r = archive_read_data_block (archive, &buf, &len, &offset)) == ARCHIVE_OK)
	{
		if (offset > (off_t)[fh offsetInFile])
			[fh truncateFileAtOffset:offset];
		[fh writeData:[NSData dataWithBytesNoCopy:(void*)buf length:len freeWhenDone:NO]];
		if (++idx % 300 == 0 && wrapper)
			wrapper.uncompressedOffset = archive_position_uncompressed(archive);
	}
	[fh closeFile];
	
	if (r != ARCHIVE_EOF && r != ARCHIVE_WARN)
	{
		if (error)
			*error = [ArchiveWrapper archiveError:archive code:r];
		return NO;
	}
	
	if (error)
	{
		if (r == ARCHIVE_WARN)
			*error = [ArchiveWrapper archiveError:archive code:r];
		else
			*error = nil;
	}
		
	return YES;
}

@end


@implementation ArchiveWrapper

+ (ArchiveWrapper*)archiveForReadingFromURL:(NSURL *)url encoding:(NSStringEncoding)enc error:(NSError **)error
{
	return [[self alloc] initForReadingFromURL:url encoding:enc error:error];
}

- (id)initForReadingFromURL:(NSURL *)url encoding:(NSStringEncoding)enc error:(NSError **)error
{
	self = [self init];
	if (self)
	{
		int r;
		
		if (![url isFileURL])
		{
			/* XXX maybe use exception here. */
			if (error)
				*error = [ArchiveWrapper errorWithCode:ARCHIVE_FATAL eno:EINVAL string:@"Only file URLs supported for now"];
			return nil;
		}
		
		archive = archive_read_new ();
		archive_read_support_compression_all (archive);
		archive_read_support_format_all (archive);
		if ((r = archive_read_open_filename (archive, [[url path] fileSystemRepresentation],
											10 * 1024) != ARCHIVE_OK))
		{
			if (error)
				*error = [ArchiveWrapper archiveError:archive code:r];
				
			if (r != ARCHIVE_WARN)
				return nil;
		}
		
		encoding = enc;
		
		lastMember = nil;
		self.uncompressedOffset = archive_position_uncompressed(archive);
	}
	return self;
}

- (void)finalize
{
	if (archive)
		archive_read_finish (archive);
	[super finalize];
}

- (Class)memberClass
{
	return [ArchiveMember class];
}

- (ArchiveMember *)nextMemberWithError:(NSError**)error
{
	if (lastMember)
		[lastMember skipDataWithError:error];
	
	lastMember = [[[self memberClass] alloc] initWithWrapper:self archive:archive encoding:encoding error:error];
	self.uncompressedOffset = archive_position_uncompressed(archive);

	if (!lastMember)
		archive_read_close (archive);
	
	return lastMember;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	ArchiveMember *res = [self nextMemberWithError:nil];
	
	if (!state->state)
	{
		state->mutationsPtr = &state->extra[0];
		state->state = 1;
	}
	
	if (!res)
		return 0;
	
	NSAssert(len >= 1, @"len < 1!?");
	stackbuf[0] = res;
	state->itemsPtr = stackbuf;
	return 1;
}

@synthesize uncompressedOffset;

@end
