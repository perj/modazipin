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

#include "erf.h"

static NSPredicate *isERF;

@implementation Scanner

@synthesize message;

- (id)initWithDocument:(AddInsList*)doc URL:(NSURL*)url message:(NSString*)msg split:(BOOL)splt
{
	self = [super init];
	if (self)
	{
		document = doc;
		startURL = url;
		message = msg;
		split = splt;
		if (!isERF)
			isERF = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] '.erf'"];
	}
	return self;
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
	
	if ([isERF evaluateWithObject:name])
	{
		NSData *erfdata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:nil];
		
		if (erfdata)
		{
			parse_erf_data([erfdata bytes], [erfdata length], ^(struct erf_header *header, struct erf_file *file)
						   {
							   int len = 0;
							   
							   while (len < ERF_FILENAME_MAXLEN && file->entry->name[len] != 0)
								   len++;
							   
							   [document performSelectorOnMainThread:@selector(addContentsForURL:)
														  withObject:[NSDictionary dictionaryWithObjectsAndKeys:
																	  [[NSString alloc] initWithBytes:file->entry->name
																								length:len * 2
																							  encoding:NSUTF16LittleEndianStringEncoding], @"contents",
																	  url, @"URL",
																	  nil]
													   waitUntilDone:YES];
						   });
		}
		[document performSelectorOnMainThread:@selector(addContentsForURL:)
								   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
											   url, @"URL",
											   nil]
								waitUntilDone:YES];
	}
	else
		[document performSelectorOnMainThread:@selector(addContentsForURL:)
								   withObject:[NSDictionary dictionaryWithObjectsAndKeys:
											   name, @"contents",
											   url, @"URL",
											   nil]
								waitUntilDone:YES];
}

- (void)main
{
	NSDirectoryEnumerator *enumer = [[NSFileManager defaultManager] enumeratorAtURL:startURL includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *url, NSError *error) { return YES; }];
	NSURL *item;
	
	[self handle:startURL];
	
	while ((item = [enumer nextObject]) && ![self isCancelled])
	{
		if (split)
		{
			[[NSOperationQueue currentQueue] addOperation:[[Scanner alloc] initWithDocument:document URL:item message:message split:NO]];
			[enumer skipDescendants];
		}
		else
			[self handle:item];
	}
}

@end
