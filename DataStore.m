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

@implementation NSAtomicStore (CacheNodeCreation)

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
			[data setObject:value forKey:key];
	}
	
	cnode = [self cacheNodeForObjectID:[managedObject objectID]];
	if (!cnode)
		cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[managedObject objectID]];
	[cnode setPropertyCache:data];
	return cnode;
}

@end

@interface DataStore (Errors)

- (NSError*)dataStoreError:(NSInteger)code msg:(NSString*)fmt, ... NS_FORMAT_FUNCTION(2,3);

@end

@implementation DataStore (Errors)

- (NSError*)dataStoreError:(NSInteger)code msg:(NSString*)fmt, ...
{
	va_list ap;
	
	va_start(ap, fmt);
	NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);
	
	return [NSError errorWithDomain:@"DataStoreError" code:code userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																		  msg, NSLocalizedDescriptionKey,
																		  [self URL], NSURLErrorKey,
																		  nil]];
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

- (BOOL)loadXML:(NSData *)data ofType:(NSString*)rootType error:(NSError**)error
{
	NSInteger xmlopt = NSXMLNodePreserveCharacterReferences | NSXMLNodePreserveWhitespace;
	
	NSAssert(xmldoc == nil, @"xmldoc != nil");
	
	xmldoc = [[NSXMLDocument alloc] initWithData:data options:xmlopt error:error];
	
	if (!xmldoc)
		return NO;
	
	NSXMLElement *rootelem = [xmldoc rootElement];
	
	if (![[rootelem name] isEqualToString:rootType])
	{
		if (error)
			*error = [self dataStoreError:4 msg:@"XML is not of type '%@'", rootType];
		return NO;
	}
	
	return YES;
}


/*
 * Load a text node with DefaultText and language codes.
 */
- (id)loadText:(NSXMLNode*)node forItem:(id)item error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	id res = createBlock(node, @"Text");
	
	if (!res)
		return nil;
	
	[data setObject:node forKey:@"node"];
	[data setObject:item forKey:@"item"];
	
	for (NSXMLNode *attr in [(NSXMLElement*)node attributes])
	{
		if ([[attr name] isEqualToString:@"DefaultText"])
		{
			[data setObject:[attr stringValue] forKey:[attr name]];
			continue;
		}
	}
	
	NSMutableSet *langset = [NSMutableSet set];
	for (NSXMLNode *subnode in [node children])
	{
		if ([subnode kind] == NSXMLTextKind)
		{
			/* Short circuit for simple text. */
			[data setObject:[subnode stringValue] forKey:@"DefaultText"];
			continue;
		}
		
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

- (id)loadModazipin:(NSXMLElement*)node forItem:(id)item error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSXMLElement *pathsNode = nil;
	NSMutableSet *paths = [NSMutableSet set];
	id res = createBlock(node, @"Modazipin");
	
	if (!res)
		return nil;
	
	for (NSXMLElement *elem in [node children])
	{
		if ([[elem name] isEqualToString:@"paths"])
			pathsNode = elem;
		else if ([[elem name] isEqualToString:@"contents"])
			[elem detach];
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
	
	NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 paths, @"paths",
								 node, @"node",
								 item, @"item",
								 nil];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"origGameVersion"])
		{
			[data setObject:[attr stringValue] forKey:[attr name]];
			continue;
		}
	}
	
	return setBlock(res, data);
}

/*
 * Load data common for AddIns and Offers
 */
- (NSMutableDictionary*)loadItem:(id)item node:(NSXMLElement*)node forManifest:(id)manifest error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	
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
			|| [[attr name] isEqualToString:@"Format"]
			|| [[attr name] isEqualToString:@"BioWare"])
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
			id tnode = [self loadText:subnode forItem:item error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
			
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
			id mnode = [self loadModazipin:subnode forItem:item error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
			
			if (!mnode)
				return nil;
			
			[data setObject:mnode forKey:[subnode name]];
			continue;
		}
	}
	
	return data;
}

/*
 * Load a single AddInItem node.
 */
- (id)loadAddInItem:(NSXMLElement *)node forManifest:(id)manifest error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data;
	id res;
	
	if (![[node name] isEqualToString:@"AddInItem"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an AddInItem"];
		return nil;
	}
	
	res = createBlock(node, @"AddInItem");
	if (!res)
		return nil;
	
	data = [self loadItem:res node:node forManifest:manifest error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	if (!data)
		return nil;
	
	[data setValue:[NSNumber numberWithBool:YES] forKey:@"displayed"];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"Enabled"]
			|| [[attr name] isEqualToString:@"State"]
			|| [[attr name] isEqualToString:@"RequiresAuthorization"])
		{
			[data setObject:[NSDecimalNumber decimalNumberWithString:[attr stringValue]] forKey:[attr name]];
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
	if (![[node name] isEqualToString:@"AddInsList"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an AddInsList"];
		return NO;
	}
	
	for (NSXMLElement *subnode in [node children]) {
		id res = [self loadAddInItem:subnode forManifest:nil error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
		
		if (!res)
			return NO;
	}
	
	return YES;
}

/*
 * Load an AddinManifest. Currently just loads the list.
 */
- (BOOL)loadAddInManifest:(NSXMLElement *)node error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	return [self loadAddInsList:(NSXMLElement*)[node childAtIndex:0] error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
}

/*
 * Load a PRCList node with PRCItem subnodes.
 */
- (id)loadPRCList:(NSXMLElement*)node forOfferItem:(id)item error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableSet *pset = [NSMutableSet set];
	
	for (NSXMLElement *subnode in [node children])
	{
		NSMutableDictionary *data = [NSMutableDictionary dictionary];
		id pnode = createBlock(subnode, @"PRCItem");
		
		if (!pnode)
			return nil;
		
		[data setObject:subnode forKey:@"node"];
		[data setObject:item forKey:@"offerItem"];
		
		for (NSXMLNode *attr in [subnode attributes])
		{
			if ([[attr name] isEqualToString:@"ProductID"]
				|| [[attr name] isEqualToString:@"microContentID"]
				|| [[attr name] isEqualToString:@"Version"])
			{
				[data setObject:[attr stringValue] forKey:[attr name]];
				continue;
			}
		}
		
		for (NSXMLElement *subsubnode in [subnode children])
		{
			if ([[subsubnode name] isEqualToString:@"Title"])
			{
				id tnode = [self loadText:subsubnode forItem:pnode error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
				
				if (!tnode)
					return nil;
				
				[data setObject:tnode forKey:[subsubnode name]];
				continue;
			}
		}
		
		pnode = setBlock(pnode, data);
		if (!pnode)
			return nil;
		
		[pset addObject:pnode];
	}
	return pset;
}

/*
 * Load a single OfferItem node.
 */
- (id)loadOfferItem:(NSXMLElement *)node forManifest:(id)manifest error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data;
	id res;
	
	if (![[node name] isEqualToString:@"OfferItem"] && ![[node name] isEqualToString:@"DisabledOfferItem"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an OfferItem"];
		return nil;
	}
	
	res = createBlock(node, @"OfferItem");
	if (!res)
		return nil;
	
	data = [self loadItem:res node:node forManifest:manifest error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	if (!data)
		return nil;
	
	[data setObject:[NSNumber numberWithBool:NO] forKey:@"displayed"];
	[data setObject:[[node name] isEqualToString:@"OfferItem"] ? [NSDecimalNumber one] : [NSDecimalNumber zero]
			 forKey:@"Enabled"];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"Presentation"])
		{
			[data setObject:[NSDecimalNumber decimalNumberWithString:[attr stringValue]] forKey:[attr name]];
			continue;
		}
	}
	
	for (NSXMLElement *subnode in [node children])
	{
		if ([[subnode name] isEqualToString:@"PRCList"])
		{
			NSMutableSet *pset = [self loadPRCList:subnode forOfferItem:res error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
			
			if (!pset)
				return NO;
			
			[data setObject:pset forKey:[subnode name]];
			continue;
		}
	}
	
	return setBlock(res, data);
}

/*
 * Load an OfferList node
 */
- (BOOL)loadOfferList:(NSXMLElement *)node error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	if (![[node name] isEqualToString:@"OfferList"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an OfferList"];
		return NO;
	}
	
	for (NSXMLElement *subnode in [node children]) {
		id res = [self loadOfferItem:subnode forManifest:nil error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
		
		if (!res)
			return NO;
	}
	
	return YES;
}

/*
 * Load an OfferManifest. Currently just loads the list.
 */
- (BOOL)loadOfferManifest:(NSXMLElement *)node error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	return [self loadOfferList:(NSXMLElement*)[node childAtIndex:0] error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
}

/*
 * Load a single OverrideItem node.
 */
- (id)loadOverrideItem:(NSXMLElement *)node forManifest:(id)manifest error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	NSMutableDictionary *data;
	id res;
	
	if (![[node name] isEqualToString:@"OverrideItem"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an OverrideItem"];
		return nil;
	}
	
	res = createBlock(node, @"OverrideItem");
	if (!res)
		return nil;
	
	data = [self loadItem:res node:node forManifest:manifest error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	if (!data)
		return nil;
	
	[data setObject:[NSNumber numberWithBool:YES] forKey:@"displayed"];
	[data setObject:[NSDecimalNumber one] forKey:@"Enabled"];
	
	for (NSXMLNode *attr in [node attributes])
	{
		if ([[attr name] isEqualToString:@"Name"])
		{
			[data setObject:[attr stringValue] forKey:@"UID"];
			continue;
		}
	}
	
	return setBlock(res, data);
}

/*
 * Load an OverrideList node
 */
- (BOOL)loadOverrideList:(NSXMLElement *)node error:(NSError **)error usingCreateBlock:(createObjBlock)createBlock usingSetBlock:(setDataBlock)setBlock
{
	if (![[node name] isEqualToString:@"OverrideList"])
	{
		if (error)
			*error = [self dataStoreError:5 msg:@"Node is not an OverrideList"];
		return NO;
	}
	
	for (NSXMLElement *subnode in [node children]) {
		id res = [self loadOverrideItem:subnode forManifest:nil error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
		
		if (!res)
			return NO;
	}
	
	return YES;
}

- (NSString*)uniqueForNode:(NSXMLElement*)node
{
	NSXMLNode *parent = [node parent];
	NSString *me = [node name];
	
	if ([me isEqualToString:@"AddInItem"] || [me isEqualToString:@"OfferItem"] || [me isEqualToString:@"DisabledOfferItem"])
		return [[(NSXMLElement *)node attributeForName:@"UID"] stringValue];
	if ([me isEqualToString:@"OverrideItem"])
		return [[(NSXMLElement *)node attributeForName:@"Name"] stringValue];
	
	if ([me isEqualToString:@"file"] || [me isEqualToString:@"dir"])
		me = [NSString stringWithFormat:@"%@:%@", me, [[(NSXMLElement*)node attributeForName:@"path"] stringValue]];
	else if ([me isEqualToString:@"content"])
		me = [NSString stringWithFormat:@"content:%@", [[(NSXMLElement*)node attributeForName:@"name"] stringValue]];
	
	if ([node level] == 1 || !parent)
		return me;
	
	return [[self uniqueForNode:(NSXMLElement*)parent] stringByAppendingFormat:@"/%@", me];
}

- (id)makeCacheNode:(NSXMLElement*)elem forEntityName:(NSString*)name
{
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:name];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:[self uniqueForNode:elem]];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
	
	return cnode;
}

- (NSXMLElement*)makeModazipinNodeForFiles:(NSSet*)files dirs:(NSSet*)dirs
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
	
	return res;
}

- (NSArray *)verifyManifestOfType:(NSString*)manifestType listNodeType:(NSString*)listNodeType error:(NSError**)error
{
	NSXMLElement *root = [xmldoc rootElement];
	
	if (![[[root attributeForName:@"Type"] stringValue] isEqualToString:manifestType])
	{
		if (error)
			*error = [self dataStoreError:6 msg:@"Manifest type is not %@", manifestType];
		return nil;
	}
	
	if ([root childCount] < 1)
	{
		if (error)
			*error = [self dataStoreError:7 msg:@"No contents in manifest"];
		return nil;
	}
	
	if ([root childCount] > 1)
	{
		if (error)
			*error = [self dataStoreError:8 msg:@"Unexpected contents in manifest"];
		return nil;
	}
	
	NSXMLElement *listNode = (NSXMLElement*)[root childAtIndex:0];
	
	if (![[listNode name] isEqualToString:listNodeType])
	{
		if (error)
			*error = [self dataStoreError:9 msg:@"Manifest contents is not %@", listNodeType];
		return nil;
	}
	
	if ([listNode childCount] < 1)
	{
		if (error)
			*error = [self dataStoreError:10 msg:@"No contents in list"];
		return nil;
	}
	
	NSArray *itemNodes = [listNode children];
	
	for (NSXMLElement *itemNode in itemNodes)
	{
		if (![[itemNode name] isEqualToString:[NSString stringWithFormat:@"%@Item", manifestType]])
		{
			if (error)
				*error = [self dataStoreError:12 msg:@"Unexpected item kind"];
			return nil;
		}
		
		if (![[[itemNode attributeForName:@"UID"] stringValue] length])
		{
			if (error)
				*error = [self dataStoreError:13 msg:@"No UID for item"];
			return nil;
		}
	}
	
	return itemNodes;
}

- (Item*)insertItemNode:(NSXMLElement*)node usingSelector:(SEL)sel error:(NSError **)error intoContext:(NSManagedObjectContext*)context
{
	node = [node copy];
	
	IMP imp = [self methodForSelector:sel];
	if (!imp)
		[NSException raise:NSInvalidArgumentException format:@"%s is not a method of this object.", (char*)sel];
	
	id res = (*imp)(self, sel, node, nil, error, ^(NSXMLElement *elem, NSString *entityName)
			  {
				  return [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
			  }, ^(id obj, NSMutableDictionary *data)
			  {
				  for (NSString *key in data) {
					  [obj setValue:[data objectForKey:key] forKey:key];
				  }
				  [context assignObject:obj toPersistentStore:self];
				  if ([obj isKindOfClass:[Path self]])
					  [obj setValue:[NSNumber numberWithBool:YES] forKey:@"verified"];
				  return obj;
			  });
	
	if (!res)
		return nil;
	
	[[xmldoc rootElement] addChild:node];
	return res;
}

@end


@implementation DataStore (AtomicStoreCallbacks)

- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
	if (![managedObject isKindOfClass:[DataStoreObject self]])
		return;
	
	NSXMLElement *elem = (NSXMLElement*)[managedObject valueForKey:@"node"];
	NSXMLNode *attr;
	
	if ([managedObject isKindOfClass:[Item self]])
	{
		Item *item = (Item*)managedObject;
		
		if ([[[managedObject entity] name] isEqualToString:@"AddInItem"])
		{
			attr = [elem attributeForName:@"Enabled"];
			if ([item.Enabled intValue])
				[attr setStringValue:@"1"];
			else
				[attr setStringValue:@"0"];
		}
		else if ([[[managedObject entity] name] isEqualToString:@"OfferItem"])
		{
			if ([item.Enabled intValue])
				[elem setName:@"OfferItem"];
			else
				[elem setName:@"DisabledOfferItem"];
		}
		
		for (NSXMLNode *child in [elem children])
		{
			if ([[child name] isEqualToString:@"GameVersion"])
				[child setStringValue:item.GameVersion];
		}
		
		[node setValue:item.Enabled forKey:@"Enabled"];
		[node setValue:item.GameVersion forKey:@"GameVersion"];
		
	}
	else if ([[[managedObject entity] name] isEqualToString:@"Modazipin"])
	{
		Modazipin *modazipin = (Modazipin*)managedObject;
		
		if (modazipin.origGameVersion)
		{
			attr = [elem attributeForName:@"origGameVersion"];
			
			if (attr)
				[attr setStringValue:modazipin.origGameVersion];
			else
			{
				attr = [NSXMLNode attributeWithName:@"origGameVersion" stringValue:modazipin.origGameVersion];
				[elem addAttribute:attr];
			}
		}
	}
}

- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	
	return [self uniqueForNode:(NSXMLElement*)obj.node];
}

- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
	/* Create a node if needed. */
	if ([managedObject isKindOfClass:[DataStoreObject self]] && ![managedObject valueForKey:@"node"])
	{
		if ([[[managedObject entity] name] isEqualToString:@"Modazipin"])
		{
			Modazipin *modazipin = (Modazipin*)managedObject;
			
			if (modazipin.item.node)
			{
				NSXMLElement *elem = [NSXMLElement elementWithName:@"modazipin"];
				[(NSXMLElement*)modazipin.item.node addChild:elem];
				modazipin.node = elem;
			}
		}
	}
	
	return [super newCacheNodeForManagedObject:managedObject];
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
		NSData *xmldata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:&loadError];

		if (xmldata)
			[self loadXML:xmldata ofType:@"AddInsList" error:&loadError];
		
		self.identifier = @"AddInsList";
	}
	return self;
}

- (BOOL)load:(NSError **)error
{
	if (loadError)
	{
		if (error)
			*error = loadError;
		loadError = nil;
		return NO;
	}
	
	if (!xmldoc)
		return YES;
	
	NSMutableSet *set = [NSMutableSet set];
	BOOL res = [self loadAddInsList:[xmldoc rootElement] error:error usingCreateBlock:
						  ^(NSXMLNode *elem, NSString *entityName)
						  {
							  id cnode = [self makeCacheNode:elem forEntityName:entityName];
							  
							  [set addObject:cnode];
							  return cnode;
						  } usingSetBlock:
						  ^(id obj, NSMutableDictionary *data)
						  {
							  [obj setPropertyCache:data];
							  
							  return obj;
						  }];
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (NSString *)type {
    return @"AddInsListStore";
}

- (BOOL)save:(NSError **)error
{
	BOOL res = [[xmldoc XMLDataWithOptions:NSXMLNodePrettyPrint] writeToURL:[self URL] options:0 error:error];
	
	return res;
}

- (AddInItem*)insertAddInNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context
{
	return (AddInItem*)[self insertItemNode:node usingSelector:@selector(loadAddInItem:forManifest:error:usingCreateBlock:usingSetBlock:) error:error intoContext:context];
}

@end

@implementation OfferListStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self && url)
	{
		NSData *xmldata = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:&loadError];
		
		if (xmldata)
			[self loadXML:xmldata ofType:@"OfferList" error:&loadError];
		
		self.identifier = @"OfferList";
	}
	return self;
}

- (BOOL)load:(NSError **)error
{
	if (loadError)
	{
		if (error)
			*error = loadError;
		loadError = nil;
		return NO;
	}
	
	if (!xmldoc)
		return YES;
	
	NSMutableSet *set = [NSMutableSet set];
	BOOL res = [self loadOfferList:[xmldoc rootElement] error:error usingCreateBlock:
				^(NSXMLNode *elem, NSString *entityName)
				{
					id cnode = [self makeCacheNode:elem forEntityName:entityName];
					
					[set addObject:cnode];
					return cnode;
				} usingSetBlock:
				^(id obj, NSMutableDictionary *data)
				{
					[obj setPropertyCache:data];
					
					return obj;
				}];
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (NSString *)type {
    return @"OfferListStore";
}

- (BOOL)save:(NSError **)error
{
	BOOL res = [[xmldoc XMLDataWithOptions:NSXMLNodePrettyPrint] writeToURL:[self URL] options:0 error:error];
	
	return res;
}

- (OfferItem*)insertOfferNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context
{
	return (OfferItem*)[self insertItemNode:node usingSelector:@selector(loadOfferItem:forManifest:error:usingCreateBlock:usingSetBlock:) error:error intoContext:context];
}

@end


@implementation ArchiveStore

- (NSDictionary*)loadArchive:(NSURL *)url class:(Class)archClass error:(NSError**)error
{
	/* XXX guessing encoding. */
	id archive = [archClass archiveForReadingFromURL:url encoding:NSWindowsCP1252StringEncoding error:error];
	NSData *xmldata = nil;
	
	if (!archive)
		return nil;
	
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
	
	[self willChangeValueForKey:@"uncompressedSize"];
	uncompressedSize = ((ArchiveWrapper*)archive).uncompressedOffset;
	[self didChangeValueForKey:@"uncompressedSize"];
	
	if (!xmldata)
	{
		if (error)
			*error = [self dataStoreError:2 msg:@"Could not find manifest"];
		return nil;
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			xmldata, @"manifest",
			files, @"files",
			dirs, @"directories",
			contents, @"contents",
			nil];
}

@synthesize uncompressedSize;

@end


@implementation DazipStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options {
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self)
	{
		NSDictionary *dazipData = [self loadArchive:url class:[DazipArchive self] error:&loadError];
		
		if (!dazipData)
			return self;
		
		NSData *xmldata = [dazipData objectForKey:@"manifest"];
		NSMutableSet *files = [dazipData objectForKey:@"files"];
		NSMutableSet *dirs = [dazipData objectForKey:@"directories"];
		//NSMutableSet *contents = [dazipData objectForKey:@"contents"];
		
		if (![self loadXML:xmldata ofType:@"Manifest" error:&loadError])
			return self;
		
		NSString *manifestType = [[[xmldoc rootElement] attributeForName:@"Type"] stringValue];
		NSString *listNodeType = nil;
		NSString *mainDirectory = nil;
		
		if ([manifestType isEqualToString:@"AddIn"])
		{
			listNodeType = @"AddInsList";
			mainDirectory = @"Addins";
		}
		else if ([manifestType isEqualToString:@"Offer"])
		{
			listNodeType = @"OfferList";
			mainDirectory = @"Offers";
		}
		else
		{
			loadError = [self dataStoreError:1 msg:@"Unknown manifest type"];
			return self;
		}
			
		NSArray *itemNodes = [self verifyManifestOfType:manifestType listNodeType:listNodeType error:&loadError];
		if (!itemNodes)
			return self;
		
		for (NSXMLElement *itemNode in itemNodes)
		{
			/* Filter files and dirs to only be those paths outside of the addin main directory. */
			NSPredicate *notInItem = [NSPredicate predicateWithFormat:@"NOT (SELF ==[c] %@)",
									   [NSString stringWithFormat:@"%@/%@", mainDirectory,
										[[itemNode attributeForName:@"UID"] stringValue]]];
			[files filterUsingPredicate:notInItem];
			[dirs filterUsingPredicate:notInItem];
		}
		
		/* Also filter any items in Addins/ or Offers/ that are not in the main dir, since they'll be moved there
		 * when installing.
		 */
		NSPredicate *otherItems = [NSPredicate predicateWithFormat:@"NOT (SELF BEGINSWITH[c] 'Addins/' OR SELF BEGINSWITH[c] 'Offers/')"];
		
		[files filterUsingPredicate:otherItems];
		[dirs filterUsingPredicate:otherItems];
		
		if ([itemNodes count] > 1)
		{
			/*
			 * This part is tricky. We need to figure out what path is connected to what item.
			 * Heuristics, mostly.
			 */
			
			NSMutableDictionary *assignedfiles = [NSMutableDictionary dictionaryWithCapacity:[itemNodes count]];
			NSMutableDictionary *assigneddirs = [NSMutableDictionary dictionaryWithCapacity:[itemNodes count]];
			
			for (NSMutableSet *c in [NSArray arrayWithObjects:files, dirs, nil])
			{
				for (NSString *p in c)
				{
					int bestscore = 0;
					NSString *bestUid = nil;
					
					for (NSXMLElement *itemNode in itemNodes)
					{
						NSString *uid = [[itemNode attributeForName:@"UID"] stringValue];
						NSRange r = [p rangeOfString:[NSString stringWithFormat:@"/%@/", uid] options:NSCaseInsensitiveSearch];
						int score = 0;
						
						if (r.length > 0)
						{
							score = 4;
							goto scored;
						}
						r = [p rangeOfString:[NSString stringWithFormat:@"/%@.", uid] options:NSCaseInsensitiveSearch];
						if (r.length > 0)
						{
							score = 3;
							goto scored;
						}
						r = [p rangeOfString:[NSString stringWithFormat:@"/%@", uid] options:NSCaseInsensitiveSearch];
						if (r.length > 0)
						{
							score = 2;
							goto scored;
						}
						r = [p rangeOfString:[NSString stringWithFormat:@"%@", uid] options:NSCaseInsensitiveSearch];
						if (r.length > 0)
						{
							score = 1;
							goto scored;
						}
					scored:
						if (score > bestscore)
						{
							bestscore = score;
							bestUid = uid;
						}
					}
					
					if (!bestUid)
					{
						/* Fallback to first item. */
						/* XXX think this over. */
						bestUid = [[[itemNodes objectAtIndex:0] attributeForName:@"UID"] stringValue];
					}
					
					NSMutableDictionary *tgt;
					NSMutableArray *a;
					
					if (c == files)
						tgt = assignedfiles;
					else
						tgt = assigneddirs;
					
					a = [tgt objectForKey:bestUid];
					if (!a)
					{
						a = [NSMutableArray array];
						[tgt setObject:a forKey:bestUid];
					}
					[a addObject:p];
				}
			}
			
			for (NSXMLElement *itemNode in itemNodes)
			{
				NSString *uid = [[itemNode attributeForName:@"UID"] stringValue];
				NSXMLElement *modNode = [self makeModazipinNodeForFiles:[assignedfiles objectForKey:uid] dirs:
										 [assigneddirs objectForKey:uid]];
				
				[itemNode addChild:modNode];
			}
		}
		else
		{
			NSXMLElement *modNode = [self makeModazipinNodeForFiles:files dirs:dirs];
			
			[[itemNodes objectAtIndex:0] addChild:modNode];
		}
		
		self.identifier = [[[itemNodes objectAtIndex:0] attributeForName:@"UID"] stringValue];
	}
	return self;
}

- (BOOL)load:(NSError **)error
{
	if (loadError)
	{
		if (error)
			*error = loadError;
		loadError = nil;
		return NO;
	}
	
	if (!xmldoc)
		return YES;
	
	NSString *manifestType = [[[xmldoc rootElement] attributeForName:@"Type"] stringValue];
	NSMutableSet *set = [NSMutableSet set];
	BOOL res;
	
	createObjBlock createBlock = ^(NSXMLNode *elem, NSString *entityName)
	{
		id cnode = [self makeCacheNode:elem forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	};
	
	setDataBlock setBlock = ^(id obj, NSMutableDictionary *data)
	{
		[obj setPropertyCache:data];
		
		return obj;
	};
	
	if ([manifestType isEqualToString:@"AddIn"])
		res = [self loadAddInManifest:[xmldoc rootElement] error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	else
		res = [self loadOfferManifest:[xmldoc rootElement] error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (NSString *)type {
    return @"DazipStore";
}

@end

@implementation OverrideStore

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options
{
	self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	if (self)
	{
		NSDictionary *overrideData = [self loadArchive:url class:[OverrideArchive self] error:&loadError];
		
		NSData *xmldata = [overrideData objectForKey:@"manifest"];
		NSMutableSet *files = [overrideData objectForKey:@"files"];
		NSMutableSet *dirs = [overrideData objectForKey:@"directories"];
		//NSMutableSet *contents = [overrideData objectForKey:@"contents"];
		
		if (![self loadXML:xmldata ofType:@"OverrideList" error:&loadError])
			return self;
		
		NSXMLElement *root = [xmldoc rootElement];
		
		if ([root childCount] < 1)
		{
			loadError = [self dataStoreError:14 msg:@"No contents in manifest"];
			return self;
		}
		
		if ([root childCount] > 1)
		{
			loadError = [self dataStoreError:15 msg:@"More than one item in manifest"];
			return self;
		}
		
		NSXMLElement *itemNode = (NSXMLElement*)[root childAtIndex:0];
		NSString *uid = [[itemNode attributeForName:@"Name"] stringValue];
		
		if (!uid || ![uid length])
		{
			loadError = [self dataStoreError:16 msg:@"No UID for override"];
			return self;
		}
		
		NSXMLElement *modazipinNode = [self makeModazipinNodeForFiles:files dirs:dirs];
		[itemNode addChild:modazipinNode];
		
		self.identifier = uid;
	}
	return self;
}

- (BOOL)load:(NSError**)error
{
	if (loadError)
	{
		if (error)
			*error = loadError;
		loadError = nil;
		return NO;
	}
	
	if (!xmldoc)
		return YES;
	
	NSMutableSet *set = [NSMutableSet set];
	BOOL res;
	
	createObjBlock createBlock = ^(NSXMLNode *elem, NSString *entityName)
	{
		id cnode = [self makeCacheNode:elem forEntityName:entityName];
		
		[set addObject:cnode];
		return cnode;
	};
	
	setDataBlock setBlock = ^(id obj, NSMutableDictionary *data)
	{
		[obj setPropertyCache:data];
		
		return obj;
	};
	
	res = [self loadOverrideList:[xmldoc rootElement] error:error usingCreateBlock:createBlock usingSetBlock:setBlock];
	
	if (!res)
		return NO;
	
	[self addCacheNodes:set];
	return YES;
}

- (NSString *)type {
	return @"OverrideStore";
}		 
		 
@end

