//
//  AppDelegate.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "DataStore.h"

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notice
{
	[NSPersistentStoreCoordinator registerStoreClass:[AddInsListStore self] forStoreType:@"AddInsListStore"];
	[NSPersistentStoreCoordinator registerStoreClass:[AddInStore self] forStoreType:@"AddInStore"];
}

@end
