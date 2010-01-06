//
//  DataStore.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "DataStore.h"

#include <archive.h>
#include <archive_entry.h>

@implementation DataStoreObject

@synthesize node;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	DataStore *store = [[[[self managedObjectContext] persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	
	self.node = [[store referenceObjectForObjectID:[self objectID]] objectForKey:@"node"];
}

@end


@implementation DataStore

@synthesize identifier;

- (NSDictionary*)metadata {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[self type],
			NSStoreTypeKey,
			[self identifier],
			NSStoreUUIDKey,
			nil];
}

- (void)loadXML:(NSData *)data
{
	NSInteger xmlopt = NSXMLNodePreserveCharacterReferences | NSXMLNodePreserveWhitespace;
	NSError *error;
	
	NSAssert(xmldoc == nil, @"xmldoc != nil");
	
	xmldoc = [[NSXMLDocument alloc] initWithData:data options:xmlopt error:&error];
	
	if (!xmldoc)
	{
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not read XML"] userInfo:nil] raise];
	}
	
}

/*
 * Load a text node with DefaultText and language codes.
 */
- (id)loadText:(NSXMLElement*)node error:(NSError **)error usingBlock:(loadNodeBlock)block
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	
	[data setObject:node forKey:@"node"];
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"DefaultText"])
		{
			[data setObject:[attr stringValue] forKey:[attr name]];
			continue;
		}
	}
	
	NSMutableSet *langset = [NSMutableSet set];
	for (NSXMLElement *subnode in [node children])
	{
		NSMutableDictionary *subdata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[subnode name], @"langcode",
										[subnode stringValue], @"value",
										subnode, @"node",
										nil];
		id lnode = block(subdata, @"LocalizedText");
		
		if (!lnode)
			return nil;

		[langset addObject:lnode];
	}
	if ([langset count])
		[data setObject:langset forKey:@"languages"];
	
	return block(data, @"Text");
}

/*
 * Load a single AddInItem node.
 */
- (BOOL)loadAddInItem:(NSXMLElement *)node error:(NSError **)error usingBlock:(loadNodeBlock)block
{
	NSMutableDictionary *data;
	
	if (![[node name] isEqualToString:@"AddInItem"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInItem"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	data = [NSMutableDictionary dictionary];
	
	[data setObject:node forKey:@"node"];
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
			id tnode = [self loadText:subnode error:error usingBlock:block];
			
			if (!tnode)
				return NO;
			
			[data setObject:tnode forKey:[subnode name]];
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
			/* Noop, don't know format. */
			continue;
		}
	}
	
	return block(data, @"AddInItem") != nil;
}

/*
 * Load an AddInsList node
 */
- (BOOL)loadAddInsList:(NSXMLElement *)node error:(NSError **)error usingBlock:(loadNodeBlock)block
{
	/* XXX should probably return error instead of exception */
	if (![[node name] isEqualToString:@"AddInsList"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInsList"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	for (NSXMLElement *subnode in [node children]) {
		BOOL res = [self loadAddInItem:subnode error:error usingBlock:block];
		
		if (!res)
			return NO;
	}
	
	return YES;
}

- (id)makeCacheNode:(NSMutableDictionary*)data forEntityName:(NSString*)name
{
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:name];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:data];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
	
	[cnode setPropertyCache:data];
	
	return cnode;
}

- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
	NSMutableDictionary *data = [self referenceObjectForObjectID:[managedObject objectID]];
	NSXMLElement *elem = [data objectForKey:@"node"];
	NSXMLNode *attr;
	
	/* Only support updating Enabled for now */
	
	if (![[elem name] isEqualToString:@"AddInItem"])
		return;
	
	attr = [elem attributeForName:@"Enabled"];
	if ([[managedObject valueForKey:@"Enabled"] intValue])
		[attr setStringValue:@"1"];
	else
		[attr setStringValue:@"0"];
}

- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	
	for (NSPropertyDescription *prop in [managedObject entity])
	{
		NSString *key = [prop name];
		id value = [managedObject valueForKey:key];
		
		if ([[prop class] isSubclassOfClass:[NSRelationshipDescription class]])
		{
			NSRelationshipDescription *rel = (NSRelationshipDescription*)prop;
			
			if ([rel isToMany])
			{
				NSMutableSet *set = [NSMutableSet set];
				
				for (DataStoreObject *o in value)
				{
					NSAtomicStoreCacheNode *cnode = [self cacheNodeForObjectID:[o objectID]];
					if (cnode)
						[set addObject:cnode];
				}
				if ([set count])
					[data setObject:set forKey:key];
			}
			else
			{
				NSAtomicStoreCacheNode *cnode = [self cacheNodeForObjectID:[value objectID]];
				if (cnode)
					[data setObject:cnode forKey:key];
			}
		}
		else
			[data setObject:[value copy] forKey:key];
	}
	[data setObject:obj.node forKey:@"node"];
	return data;
}

- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
	NSMutableDictionary *data = [self referenceObjectForObjectID:[managedObject objectID]];
	
	if (!data)
		data = [self newReferenceObjectForManagedObject:managedObject];
	return [self makeCacheNode:data forEntityName:[[managedObject entity] name]];
}

@end

@implementation AddInsListStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self && url)
	{
		NSError *error = nil;
		NSData *xmldata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:&error];
		
		if (!xmldata)
		{
			if ([url isFileURL] && [[error domain] isEqualToString:NSURLErrorDomain])
			{
				NSInteger code = [error code];
				
				if ((code == NSURLErrorCannotOpenFile) || (code == NSURLErrorZeroByteResource))
				{
					[[NSFileManager defaultManager] createFileAtPath:[url path] contents:nil attributes:nil];
				}
			}
			else
				[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not open URL %@", url] userInfo:nil] raise];
			xmldoc = nil;
		}
		else
			[self loadXML:xmldata];
		
		self.identifier = @"AddInsList";
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
	
	NSMutableSet *set = [NSMutableSet set];
	BOOL res = [self loadAddInsList:[xmldoc rootElement] error:error usingBlock:^(NSMutableDictionary *data, NSString *entityName)
	{
		id cnode = [self makeCacheNode:data forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	}];
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (BOOL)save:(NSError **)error
{
	BOOL res = [[xmldoc XMLDataWithOptions:NSXMLNodePrettyPrint] writeToURL:[self URL] options:0 error:error];
	
	return res;
}

- (BOOL)insertAddInNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context
{
	node = [node copy];
	
	BOOL res = [self loadAddInItem:node error:error usingBlock:^(NSMutableDictionary *data, NSString *entityName)
	{
		DataStoreObject *obj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
		
		for (NSString *key in data) {
			if ([key isEqualToString:@"node"])
				obj.node = [data objectForKey:key];
			else
				[obj setValue:[data objectForKey:key] forKey:key];
		}
		
		return obj;
	}];
	
	if (!res)
		return NO;
																
	[[xmldoc rootElement] addChild:node];
	return YES;
}

@end

@implementation AddInStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self && url)
	{
		NSError *error = nil;
		NSData *data;
		
		if (![url isFileURL])
		{
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not open URL %@", url] userInfo:nil] raise];
		}
		
		/* Make sure the file exists. */
		//[[NSFileManager defaultManager] createFileAtPath:[url path] contents:nil attributes:nil];
		
		struct archive *a = archive_read_new();
		struct archive_entry *entry;
		NSMutableData *xmldata = nil;
		int err;
		
		/* Used to do archive_read_open_memory, but couldn't get it to work. */
		archive_read_support_compression_all(a);
		archive_read_support_format_all(a);
		if (archive_read_open_filename(a, [[url path] cStringUsingEncoding:NSUTF8StringEncoding],
									   10 * 1024) != ARCHIVE_OK)
		{
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not read URL %@", url] userInfo:nil] raise];
		}
		
		while ((err = archive_read_next_header(a, &entry)) == ARCHIVE_OK)
		{
			const char *path = archive_entry_pathname(entry);
			
			if (strcasecmp(path, "Manifest.xml") == 0)
			{
				xmldata = [NSMutableData dataWithLength:archive_entry_size(entry)];
				
				if (archive_read_data(a, [xmldata mutableBytes], [xmldata length]) < [xmldata length])
				{
					archive_read_finish(a);
					[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not read Manifest.xml from URL %@", url] userInfo:nil] raise];
				}
				break;
			}
			archive_read_data_skip(a);
		}
		
		if (!xmldata && err != 1)
		{
			NSException *except = [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Archive error: %s", archive_error_string(a)] userInfo:nil];
			archive_read_finish(a);
			[except raise];
		}
		
		archive_read_finish(a);
		
		if (!xmldata)
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not find Manifest.xml in URL %@", url] userInfo:nil] raise];
		
		[self loadXML:xmldata];
		self.identifier = @"AddIn"; // XXX get a better one.
	}
	return self;
}

- (NSString *)type {
    return @"AddInStore";
}

- (BOOL)load:(NSError **)error
{
	if (!xmldoc)
		return YES;
	
	NSXMLElement *rootelem = [xmldoc rootElement];
	
	if (![[rootelem name] isEqualToString:@"Manifest"])
	{
		return NO;
	}
	
	NSMutableSet *set = [NSMutableSet set];
	BOOL res = [self loadAddInsList:(NSXMLElement*)[rootelem childAtIndex:0] error:error usingBlock:^(NSMutableDictionary *data, NSString *entityName)
	{
		id cnode = [self makeCacheNode:data forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	}];
	
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

@end