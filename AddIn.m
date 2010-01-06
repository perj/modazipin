//
//  AddIn.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

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
		[list installAddInItem:(NSXMLElement*)[obj node] error:&err];
	}
	[list saveDocument:self];
	[list showWindows];
	[self close];
}

@end
