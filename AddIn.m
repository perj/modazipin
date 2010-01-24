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

#import "AddIn.h"
#import "AddInsList.h"
#import "AppDelegate.h"
#import "DataStore.h"

@implementation AddIn

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
    }
    return self;
}

- (NSString *)windowNibName 
{
    return @"AddIn";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

- (void)displayUIDConflictFor:(AddInItem*)a and:(AddInItem*)b
{
	NSBeginCriticalAlertSheet (@"Duplicate",
							   @"OK",
							   nil,
							   nil,
							   [self windowForSheet],
							   nil,
							   NULL,
							   NULL,
							   NULL,
							   @"This addin could not be installed because it conflicts with \"%@\"",
							   b.Title.DefaultText);
}

- (void)displayPathsConflictFor:(AddInItem*)a and:(AddInItem*)b
{
	NSMutableArray *arr = [NSMutableArray array];
	NSSet *aPaths = a.modazipin.paths;
	NSSet *bPaths = b.modazipin.paths;
	
	for (Path *apath in aPaths)
	{
		for (Path *bpath in bPaths)
		{
			if ([apath.path caseInsensitiveCompare:bpath.path] == NSOrderedSame)
				[arr addObject:apath.path];
		}
	}
	
	NSBeginCriticalAlertSheet (@"Duplicate items",
							   @"OK",
							   nil,
							   nil,
							   [self windowForSheet],
							   nil,
							   NULL,
							   NULL,
							   NULL,
							   @"This addin could not be installed because it contains these items also contained by \"%@\":\n\n%@",
							   b.Title.DefaultText,
							   [arr componentsJoinedByString:@"\n"]);
}

- (IBAction)install:(id)sender
{
	AddInsList *list = [AddInsList sharedAddInsList];
	
	if (!list)
	{
		[[NSApp delegate] openAddInsList:self];
		list = [AddInsList sharedAddInsList];
	}
	
	NSError *err;
	NSArray *arr = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allAddIns"] error:&err];
	
	for (AddInItem *obj in arr)
	{
		NSSet *objPaths = obj.modazipin.paths;
		
		NSArray *installed = [[list managedObjectContext] executeFetchRequest:[[list managedObjectModel] fetchRequestTemplateForName:@"allAddIns"] error:&err];
		for (AddInItem *item in installed)
		{
			if ([obj.UID caseInsensitiveCompare:item.UID] == NSOrderedSame)
			{
				[self displayUIDConflictFor:obj and:item];
				return;
			}
			
			NSSet *itemPaths = item.modazipin.paths;
			if (objPaths && itemPaths) 
			{
				/* XXX Is there a better way to do this? (can't really use LIKE since I don't know if values contain * and ? */
				for (Path *opath in objPaths)
				{
					for (Path *ipath in itemPaths)
					{
						if ([opath.path caseInsensitiveCompare:ipath.path] == NSOrderedSame)
						{
							[self displayPathsConflictFor:obj and:item];
							return;
						}
					}
				}
			}
		}
		[list installAddInItem:(NSXMLElement*)[obj node] withArchive:[self fileURL] error:&err];
	}
	[list saveDocument:self];
	[list showWindows];
	[self close];
}

@end
