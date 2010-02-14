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

#import "DataStore.h"
#import "DataStoreObject.h"
#import "DazipArchive.h"

#include "erf.h"


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

- (void)loadXML:(NSData *)data ofType:(NSString*)rootType
{
	NSInteger xmlopt = NSXMLNodePreserveCharacterReferences | NSXMLNodePreserveWhitespace;
	NSError *error;
	
	NSAssert(xmldoc == nil, @"xmldoc != nil");
	
	xmldoc = [[NSXMLDocument alloc] initWithData:data options:xmlopt error:&error];
	
	if (!xmldoc)
	{
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not read XML"] userInfo:nil] raise];
	}
	
	NSXMLElement *rootelem = [xmldoc rootElement];
	
	if (![[rootelem name] isEqualToString:rootType])
	{
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"XML is not of type '%@'", rootType] userInfo:nil] raise];
	}
}

/*
 * Load a text node with DefaultText and language codes.
 */
- (id)loadText:(NSXMLElement*)node forItem:(id)addinitem error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	id res = createBlock(node, @"Text");
	
	if (!res)
		return nil;
	
	[data setObject:node forKey:@"node"];
	[data setObject:addinitem forKey:@"addInItem"];
	
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
										[[subnode stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], @"value",
										subnode, @"node",
										res, @"text",
										nil];
		id lnode = setBlock(createBlock(subnode, @"LocalizedText"), subdata);
		
		if (!lnode)
			return nil;
		
		[langset addObject:lnode];
	}
	if ([langset count])
		[data setObject:langset forKey:@"languages"];
	
	return setBlock(res, data);
}

- (id)loadModazipin:(NSXMLElement*)node forItem:(id)addinitem error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSXMLElement *pathsNode = nil;
	NSXMLElement *contentsNode = nil;
	NSMutableSet *paths = [NSMutableSet set];
	NSMutableSet *contents = [NSMutableSet set];
	id res = createBlock(node, @"Modazipin");
	
	if (!res)
		return nil;
	
	for (NSXMLElement *elem in [node children])
	{
		if ([[elem name] isEqualToString:@"paths"])
			pathsNode = elem;
		else if ([[elem name] isEqualToString:@"contents"])
			contentsNode = elem;
	}
	
	if (pathsNode)
	{
		for (NSXMLElement *elem in [pathsNode children])
		{
			NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 [elem name], @"type",
										 [[elem attributeForName:@"path"] stringValue], @"path",
										 elem, @"node",
										 res, @"modazipin",
										 nil];
			id pnode = setBlock(createBlock(elem, @"Path"), data);
			
			if (!pnode)
				return nil;
			
			[paths addObject:pnode];
		}
	}
	
	if (contentsNode)
	{
		for (NSXMLElement *elem in [contentsNode children])
		{
			NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 [[elem attributeForName:@"name"] stringValue], @"name",
										 elem, @"node",
										 res, @"modazipin",
										 nil];
			id cnode = setBlock(createBlock(elem, @"Content"), data);
			
			if (!cnode)
				return nil;
			
			[contents addObject:cnode];
		}
	}
	
	NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 paths, @"paths",
								 contents, @"contents",
								 node, @"node",
								 addinitem, @"addInItem",
								 nil];
	return setBlock(res, data);
}

/*
 * Load a single AddInItem node.
 */
- (id)loadAddInItem:(NSXMLElement *)node forManifest:(id)manifest error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data;
	id res;
	
	if (![[node name] isEqualToString:@"AddInItem"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInItem"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	res = createBlock(node, @"AddInItem");
	if (!res)
		return nil;
	
	data = [NSMutableDictionary dictionary];
	
	[data setObject:node forKey:@"node"];
	if (manifest)
		[data setObject:manifest forKey:@"manifest"];
	
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
			id tnode = [self loadText:subnode forItem:res error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
			
			if (!tnode)
				return nil;
			
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
		
		if ([[subnode name] isEqualToString:@"PrereqList"])
		{
			/* Noop, don't know format. */
			continue;
		}
		
		if ([[subnode name] isEqualToString:@"modazipin"])
		{
			id mnode = [self loadModazipin:subnode forItem:res error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
			
			if (!mnode)
				return nil;
			
			[data setObject:mnode forKey:[subnode name]];
			continue;
		}
	}
	
	return setBlock(res, data);
}

/*
 * Load an AddInsList node
 */
- (BOOL)loadAddInsList:(NSXMLElement *)node error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	/* XXX should probably return error instead of exception */
	if (![[node name] isEqualToString:@"AddInsList"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:@"Node is not an AddInsList"
							   userInfo:[NSDictionary dictionaryWithObject:node forKey:@"node"]] raise];
	
	for (NSXMLElement *subnode in [node children]) {
		id res = [self loadAddInItem:subnode forManifest:nil error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
		
		if (!res)
			return NO;
	}
	
	return YES;
}

- (NSString*)uniqueForNode:(NSXMLNode*)node
{
	NSXMLNode *parent = [node parent];
	NSString *me = [node name];
	
	if ([me isEqualToString:@"AddInItem"])
		return [[(NSXMLElement *)node attributeForName:@"UID"] stringValue];
	
	if ([me isEqualToString:@"file"] || [me isEqualToString:@"dir"])
		me = [NSString stringWithFormat:@"%@:%@", me, [[(NSXMLElement*)node attributeForName:@"path"] stringValue]];
	else if ([me isEqualToString:@"content"])
		me = [NSString stringWithFormat:@"content:%@", [[(NSXMLElement*)node attributeForName:@"name"] stringValue]];
	
	if ([node level] == 1 || !parent)
		return me;
	
	return [[self uniqueForNode:parent] stringByAppendingFormat:@"/%@", me];
}

- (id)makeCacheNode:(NSXMLElement*)elem forEntityName:(NSString*)name
{
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:name];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:[self uniqueForNode:elem]];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
	
	return cnode;
}

- (NSXMLElement*)makeModazipinNodeForContents:(NSSet*)contents files:(NSSet*)files dirs:(NSSet*)dirs
{
	NSXMLElement *res = [NSXMLElement elementWithName:@"modazipin"];
	
	NSXMLElement *paths = [NSXMLElement elementWithName:@"paths"];
	
	for (NSString *file in files)
	{
		NSXMLElement *fileNode = [NSXMLElement elementWithName:@"file"];
		
		[fileNode addAttribute:[NSXMLNode attributeWithName:@"path" stringValue:file]];
		[paths addChild:fileNode];
	}
	
	for (NSString *dir in dirs)
	{
		NSXMLElement *dirNode = [NSXMLElement elementWithName:@"dir"];
		
		[dirNode addAttribute:[NSXMLNode attributeWithName:@"path" stringValue:dir]];
		[paths addChild:dirNode];
	}
	
	[res addChild:paths];
	
	NSXMLElement *contentsNode = [NSXMLElement elementWithName:@"contents"];
	
	for (NSString *content in contents)
	{
		NSXMLElement *contentNode = [NSXMLElement elementWithName:@"content"];
		
		[contentNode addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:content]];
		[contentsNode addChild:contentNode];
	}
	
	[res addChild:contentsNode];
	return res;
}

@end


@implementation DataStore (AtomicStoreCallbacks)

- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	NSXMLElement *elem = (NSXMLElement*)obj.node;
	NSXMLNode *attr;
	AddInItem *item;
	
	/* Only support updating Enabled for now */
	
	if (![[elem name] isEqualToString:@"AddInItem"])
		return;
	
	item = (AddInItem*)obj;
	attr = [elem attributeForName:@"Enabled"];
	if ([item.Enabled intValue])
		[attr setStringValue:@"1"];
	else
		[attr setStringValue:@"0"];
	[node setValue:item.Enabled forKey:@"Enabled"];
}

- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	
	return [self uniqueForNode:obj.node];
}

- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
	/* This function is completely generic. */
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	NSAtomicStoreCacheNode *cnode;
	
	for (NSPropertyDescription *prop in [managedObject entity])
	{
		NSString *key = [prop name];
		id value = [managedObject valueForKey:key];
		
		if (!value)
			continue;
		
		if ([[prop class] isSubclassOfClass:[NSRelationshipDescription class]])
		{
			NSRelationshipDescription *rel = (NSRelationshipDescription*)prop;
			
			if ([rel isToMany])
			{
				NSMutableSet *set = [NSMutableSet set];
				
				for (NSManagedObject *o in value)
				{
					cnode = [self cacheNodeForObjectID:[o objectID]];
					
					if (!cnode)
					{
						cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[o objectID]];
						[self addCacheNodes:[NSSet setWithObject:cnode]];
					}
					[set addObject:cnode];
				}
				[data setObject:set forKey:key];
			}
			else
			{
				NSManagedObject *o = value;
				
				cnode = [self cacheNodeForObjectID:[o objectID]];
				if (!cnode)
				{
					cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[o objectID]];
					[self addCacheNodes:[NSSet setWithObject:cnode]];
				}
				[data setObject:cnode forKey:key];
			}
		}
		else
			[data setObject:[value copy] forKey:key];
	}
	
	cnode = [self cacheNodeForObjectID:[managedObject objectID]];
	if (!cnode)
		cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[managedObject objectID]];
	[cnode setPropertyCache:data];
	return cnode;
}

- (void)willRemoveCacheNodes:(NSSet *)cacheNodes
{
	for (NSAtomicStoreCacheNode *cnode in cacheNodes)
	{
		NSXMLNode *node = [[cnode propertyCache] objectForKey:@"node"];
		
		[node detach];
	}
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
			[self loadXML:xmldata ofType:@"AddInsList"];
		
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
	BOOL res = [self loadAddInsList:[xmldoc rootElement] error:error
				   usingCreateBlock:^(NSXMLElement *elem, NSString *entityName)
	{
		id cnode = [self makeCacheNode:elem forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	} usingSetBlock:^(id obj, NSMutableDictionary *data)
	{
		[obj setPropertyCache:data];
		
		return obj;
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
	
	id res = [self loadAddInItem:node forManifest:nil error:error usingCreateBlock:^(NSXMLElement *elem, NSString *entityName)
	{
		return [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
	} usingSetBlock:^(id obj, NSMutableDictionary *data)
	{
		for (NSString *key in data) {
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
		/* XXX guessing encoding. */
		DazipArchive *archive = [DazipArchive archiveForReadingFromURL:url encoding:NSWindowsCP1252StringEncoding error:nil];
		NSData *xmldata = nil;

		NSMutableSet *files = [NSMutableSet set];
		NSMutableSet *dirs = [NSMutableSet set];
		NSMutableSet *contents = [NSMutableSet set];
		
		for (DazipArchiveMember *entry in archive)
		{
			switch (entry.type)
			{
			case dmtManifest:
				xmldata = [entry data];
				break;
			case dmtERF:
				{
					NSData *erfdata = entry.data;
					
					parse_erf_data([erfdata bytes], [erfdata length],
								^(struct erf_header *header, struct erf_file *file)
					{
						int len = 0;
						
						while (len < ERF_FILENAME_MAXLEN && file->entry->name[len] != 0)
							len++;
						
						[contents addObject:[[NSString alloc] initWithBytes:file->entry->name
																	 length:len * 2
																   encoding:NSUTF16LittleEndianStringEncoding]];
					});
				}
				/* Fall through */
				if (0)
				{
			case dmtFile:
					[contents addObject:entry.contentName];
				}
				switch (entry.contentType)
				{
				case dmctFile:
					[files addObject:entry.contentPath];
					break;
				case dmctDirectory:
					[dirs addObject:entry.contentPath];
					break;
				}
				break;
			}
		}
		
		if (!xmldata)
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not find Manifest.xml in URL %@", url] userInfo:nil] raise];
		
		[self loadXML:xmldata ofType:@"Manifest"];
		
		NSXMLElement *addinNode = [self verifyManifest];
		
		/* Filter files and dirs to only be those paths outside of the addin main directory. */
		NSPredicate *notInAddin = [NSPredicate predicateWithFormat:@"NOT (SELF ==[c] %@)",
								   [NSString stringWithFormat:@"Addins/%@",
									[[addinNode attributeForName:@"UID"] stringValue]]];
		[files filterUsingPredicate:notInAddin];
		[dirs filterUsingPredicate:notInAddin];
		
		NSXMLElement *modNode = [self makeModazipinNodeForContents:contents files:files dirs:dirs];
		
		[addinNode addChild:modNode];
		
		self.identifier = [[addinNode attributeForName:@"UID"] stringValue];
	}
	return self;
}

- (NSString *)type {
    return @"AddInStore";
}

- (NSXMLElement *)verifyManifest
{
	NSXMLElement *root = [xmldoc rootElement];
	
	if (![[[root attributeForName:@"Type"] stringValue] isEqualToString:@"AddIn"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Manifest type is not AddIn"] userInfo:nil] raise];
	
	if ([root childCount] < 1)
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"No contents in manifest"] userInfo:nil] raise];

	if ([root childCount] > 1)
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Unexpected contents in manifest"] userInfo:nil] raise];
	
	NSXMLElement *addinslistNode = (NSXMLElement*)[root childAtIndex:0];
	
	if (![[addinslistNode name] isEqualToString:@"AddInsList"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Manifest contents is not AddInsList"] userInfo:nil] raise];

	if ([addinslistNode childCount] < 1)
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"No addins listed"] userInfo:nil] raise];
	
	if ([addinslistNode childCount] > 1)
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"More than one addin listed"] userInfo:nil] raise];
	
	NSXMLElement *addinNode = (NSXMLElement*)[addinslistNode childAtIndex:0];
	
	if (![[addinNode name] isEqualToString:@"AddInItem"])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Unexpected AddIn kind"] userInfo:nil] raise];
	
	if (![[[addinNode attributeForName:@"UID"] stringValue] length])
		[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"No UID for AddIn"] userInfo:nil] raise];
	
	return addinNode;
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
	BOOL res = [self loadAddInsList:(NSXMLElement*)[rootelem childAtIndex:0] error:error
						 usingCreateBlock:^(NSXMLElement *elem, NSString *entityName)
	{
		id cnode = [self makeCacheNode:elem forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	} usingSetBlock:^(id obj, NSMutableDictionary *data)
	{
		[obj setPropertyCache:data];
		
		return obj;
	}];
	
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

@end
