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

#import "AppDelegate.h"
#import "DataStore.h"
#import "AddInsList.h"
#import "NullStore.h"

@implementation AppDelegate

- (void)setupDefaults
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 @"0.2", @"backgroundAlpha",
															 @"0", @"useCustomBackground",
															 @"0", @"quitOnGameLaunch",
															 nil]];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notice
{
	[NSPersistentStoreCoordinator registerStoreClass:[AddInsListStore self] forStoreType:@"AddInsListStore"];
	[NSPersistentStoreCoordinator registerStoreClass:[OfferListStore self] forStoreType:@"OfferListStore"];
	[NSPersistentStoreCoordinator registerStoreClass:[DazipStore self] forStoreType:@"DazipStore"];
	[NSPersistentStoreCoordinator registerStoreClass:[NullStore self] forStoreType:@"NullStore"];
	
	[self setupDefaults];
	
	[self openAddInsList:self];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	[self openAddInsList:self];
	return NO;
}

- (IBAction)chooseDragonAgeFolder:(id)sender
{
	static BOOL running = NO;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSURL *oldUrl = [[NSUserDefaults standardUserDefaults] URLForKey:@"baseurl"];
	NSError *err;
	
	if (running)
		return;
	running = YES;
	
	if (!oldUrl)
		oldUrl = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
	
	if (oldUrl)
		[panel setDirectoryURL:oldUrl];
	
	[panel setMessage:@"Please locate the \"Dragon Age\" folder usually within the \"BioWare\" folder in Documents."];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	
	NSInteger result = [panel runModal];
	if (result == NSFileHandlingPanelOKButton)
	{
		NSURL *baseurl = [panel URL];
		NSDocument *doc = [[AddInsList alloc] initWithContentsOfURL:baseurl
															 ofType:@"Dragon Age AddIns List"
															  error:&err];
		
		if (doc)
		{
			[[NSDocumentController sharedDocumentController] addDocument:doc];
			[doc makeWindowControllers];
			[doc showWindows];
			[[NSUserDefaults standardUserDefaults] setURL:baseurl forKey:@"baseurl"];
		}
		else
			[NSApp presentError:err]; 
	}
	running = NO;
}

- (IBAction)openAddInsList:(id)sender
{
	NSError *err = nil;
	
	NSURL *baseurl = [[NSUserDefaults standardUserDefaults] URLForKey:@"baseurl"];
	
	if (!baseurl)
	{
		NSURL *documents = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
		
		baseurl = [[NSURL URLWithString:@"BioWare/Dragon%20Age" relativeToURL:documents] standardizedURL];
	}
	
	if (baseurl)
	{
		/* Manually open the AddIns.xml file, to avoid registering as opener of all .xml files */
		NSDocument *doc;
		
		if ((doc = [[NSDocumentController sharedDocumentController] documentForURL:baseurl]))
			[doc showWindows];
		else
		{
			doc = [AddInsList sharedAddInsList];
			if (!doc)
				doc = [[AddInsList alloc] initWithContentsOfURL:baseurl
														 ofType:@"Dragon Age AddIns List"
														  error:&err];
			
			if (doc)
			{
				[[NSDocumentController sharedDocumentController] addDocument:doc];
				[doc makeWindowControllers];
				[doc showWindows];
				[[NSUserDefaults standardUserDefaults] setURL:baseurl forKey:@"baseurl"];
			}
			else
				[self chooseDragonAgeFolder:nil];
		}
	}
}

- (IBAction)chooseCustomBackground:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSURL *oldUrl = [[NSUserDefaults standardUserDefaults] URLForKey:@"customBackgroundURL"];
	
	if (!oldUrl)
		oldUrl = [[AddInsList sharedAddInsList] randomScreenshotURL];
	
	if (oldUrl)
		[panel setDirectoryURL:[oldUrl URLByDeletingLastPathComponent]];
	
	[panel setAllowedFileTypes:[NSArray arrayWithObject:@"public.image"]];
	
	[panel beginSheetModalForWindow:[sender window] completionHandler:^(NSInteger result)
	 {
		if (result == NSFileHandlingPanelOKButton)
		{
			NSURL *newUrl = [panel URL];
			NSString *displayName = nil;
			
			[[NSUserDefaults standardUserDefaults] setURL:newUrl forKey:@"customBackgroundURL"];
			//[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:newUrl forKey:@"customBackgroundURL"];
			[newUrl getResourceValue:&displayName forKey:NSURLLocalizedNameKey error:nil];
			[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:displayName forKey:@"customBackgroundDisplayName"];
			[[[NSUserDefaultsController sharedUserDefaultsController] values] setValue:@"1" forKey:@"useCustomBackground"];
			
		}
	 }];
}

@end
