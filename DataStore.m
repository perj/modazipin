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
			/* Noop, don't know format. */
			continue;
		}
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

@end

@implementation AddInsListStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self && url)
	{
		NSError *error = nil;
		NSData *xmldata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:&error];
		
		if (!xmldata && [url isFileURL] && [[error domain] isEqualToString:NSURLErrorDomain])
		{
			NSInteger code = [error code];
			
			if ((code == NSURLErrorCannotOpenFile) || (code == NSURLErrorZeroByteResource))
			{
				[[NSFileManager defaultManager] createFileAtPath:[url path] contents:nil attributes:nil];
				xmldoc = nil;
			}
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
	NSMutableSet *set = [self loadAddInsList:[xmldoc rootElement] error:error];
	if (!set)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (BOOL)save:(NSError **)error
{
	return [[xmldoc XMLData] writeToURL:[self URL] atomically:YES];
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
	
	NSMutableSet *set = [self loadAddInsList:(NSXMLElement*)[rootelem childAtIndex:0] error:error];
	if (!set)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

@end