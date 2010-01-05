//
//  DataStore.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "DataStore.h"

@implementation DataStore

- (NSString *)identifier
{
	return @"12345678-1234-1234-1234-1234567890AB";
}

- (NSDictionary*)metadata {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[self type],
			NSStoreTypeKey,
			[self identifier],
			NSStoreUUIDKey,
			nil];
}

- (void)loadXML:(NSURL *)url
{
	NSAssert(xmldoc == nil, @"xmldoc != nil");
	
	NSInteger xmlopt = NSXMLNodePreserveCharacterReferences | NSXMLNodePreserveWhitespace;
	NSError *error = nil;
	
	xmldoc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:xmlopt error:&error];
	
	if (!xmldoc && [url isFileURL] && [[error domain] isEqualToString:NSURLErrorDomain])
	{
		NSInteger code = [error code];
		
		if ((code == NSURLErrorCannotOpenFile) || (code == NSURLErrorZeroByteResource))
		{
			[[NSFileManager defaultManager] createFileAtPath:[url path] contents:nil attributes:nil];
			xmldoc = [[NSXMLDocument alloc] initWithKind:NSXMLDocumentXMLKind options:xmlopt];
		}
	}
	
	if (!xmldoc)
	{
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not open URL %@", url] userInfo:nil] raise];
	}
}

/*
 * Load a text node with DefaultText and language codes.
 */
- (NSArray*)loadText:(NSXMLElement*)node error:(NSError **)error
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	NSMutableSet *res = [NSMutableSet set];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"DefaultText"])
		{
			[data setObject:[attr stringValue] forKey:[attr name]];
			continue;
		}
		
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Unknown Text attribute"
							   userInfo:[NSDictionary dictionaryWithObject:attr forKey:@"node"]] raise];
	}
	
	for (NSXMLElement *subnode in [node children])
	{
		NSMutableDictionary *subdata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[subnode name], @"langcode",
										[subnode stringValue], @"value",
										nil];
		NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:@"LocalizedText"];
		NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:subdata];
		NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
		
		[cnode setPropertyCache:subdata];
		[res addObject:cnode];
	}
	
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:@"Text"];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:data];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
	
	[cnode setPropertyCache:data];
	[res addObject:cnode];
	
	return [NSArray arrayWithObjects:cnode, res, nil];
}

/*
 * Load a single AddInItem node.
 */
- (NSMutableSet*)loadAddInItem:(NSXMLElement *)node error:(NSError **)error
{
	NSMutableDictionary *data;
	NSMutableSet *res = [NSMutableSet set];
	
	if (![[node name] isEqualToString:@"AddInItem"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInItem"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	data = [NSMutableDictionary dictionary];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"UID"]
			|| [[attr name] isEqualToString:@"Name"]
			|| [[attr name] isEqualToString:@"ExtendedModuleUID"])
		{
			[data setObject:[attr stringValue] forKey:[attr name]];
			continue;
		}
		
		if ([[attr name] isEqualToString:@"Priority"]
			|| [[attr name] isEqualToString:@"Enabled"]
			|| [[attr name] isEqualToString:@"State"]
			|| [[attr name] isEqualToString:@"Format"]
			|| [[attr name] isEqualToString:@"BioWare"]
			|| [[attr name] isEqualToString:@"RequiresAuthorization"])
		{
			[data setObject:[NSDecimalNumber decimalNumberWithString:[attr stringValue]] forKey:[attr name]];
			continue;
		}
		
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Unknown AddInItem attribute"
							   userInfo:[NSDictionary dictionaryWithObject:attr forKey:@"node"]] raise];
	}
	
	for (NSXMLElement *subnode in [node children])
	{
		if ([[subnode name] isEqualToString:@"Title"]
			|| [[subnode name] isEqualToString:@"Description"]
			|| [[subnode name] isEqualToString:@"Rating"]
			|| [[subnode name] isEqualToString:@"RatingDescription"]
			|| [[subnode name] isEqualToString:@"URL"]
			|| [[subnode name] isEqualToString:@"Publisher"])
		{
			NSArray *arr = [self loadText:subnode error:error];
			
			if (!arr)
				return nil;
			
			NSAtomicStoreCacheNode *cnode = [arr objectAtIndex:0];
			NSMutableSet *subset = [arr objectAtIndex:1];
			
			[res unionSet:subset];
			
			[data setObject:cnode forKey:[subnode name]];
			continue;
		}
		
		if ([[subnode name] isEqualToString:@"Image"]
			|| [[subnode name] isEqualToString:@"ReleaseDate"]
			|| [[subnode name] isEqualToString:@"Version"]
			|| [[subnode name] isEqualToString:@"GameVersion"])
		{
			[data setObject:[subnode stringValue] forKey:[subnode name]];
			continue;
		}
		
		if ([[subnode name] isEqualToString:@"Type"]
			|| [[subnode name] isEqualToString:@"Price"]
			|| [[subnode name] isEqualToString:@"Size"])
		{
			[data setObject:[NSDecimalNumber decimalNumberWithString:[subnode stringValue]] forKey:[subnode name]];
			continue;
		}
		
		if ([[subnode name] isEqualToString:@"PrereqList"]) {
			/* Noop, don't know format. XXX error if non-empty. */
			continue;
		}
		
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Unknown AddInItem element"
							   userInfo:[NSDictionary dictionaryWithObject:subnode forKey:@"node"]] raise];
	}
	
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:@"AddInItem"];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:data];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];

	[cnode setPropertyCache:data];
	[res addObject:cnode];
	
	return res;
}

/*
 * Load an AddInsList node
 */
- (NSMutableSet*)loadAddInsList:(NSXMLElement *)node error:(NSError **)error
{
	NSMutableSet *res = [NSMutableSet set];
	
	/* XXX should probably return error instead of exception */
	if (![[node name] isEqualToString:@"AddInsList"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInsList"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	for (NSXMLElement *subnode in [node children]) {
		NSMutableSet *subset = [self loadAddInItem:subnode error:error];
		
		if (!subset)
			return nil;
		
		[res unionSet:subset];
	}
	
	return res;
}

@end

@implementation AddInsListStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self && url)
	{
		[self loadXML:url];
	}
	return self;
}

- (NSString *)type {
    return @"AddInsListStore";
}

- (BOOL)load:(NSError **)error
{
	if (!xmldoc)
		return YES;
	NSMutableSet *set = [self loadAddInsList:[xmldoc rootElement] error:error];
	if (!set)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

@end

@implementation AddInStore

@end