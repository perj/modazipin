//
//  DataStore.h
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef id (^loadNodeBlock)(NSMutableDictionary *data, NSString *entityName);

@interface DataStore : NSAtomicStore {
	NSString *identifier;
	NSXMLDocument *xmldoc;
}

@property(copy) NSString *identifier;

@end

@interface AddInsListStore : DataStore
{
}

- (BOOL)insertAddInNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context;

@end

@interface AddInStore : DataStore
{
}

@end

@interface DataStoreObject : NSManagedObject {
	NSXMLNode *node;
}

@property(retain) NSXMLNode *node;

@end
