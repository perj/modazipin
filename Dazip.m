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

#import "Dazip.h"
#import "AddInsList.h"
#import "AppDelegate.h"
#import "DataStore.h"
#import "ArchiveWrapper.h"

@implementation Dazip

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
    }
    return self;
}

#if 0
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error
{
	return [super readFromURL:absoluteURL ofType:typeName error:error];
}
#endif

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	/*
	 * Not sure if it should be considered a bug or not, but the system implementation
	 * will look at the registered documents types in order and check if they can open
	 * the type given. This doesn't work, since daoverride conforms to zip, and dazip
	 * registers that it can open zip.
	 *
	 * This is probably faster anyway.
	 */
	if ([fileType isEqualToString:@"org.morth.per.dazip"])
		return @"DazipStore";
	if ([fileType isEqualToString:@"org.morth.per.daoverride"])
		return @"OverrideStore";
	return [super persistentStoreTypeForFileType:fileType];
}

- (NSString *)windowNibName 
{
    return @"Dazip";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
	NSArray *arr = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allItems"] error:nil];
	
	[detailsView setDrawsBackground:NO];
    [[detailsView mainFrame] loadHTMLString:[[arr objectAtIndex:0] detailsHTML] baseURL:[[NSBundle mainBundle] resourceURL]];
}

- (void)detailsDidLoad
{
	DOMDocument *root = [[detailsView mainFrame] DOMDocument];
	DOMHTMLElement *body = [root body];
	int height = [body scrollHeight];

	for (NSWindowController *wc in [self windowControllers])
	{
		NSSize cs = [[wc window] frame].size;
		
		cs.height = height;
		[[wc window] setContentSize:cs];
	}
}

- (void)detailsCommand:(NSString*)command
{
	if ([command isEqualToString:@"install"])
		[self install:self];
}

- (void)displayUIDConflictFor:(Item*)a and:(Item*)b
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
							   b.Title.localizedValue);
}

- (void)displayPathsConflictFor:(Item*)a and:(Item*)b
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
							   b.Title.localizedValue,
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
	NSArray *arr = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allItems"] error:&err];

	NSFetchRequest *uidFetch = [[list managedObjectModel] fetchRequestFromTemplateWithName:@"itemsWithUIDs" substitutionVariables:[NSDictionary dictionaryWithObject:[arr valueForKey:@"UID"] forKey:@"UIDs"]];
	NSArray *uidConflict = [[list managedObjectContext] executeFetchRequest:uidFetch error:&err];
	
	if ([uidConflict count])
	{
		[self displayUIDConflictFor:[arr objectAtIndex:0] and:[uidConflict objectAtIndex:0]];
		return;
	}
	
	NSArray *paths = [[[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allPaths"] error:&err] valueForKey:@"path"];
	NSFetchRequest *pathsFetch = [[list managedObjectModel] fetchRequestFromTemplateWithName:@"itemsWithPaths" substitutionVariables:[NSDictionary dictionaryWithObject:paths forKey:@"paths"]];
	NSArray *pathsConflict = [[list managedObjectContext] executeFetchRequest:pathsFetch error:&err];
	
	if ([pathsConflict count])
	{
		[self displayPathsConflictFor:[arr objectAtIndex:0] and:[pathsConflict objectAtIndex:0]];
		return;
	}
	
	ArchiveStore *store = (ArchiveStore*)[[[arr objectAtIndex:0] objectID] persistentStore];
	DAArchive *archive = [[store archiveClass] archiveForReadingFromURL:[self fileURL] encoding:NSWindowsCP1252StringEncoding error:&err];
	
	if (!archive)
	{
		[self presentError:err];
		return;
	}
	
	if (![list installItems:[arr valueForKey:@"node"] withArchive:archive name:[[self fileURL] lastPathComponent] uncompressedSize:store.uncompressedSize error:&err])
	{
		[self presentError:err];
		return;
	}
	
	[list selectItemWithUid:[[arr objectAtIndex:0] UID]];
	[list saveDocument:self];
	[list showWindows];

	[self close];
}

@end
