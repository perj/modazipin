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


@implementation Dazip

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
    return @"Dazip";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
	NSArray *arr = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allItems"] error:nil];
	
	[detailsView setDrawsBackground:NO];
    [[detailsView mainFrame] loadHTMLString:[[arr objectAtIndex:0] detailsHTML] baseURL:[[NSBundle mainBundle] resourceURL]];
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	if ([[request mainDocumentURL] isFileURL])
		[listener use];
	else if ([[[request URL] scheme] isEqualToString:@"command"])
	{
		NSString *command = [[request URL] resourceSpecifier];
		
		[listener ignore];
		
		if ([command isEqualToString:@"install"])
			[self install:self];
	}
	else
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request mainDocumentURL]];
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
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

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *res = [NSMutableArray arrayWithCapacity:[defaultMenuItems count]];
	
	for (NSMenuItem *item in defaultMenuItems)
	{
		/* Was planning to white list instead of black list, but eg. Open Link is not documented. */
		switch ([item tag])
		{
			case WebMenuItemTagOpenLinkInNewWindow:
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagOpenImageInNewWindow:
			case WebMenuItemTagDownloadImageToDisk:
			case WebMenuItemTagCopyImageToClipboard:
			case WebMenuItemTagOpenFrameInNewWindow:
			case WebMenuItemTagGoBack:
			case WebMenuItemTagGoForward:
			case WebMenuItemTagStop:
			case WebMenuItemTagReload:
			case WebMenuItemTagCut:
			case WebMenuItemTagPaste:
			case WebMenuItemTagSpellingGuess:
			case WebMenuItemTagNoGuessesFound:
			case WebMenuItemTagIgnoreSpelling:
			case WebMenuItemTagLearnSpelling:
			case WebMenuItemTagOther: /* XXX huh? */
			case WebMenuItemTagOpenWithDefaultApplication:
				break;
				
			default:
				[res addObject:item];
				break;
		}
	}
	return res;
}

- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragDestinationActionNone;
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
	
	DazipStore *store = (DazipStore*)[[[arr objectAtIndex:0] objectID] persistentStore];
	[list installItems:[arr valueForKey:@"node"] withArchive:[self fileURL] uncompressedSize:store.uncompressedSize error:&err];
	
	[list selectItemWithUid:[[arr objectAtIndex:0] UID]];
	[list saveDocument:self];
	[list showWindows];
	[self close];
}

@end
