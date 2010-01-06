//
//  MyDocument.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright __MyCompanyName__ 2010 . All rights reserved.
//

#import "AddInsList.h"
#import "DataStore.h"

@implementation AddInsList

static AddInsList *sharedAddInsList;

+ (AddInsList*)sharedAddInsList
{
	return sharedAddInsList;
}

- (id)init 
{
	NSAssert(sharedAddInsList == nil, "Already a shared AddInsList");
	
    self = [super init];
    if (self != nil) {
        // initialization code
    }
	sharedAddInsList = self;
    return self;
}

- (NSString *)windowNibName 
{
    return @"AddInsList";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	return @"AddInsListStore";
}

- (BOOL)installAddInItem:(NSXMLElement *)node error:(NSError**)error
{
	AddInsListStore *store = [[[[self managedObjectContext] persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	
	return [store insertAddInNode:node error:error intoContext:[self managedObjectContext]];
}

@end
