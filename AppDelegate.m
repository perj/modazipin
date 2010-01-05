//
//  AppDelegate.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "DataStore.h"
#import "AddInsList.h"

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notice
{
	[NSPersistentStoreCoordinator registerStoreClass:[AddInsListStore self] forStoreType:@"AddInsListStore"];
	[NSPersistentStoreCoordinator registerStoreClass:[AddInStore self] forStoreType:@"AddInStore"];
	[self openAddInsList:self];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	[self openAddInsList:self];
	return NO;
}

- (IBAction)openAddInsList:(id)sender
{
	NSError *err = nil;
	NSURL *documents = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&err];
	
	if (documents)
	{
		/* Manually open the AddIns.xml file, to avoid registering as opener of all .xml files */
		NSURL *addins = [[NSURL URLWithString:@"BioWare/Dragon%20Age/Settings/AddIns.xml" relativeToURL:documents] standardizedURL];
		NSDocument *doc;
		
		if ((doc = [[NSDocumentController sharedDocumentController] documentForURL:addins]))
			[doc showWindows];
		else
		{
			doc = [[AddInsList alloc] initWithContentsOfURL:addins ofType:@"Dragon Age AddIns List" error:&err];
			
			if (doc)
			{
				[[NSDocumentController sharedDocumentController] addDocument:doc];
				[doc makeWindowControllers];
				[doc showWindows];
			}
		}
	}
	
}

@end
