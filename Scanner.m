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

#import "Scanner.h"
#import "AddInsList.h"
#import "DataProxy.h"

#include "erf.h"

#include <sqlite3.h>

static NSPredicate *isERF;

@implementation Scanner

@synthesize message;

- (id)initWithDocument:(AddInsList*)doc URL:(NSURL*)url message:(NSString*)msg disabled:(BOOL)dis
{
	self = [super init];
	if (self)
	{
		document = doc;
		startURL = url;
		message = msg;
		if (!isERF)
			isERF = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] '\\.[ce]rf'"];
		mparts = [[document fileURL] pathComponents];
		disabled = dis;
	}
	return self;
}

- (NSString*)basepathForURL:(NSURL*)url type:(NSString**)outType
{
	NSMutableArray *cparts = [NSMutableArray arrayWithArray:[url pathComponents]];
	NSString *pathType;
	NSString *path;
		
	for (NSString *p in mparts) {
		if (![[cparts objectAtIndex:0] isEqualToString:p])
			return nil;
		
		[cparts removeObjectAtIndex:0];
	}
	
	if ([[cparts objectAtIndex:0] caseInsensitiveCompare:@"Addins"] == NSOrderedSame
		|| [[cparts objectAtIndex:0] caseInsensitiveCompare:@"Offers"] == NSOrderedSame)
	{
		path = [NSString pathWithComponents:[cparts subarrayWithRange:NSMakeRange(0, 2)]];
		pathType = @"addin";
	}
	else
	{
		if (disabled)
		{
			NSString *s = [cparts objectAtIndex:0];
			
			[cparts replaceObjectAtIndex:0 withObject:[s substringToIndex:[s length] - sizeof (" (disabled)") + 1]];
		}
		
		if ([cparts count] > 4)
		{
			[cparts removeObjectsInRange:NSMakeRange(4, [cparts count] - 4)];
			pathType = @"dir";
		}
		else
			pathType = @"file";
		
		path = [NSString pathWithComponents:cparts];
	}
	
	if (outType)
		*outType = pathType;
	return path;
}

- (void)sendResults
{
	if (currPath)
	{
		[document performSelectorOnMainThread:@selector(addContentsForPath:)
								   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
											   currCont, @"contents",
											   currData, @"data",
											   currOrigURLs, @"origurls",
											   currPath, @"path",
											   currPathType, @"pathtype",
											   [NSNumber numberWithBool:disabled], @"disabled",
											   nil]
								waitUntilDone:YES];
	}
}

- (void)handle:(NSURL*)url
{
	NSArray *keys = [NSArray arrayWithObjects:NSURLNameKey, NSURLIsRegularFileKey, nil];
	NSDictionary *props = [url resourceValuesForKeys:keys error:nil];
	
	if (!props)
		return;
	
	if (![[props objectForKey:NSURLIsRegularFileKey] boolValue])
		return;
	
	NSString *name = [props objectForKey:NSURLNameKey];
	if (!name || [name isEqualToString:@".DS_Store"])
		return;

	NSString *path;
	NSString *pathType;
	
	path = [self basepathForURL:url type:&pathType];
	if (![currPath isEqualToString:path])
	{
		[self sendResults];
		
		currPath = path;
		currPathType = pathType;
		currCont = [NSMutableArray array];
		currData = [NSMutableArray array];
		currOrigURLs = [NSMutableArray array];
	}
	
	if ([isERF evaluateWithObject:name])
	{
		NSData *erfdata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:nil];
		
		if (erfdata)
		{
			parse_erf_data([erfdata bytes], [erfdata length], ^(struct erf_header *header, struct erf_file *file)
						   {
							   if (file->name)
								   [currCont addObject:[NSString stringWithCString:file->name encoding:NSASCIIStringEncoding]];
							   else
								   [currCont addObject:[NSNull null]]; 
							   [currData addObject:[erfdata subdataWithRange:NSMakeRange(file->data - [erfdata bytes], file->length)]];
							   [currOrigURLs addObject:url];
						   });
		}
	}
	else
	{
		[currCont addObject:name];
		[currData addObject:[DataProxy dataProxyForURL:url]];
		[currOrigURLs addObject:url];
	}
}

- (void)main
{
	NSDirectoryEnumerator *enumer = [[NSFileManager defaultManager] enumeratorAtURL:startURL includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) { return YES; }];
	NSURL *item;
	
	[self handle:startURL];
	
	while ((item = [enumer nextObject]) && ![self isCancelled])
	{
		[self handle:item];
	}
	
	[self sendResults];
}

@end
