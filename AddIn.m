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
	
	for (DataStoreObject *obj in arr)
	{
		[list installAddInItem:(NSXMLElement*)[obj node] withArchive:[self fileURL] error:&err];
	}
	[list saveDocument:self];
	[list showWindows];
	[self close];
}

@end
