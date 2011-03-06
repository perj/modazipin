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

#import "DAArchive.h"

static NSPredicate *isDirectory;
static NSPredicate *startsWithDot;
static NSPredicate *isBlacklisted;
static NSPredicate *isDisabled;
static NSPredicate *isERF;

@implementation DAArchiveMember

@synthesize type;
@synthesize installPath;
@synthesize contentPath;
@synthesize contentType;
@synthesize contentName;

@end

@implementation DAArchive

- (id)init
{
	self = [super init];
	
	if (self)
	{
		if (!isDirectory)
			isDirectory = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '/'"];
		if (!startsWithDot)
			startsWithDot = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH '.'"];
		if (!isBlacklisted)
			isBlacklisted = [NSPredicate predicateWithFormat:@"SELF MATCHES '(?i)^Contents/(Characters|Logs|Screenshots|Settings)/.*'"];
		if (!isDisabled)
			isDisabled = [NSPredicate predicateWithFormat:@"SELF MATCHES '(?i).* (disabled)/.*'"];
		if (!isERF)
			isERF = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] '\\.[ce]rf'"];
	}
	return self;
}

- (Class)memberClass
{
	return [DAArchiveMember class];
}

@end


@implementation DazipArchive

- (DAArchiveMember *)nextMemberWithError:(NSError**)error
{
	DAArchiveMember *next;
	
	while ((next = (DAArchiveMember*)[super nextMemberWithError:error]))
	{
		NSString *path = [next pathname];
		NSArray *comps = [path pathComponents];
		NSRange cr;
		
		/* Whitelist Manifest. */
		if ([path caseInsensitiveCompare:@"Manifest.xml"] == NSOrderedSame)
		{
			next.type = dmtManifest;
			return next;
		}
		
		/* We only care about files currently. */
		if ([isDirectory evaluateWithObject:path])
			continue;
		
		/* Disallow full paths and anything starting with . */
		if ([path characterAtIndex:0] == '/')
			continue;
		if ([[comps filteredArrayUsingPredicate:startsWithDot] count])
			continue;
		
		/* Disallow everything not in Contents/ and at least two levels below */
		if ([[comps objectAtIndex:0] caseInsensitiveCompare:@"Contents"] != NSOrderedSame)
			continue;
		if ([comps count] < 3)
			continue;
		
		/* Blacklist some of the user data dirs. */
		if ([isBlacklisted evaluateWithObject:path])
			continue;
		
		/* Disallow stuff containing (disabled) */
		if ([isDisabled evaluateWithObject:path])
			continue;
		
		/* Determine contents path. */
		if ([[comps objectAtIndex:1] caseInsensitiveCompare:@"packages"] == NSOrderedSame)
			cr = NSMakeRange(1, 4);
		else
			cr = NSMakeRange(1, 2);
		if ([comps count] < cr.location + cr.length)
			continue;
		next.contentPath = [NSString pathWithComponents:[comps subarrayWithRange:cr]];
		
		cr.location = 1;
		cr.length = [comps count] - 1;
		next.installPath = [NSString pathWithComponents:[comps subarrayWithRange:cr]];
					 
		/* Determine contentType */
		if ([comps count] > cr.location + cr.length)
			next.contentType = dmctDirectory;
		else
			next.contentType = dmctFile;
		
		/* Determine type. */
		if ([isERF evaluateWithObject:path])
			next.type = dmtERF;
		else
			next.type = dmtFile;
		
		/* Determine name. */
		next.contentName = [comps objectAtIndex:[comps count] - 1];
		
		return next;
	}
	return nil;
}

@end


@implementation OverrideArchive

- (DAArchiveMember *)nextMemberWithError:(NSError**)error
{
	DAArchiveMember *next;
	
	while ((next = (DAArchiveMember*)[super nextMemberWithError:error]))
	{
		NSString *path = [next pathname];
		NSArray *comps = [path pathComponents];
		NSRange cr;
		
		/* Whitelist Manifest. */
		if ([path caseInsensitiveCompare:@"Manifest.xml"] == NSOrderedSame)
		{
			next.type = dmtManifest;
			return next;
		}
		
		/* We only care about files currently. */
		if ([isDirectory evaluateWithObject:path])
			continue;
		
		/* Disallow full paths and anything starting with . */
		if ([path characterAtIndex:0] == '/')
			continue;
		if ([[comps filteredArrayUsingPredicate:startsWithDot] count])
			continue;
		
		/* Find the override folder. */
		NSUInteger overrideIdx = 0;
		for (NSString *part in comps)
		{
			if ([part caseInsensitiveCompare:@"override"] == NSOrderedSame)
				break;
			overrideIdx++;
		}
		if (overrideIdx >= [comps count] - 1)
			continue;
		
		/* Determine contents path. */
		next.contentPath = [NSString stringWithFormat:@"packages/core/override/%@", [comps objectAtIndex:overrideIdx + 1]];
		
		cr.location = overrideIdx;
		cr.length = [comps count] - overrideIdx;
		next.installPath = [NSString stringWithFormat:@"packages/core/%@", [NSString pathWithComponents:[comps subarrayWithRange:cr]]];
		
		/* Determine contentType */
		if ([comps count] > overrideIdx + 1)
			next.contentType = dmctDirectory;
		else
			next.contentType = dmctFile;
		
		/* Determine type. */
		if ([isERF evaluateWithObject:path])
			next.type = dmtERF;
		else
			next.type = dmtFile;
		
		/* Determine name. */
		next.contentName = [comps objectAtIndex:[comps count] - 1];
		
		return next;
	}
	return nil;
}

@end
