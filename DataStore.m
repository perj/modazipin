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
#import "ArchiveWrapper.h"

#include "erf.h"

#include <pcre.h>

@implementation DataStoreObject

@synthesize node;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	DataStore *store = [[[[self managedObjectContext] persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	
	self.node = [[[store cacheNodeForObjectID:[self objectID]] propertyCache] objectForKey:@"node"];
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

- (id)loadModazipin:(NSXMLElement*)node error:(NSError **)error usingBlock:(loadNodeBlock)block
{
	NSXMLElement *pathsNode = nil;
	NSXMLElement *contentsNode = nil;
	NSMutableSet *paths = [NSMutableSet set];
	NSMutableSet *contents = [NSMutableSet set];
	
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
										 nil];
			id pnode = block(data, @"Path");
			
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
										 nil];
			id cnode = block(data, @"Content");
			
			if (!cnode)
				return nil;
			
			[contents addObject:cnode];
		}
	}
	
	NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 paths, @"paths",
								 contents, @"contents",
								 node, @"node",
								 nil];
	return block(data, @"Modazipin");
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
		
		if ([[subnode name] isEqualToString:@"PrereqList"])
		{
			/* Noop, don't know format. */
			continue;
		}
		
		if ([[subnode name] isEqualToString:@"modazipin"])
		{
			id mnode = [self loadModazipin:subnode error:error usingBlock:block];
			
			if (!mnode)
				return NO;
			
			[data setObject:mnode forKey:[subnode name]];
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

- (NSString*)uniqueForNode:(NSXMLNode*)node
{
	NSXMLNode *parent = [node parent];
	NSString *me = [node name];
	
	/* Only AddInItem need a different identifier. */
	if ([me isEqualToString:@"AddInItem"])
		return [[(NSXMLElement *)node attributeForName:@"UID"] stringValue];
	
	if ([node level] == 1 || !parent)
		return me;
	
	return [[self uniqueForNode:parent] stringByAppendingFormat:@"/%@", me];
}

- (id)makeCacheNode:(NSMutableDictionary*)data forEntityName:(NSString*)name
{
	NSEntityDescription *entity = [[[[self persistentStoreCoordinator] managedObjectModel] entitiesByName] objectForKey:name];
	NSManagedObjectID *objid = [self objectIDForEntity:entity referenceObject:[self uniqueForNode:[data objectForKey:@"node"]]];
	NSAtomicStoreCacheNode *cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:objid];
	
	[cnode setPropertyCache:data];
	
	return cnode;
}

- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	NSXMLElement *elem = (NSXMLElement*)obj.node;
	NSXMLNode *attr;
	
	/* Only support updating Enabled for now */
	
	if (![[elem name] isEqualToString:@"AddInItem"])
		return;
	
	attr = [elem attributeForName:@"Enabled"];
	if ([[managedObject valueForKey:@"Enabled"] intValue])
		[attr setStringValue:@"1"];
	else
		[attr setStringValue:@"0"];
	[node setValue:[managedObject valueForKey:@"Enabled"] forKey:@"Enabled"];
}

- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	
	return [self uniqueForNode:obj.node];
}

- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
	NSMutableDictionary *data = [NSMutableDictionary dictionary];
	DataStoreObject *obj = (DataStoreObject*)managedObject;
	NSAtomicStoreCacheNode *cnode = [self cacheNodeForObjectID:[obj objectID]];
	
	if (cnode)
		return cnode; /* Cache node was created through a relationship already. */
	
	for (NSPropertyDescription *prop in [obj entity])
	{
		NSString *key = [prop name];
		id value = [obj valueForKey:key];
		
		if ([[prop class] isSubclassOfClass:[NSRelationshipDescription class]])
		{
			NSRelationshipDescription *rel = (NSRelationshipDescription*)prop;
			
			if ([rel isToMany])
			{
				NSMutableSet *set = [NSMutableSet set];
				
				for (DataStoreObject *o in value)
				{
					cnode = [self cacheNodeForObjectID:[o objectID]];
					
					if (!cnode)
					{
						/* No risk of recursion since we only have one-way relationships. */
						cnode = [self newCacheNodeForManagedObject:o];
						[self addCacheNodes:[NSSet setWithObject:cnode]];
					}
					[set addObject:cnode];
				}
				[data setObject:set forKey:key];
			}
			else
			{
				DataStoreObject *o = value;
				
				cnode = [self cacheNodeForObjectID:[o objectID]];
				if (!cnode)
				{
					/* No risk of recursion since we only have one-way relationships. */
					cnode = [self newCacheNodeForManagedObject:o];
					[self addCacheNodes:[NSSet setWithObject:cnode]];
				}
				[data setObject:cnode forKey:key];
			}
		}
		else
			[data setObject:[value copy] forKey:key];
	}
	[data setObject:obj.node forKey:@"node"];
	
	return [self makeCacheNode:data forEntityName:[[obj entity] name]];
}

- (void)willRemoveCacheNodes:(NSSet *)cacheNodes
{
	for (NSAtomicStoreCacheNode *cnode in cacheNodes)
	{
		NSXMLNode *node = [[cnode propertyCache] objectForKey:@"node"];
		
		[node detach];
	}
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
		
		return (id)obj;
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
		Archive *archive = [Archive archiveForReadingFromURL:url encoding:NSWindowsCP1252StringEncoding error:nil];
		NSData *xmldata = nil;

		NSPredicate *isERF = [NSPredicate predicateWithFormat:@"SELF MATCHES '(?i)^Contents/(Addins/[^/]+|packages)/[^/]+/[^/]+/[^/]+\\.erf$'"];
		//NSPredicate *isDirectory = [NSPredicate predicateWithFormat:@"SELF MATCHES '(?i)^Contents/(Addins/[^/]+|packages)/[^/]+/[^/]+/[^/]+/'"];
		/* NSPredicate does not support extraction, so have to do it manually. */
		const char *errptr;
		int erroff;
		pcre *is_dir_or_file_re = pcre_compile("^Contents/(Addins/[^/]+|packages)/[^/]+/[^/]+/[^/]+/?", PCRE_CASELESS, &errptr, &erroff, NULL);
		int match[3];
		
		if (!is_dir_or_file_re)
		{
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Failed to compile regex: %s @ %d", errptr, erroff] userInfo:nil] raise];
		}
		
		NSMutableSet *files = [NSMutableSet set];
		NSMutableSet *dirs = [NSMutableSet set];
		NSMutableSet *contents = [NSMutableSet set];
		
		for (ArchiveMember *entry in archive)
		{
			NSString *pathstr = [entry pathname];
			const char *path = [entry cPathname];
			
			if ([pathstr caseInsensitiveCompare:@"Manifest.xml"] == NSOrderedSame)
			{
				xmldata = [entry data];
			}
			else if ([isERF evaluateWithObject:pathstr])
			{
				NSData *erfdata = [entry data];
				
				[files addObject:[pathstr substringFromIndex:sizeof("Contents/") - 1]];
				
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
			else if (pcre_exec(is_dir_or_file_re, NULL, path, strlen(path), 0, PCRE_ANCHORED, match, 3) >= 0)
			{
				if (path[match[1] - 1] == '/')
				{
					/* Directory of files */
					NSString *dirstr = [pathstr substringToIndex:match[1] - 1]; /* Strip trailing / */
					
					[dirs addObject:[dirstr substringFromIndex:sizeof("Contents/") - 1]];
					[contents addObject:[pathstr substringFromIndex:match[1]]];
				}
				else
				{
					/* Single file */
					int coff = match[1];
					
					[files addObject:[pathstr substringFromIndex:sizeof("Contents/") - 1]];
					
					while (path[coff] != '/')
						coff--;
					
					[contents addObject:[pathstr substringFromIndex:coff + 1]];
				}
			}
		}
		
		pcre_free(is_dir_or_file_re);
		
		if (!xmldata)
			[[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Could not find Manifest.xml in URL %@", url] userInfo:nil] raise];
		
		[self loadXML:xmldata ofType:@"Manifest"];
		
		NSXMLElement *addinNode = [self verifyManifest];
		
		/* Filter files and dirs to only be those paths outside of the addin main directory. */
		NSPredicate *notInAddin = [NSPredicate predicateWithFormat:@"NOT (SELF BEGINSWITH[c] %@)",
								   [NSString stringWithFormat:@"Addins/%@/",
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
						 usingBlock:^(NSMutableDictionary *data, NSString *entityName)
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