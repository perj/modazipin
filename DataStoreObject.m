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

#import "DataStoreObject.h"
#import "DataStore.h"
#import "base64.h"
#import "erf.h"

/* XXX layering violation */
#import "AddInsList.h"

@implementation DataStoreObject

@dynamic node;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	DataStore *store = (DataStore*)[[self objectID] persistentStore];
	
	self.node = [[[store cacheNodeForObjectID:[self objectID]] propertyCache] objectForKey:@"node"];
}

@end


@implementation Path

@dynamic contents;
@dynamic modazipin;
@dynamic path;
@dynamic type;
@dynamic verified;

static NSPredicate *isERF;

- (NSMutableDictionary*)dataForContents:(NSArray*)contents
{
	NSMutableDictionary *res = [NSMutableDictionary dictionaryWithCapacity:[contents count]];
	/* XXX layering violation */
	NSURL *url = [[[AddInsList sharedAddInsList] fileURL] URLByAppendingPathComponent:self.path];
	NSDirectoryEnumerator *enumer = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:nil options:0 errorHandler:^(NSURL *u, NSError *error) { return YES; }];
	NSURL *item;
	NSArray *keys = [NSArray arrayWithObjects:NSURLNameKey, NSURLIsRegularFileKey, nil];
	
	if (!isERF)
		isERF = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] '.erf'"];

	while ((item = [enumer nextObject]))
	{
		NSDictionary *props = [item resourceValuesForKeys:keys error:nil];
		
		if (![[props objectForKey:NSURLIsRegularFileKey] boolValue])
			continue;
		
		NSString *name = [props objectForKey:NSURLNameKey];
		
		if ([contents indexOfObject:name] != NSNotFound)
			[res setObject:[NSData dataWithContentsOfURL:item] forKey:name];
		else if ([isERF evaluateWithObject:name])
		{
			NSData *erfdata = [NSData dataWithContentsOfURL:item options:NSDataReadingMapped error:nil];
			
			parse_erf_data([erfdata bytes], [erfdata length], ^(struct erf_header *header, struct erf_file *file)
						   {
							   int len = 0;
							   
							   while (len < ERF_FILENAME_MAXLEN && file->entry->name[len] != 0)
								   len++;
							   
							   NSString *n = [[NSString alloc] initWithBytes:file->entry->name
																	  length:len * 2
																	encoding:NSUTF16LittleEndianStringEncoding];
							   
							   if ([n caseInsensitiveCompare:name] == NSOrderedSame)
								   [res setObject:[NSData dataWithBytes:(void*)file->data length:file->entry->length] forKey:name];
						   });
		}
	}
	return res;
}

@end


@interface Modazipin (CoreDataGeneratedPrimitiveAccessors)

- (NSMutableSet*)primitivePaths;
- (void)setPrimitivePaths:(NSMutableSet*)value;

@end

@implementation Modazipin

@dynamic item;
@dynamic paths;
@dynamic origGameVersion;

- (void)addPathNodes:(NSSet*)paths
{
	if (!self.node)
		return;
	
	NSXMLElement *node = [[(NSXMLElement*)self.node elementsForName:@"paths"] objectAtIndex:0];
	
	if (!node)
	{
		node = [NSXMLElement elementWithName:@"paths"];
		[(NSXMLElement*)self.node addChild:node];
	}
	
	for (Path *p in paths)
	{
		NSXMLElement *pnode = [NSXMLElement elementWithName:p.type];
		
		[pnode addAttribute:[NSXMLNode attributeWithName:@"path" stringValue:p.path]];
		[node addChild:pnode];
		p.node = pnode;
	}
}

- (void)addPathsObject:(Path *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"paths" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitivePaths] addObject:value];
    [self didChangeValueForKey:@"paths" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
	
	[self addPathNodes:changedObjects];
    
    [changedObjects release];
}

- (void)addPaths:(NSSet *)value 
{    
	[self addPathNodes:value];
	
    [self willChangeValueForKey:@"paths" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitivePaths] unionSet:value];
    [self didChangeValueForKey:@"paths" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

@end

@implementation LocalizedText

@dynamic langcode;
@dynamic value;

@end


@implementation Text

@dynamic DefaultText;
@dynamic languages;
@dynamic item;
@dynamic localizedValue;

- (void)updateLocalizedValue:(NSNotification*)notice
{
	/* XXX I should probably use a fetch request, but it is a bit of a bother right now. */
	NSPredicate *equalTmpl = [NSPredicate predicateWithFormat:@"langcode == $code"];
	NSPredicate *beginTmpl = [NSPredicate predicateWithFormat:@"langcode beginswith[c] $code"];
	NSString *value = nil;
	NSSet *available = [self languages];
	
	for (NSString *lang in [NSLocale preferredLanguages])
	{
		NSSet *found = [available filteredSetUsingPredicate:[equalTmpl predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:lang forKey:@"code"]]];
		if ([found count])
		{
			value = [[found anyObject] valueForKey:@"value"];
			break;
		}
		
		found = [available filteredSetUsingPredicate:[beginTmpl predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:lang forKey:@"code"]]];
		if ([found count])
		{
			value = [[found anyObject] valueForKey:@"value"];
			break;
		}
		
		NSRange usc = [lang rangeOfString:@"_"];
		if (usc.location == NSNotFound)
			continue;
		NSString *prefix = [lang substringToIndex:usc.location];
		
		found = [available filteredSetUsingPredicate:[equalTmpl predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:prefix forKey:@"code"]]];
		if ([found count])
		{
			value = [[found anyObject] valueForKey:@"value"];
			break;
		}
		
		found = [available filteredSetUsingPredicate:[beginTmpl predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:prefix forKey:@"code"]]];
		if ([found count])
		{
			value = [[found anyObject] valueForKey:@"value"];
			break;
		}
	}
	
	if (!value)
		value = self.DefaultText;
	
	if (![value isEqualToString:self.localizedValue])
	{
		self.localizedValue = value;
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"languages"])
		[self updateLocalizedValue:nil];
}

- (void)listenForLocalizedValue
{
	[self updateLocalizedValue:nil];
	
	[self addObserver:self forKeyPath:@"languages" options:NSKeyValueChangeSetting | NSKeyValueChangeInsertion | NSKeyValueChangeRemoval | NSKeyValueChangeReplacement context:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLocalizedValue:) name:NSCurrentLocaleDidChangeNotification object:nil];
}

- (void)didTurnIntoFault
{
	[self removeObserver:self forKeyPath:@"languages"];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSCurrentLocaleDidChangeNotification object:nil];
}

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self listenForLocalizedValue];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	[self listenForLocalizedValue];	
}


@end


@implementation Item

@dynamic BioWare;
@dynamic Enabled;
@dynamic ExtendedModuleUID;
@dynamic Format;
@dynamic GameVersion;
@dynamic Image;
@dynamic Name;
@dynamic Price;
@dynamic Priority;
@dynamic ReleaseDate;
@dynamic Size;
@dynamic Type;
@dynamic UID;
@dynamic Version;
@dynamic Description;
@dynamic modazipin;
@dynamic Publisher;
@dynamic Rating;
@dynamic RatingDescription;
@dynamic Title;
@dynamic URL;
@dynamic displayed;
@dynamic missingFiles;

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *res = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"hasConfigSections"])
		res = [res setByAddingObject:@"configSections"];
	
	return res;
}

- (NSMutableString*)replaceProperties:(NSMutableString*)str
{
	NSEntityDescription *textEntity = [NSEntityDescription entityForName:@"Text" inManagedObjectContext:[self managedObjectContext]];
	
	for (NSPropertyDescription *prop in [self entity])
	{
		NSString *repFrom = [NSString stringWithFormat:@"%%%@%%", [prop name]];
		NSString *repTo = nil;
		NSString *secStart = [NSString stringWithFormat:@"%%?%@%%", [prop name]];
		NSString *secEnd = [NSString stringWithFormat:@"%%!%@%%", [prop name]];
		
		if ([[prop class] isSubclassOfClass:[NSRelationshipDescription class]])
		{
			NSRelationshipDescription *rel = (NSRelationshipDescription*)prop;

			if ([rel isToMany])
			{
				NSSet *set = [self valueForKey:[prop name]];
				
				if ([set count])
					repTo = [[NSNumber numberWithInteger:[set count]] stringValue];
				else
					repTo = @"";
			}
			else if ([rel destinationEntity] == textEntity)
			{
				Text *t = [self valueForKey:[prop name]];
				
				if (t)
				{
					[t updateLocalizedValue:nil];
					repTo = [t localizedValue];
				}
				else
					repTo = @"";
			}
			else
			{
				id v = [self valueForKey:[prop name]];
				
				if (v)
					repTo = @"1";
				else
					repTo = @"";
			}
		}
		else if ([[prop class] isSubclassOfClass:[NSFetchedPropertyDescription class]])
		{
			NSArray *arr = [self valueForKey:[prop name]];
			if ([arr count])
			{
				NSString *repPath = [[prop userInfo] objectForKey:@"repPath"];
				
				if (repPath)
					repTo = [[arr objectAtIndex:0] valueForKey:repPath];
				else
					repTo = [[NSNumber numberWithInteger:[arr count]] stringValue];
			}
			else
				repTo = @"";
		}
		else
		{
			NSAttributeDescription *attr = (NSAttributeDescription*)prop;
			
			switch ([attr attributeType])
			{
				case NSStringAttributeType:
					repTo = [self valueForKey:[prop name]];
					if (!repTo)
						repTo = @"";
					break;
				case NSDecimalAttributeType:
				case NSBooleanAttributeType:
					if ([[self valueForKey:[prop name]] boolValue])
						repTo = [[self valueForKey:[prop name]] stringValue];
					else
						repTo = @"";
					break;
				case NSBinaryDataAttributeType:
					{
						NSData *data = [self valueForKey:[prop name]];
						
						repTo = [data base64];
					}
					break;
			}
		}
		
		if (repTo)
		{
			[str replaceOccurrencesOfString:repFrom withString:repTo options:0 range:NSMakeRange(0, [str length])];
			if ([repTo length])
			{
				[str replaceOccurrencesOfString:secStart withString:@"" options:0 range:NSMakeRange(0, [str length])];
				[str replaceOccurrencesOfString:secEnd withString:@"" options:0 range:NSMakeRange(0, [str length])];
			}
			else
			{
				while (1)
				{
					NSRange rs = [str rangeOfString:secStart];
					NSRange re = [str rangeOfString:secEnd];
					
					if (rs.location == NSNotFound || re.location == NSNotFound || re.location < rs.location)
						break;
					
					rs.length = re.location + re.length - rs.location;
					[str deleteCharactersInRange:rs];
				}
			}
		}
	}
	
	NSString *secStart = [NSString stringWithFormat:@"%%?%@%%", [[self entity] name]];
	NSString *secEnd = [NSString stringWithFormat:@"%%!%@%%", [[self entity] name]];
	
	[str replaceOccurrencesOfString:secStart withString:@"" options:0 range:NSMakeRange(0, [str length])];
	[str replaceOccurrencesOfString:secEnd withString:@"" options:0 range:NSMakeRange(0, [str length])];
	
	while (1)
	{
		NSRange rs = [str rangeOfString:@"%?"];
		
		if (rs.location == NSNotFound)
			break;
		
		while ([str characterAtIndex:rs.location + rs.length] != '%')
			rs.length++;
		
		secEnd = [NSString stringWithFormat:@"%%!%@%", [str substringWithRange:NSMakeRange(rs.location + 2, rs.length - 1)]];
		NSRange re = [str rangeOfString:secEnd];
		
		if (re.location == NSNotFound || re.location < rs.location)
			break;
		
		rs.length = re.location + re.length - rs.location;
		[str deleteCharactersInRange:rs];
	}
	
	return str;
}

- (NSMutableAttributedString *)infoAttributedString
{
	if (cachedInfo)
		return cachedInfo;
	
	NSURL *infoURL = [[NSBundle mainBundle] URLForResource:@"ItemInfo" withExtension:@"rtfd"];
	if (!infoURL)
		return nil;
	
	cachedInfo = [[NSMutableAttributedString alloc] initWithURL:infoURL documentAttributes:nil];
	if (!cachedInfo)
		return nil;
	
	[self replaceProperties:[cachedInfo mutableString]];
	return cachedInfo;
}

- (NSMutableString *)detailsHTML
{
	if (cachedDetails)
		return cachedDetails;
	
	NSURL *detailsURL = [[NSBundle mainBundle] URLForResource:@"ItemDetails" withExtension:@"html"];
	if (!detailsURL)
		return nil;
	
	cachedDetails = [NSMutableString stringWithContentsOfURL:detailsURL encoding:NSUTF8StringEncoding error:nil];
	if (!cachedDetails)
		return nil;
	
	return [self replaceProperties:cachedDetails];
}

- (NSMutableString*)galleryHTMLWithContents:(NSDictionary**)outContents;
{
	NSError *err = nil;
	NSFetchRequest *req = [[[self entity] managedObjectModel] fetchRequestFromTemplateWithName:@"contentsOfTypeForItem" substitutionVariables:[NSDictionary dictionaryWithObjectsAndKeys:@".dds", @"type", self, @"item", nil]];
	NSArray *images = [[self managedObjectContext] executeFetchRequest:req error:&err];
	
	NSMutableString *res = [NSMutableString stringWithString:@"<html><body style='color: #b7a266;'>"];
	/*XXX NSMapTable*/NSMutableDictionary *pcmap = [NSMutableDictionary dictionary];
	
	for (NSManagedObject *image in images)
	{
		Path *p = [image valueForKey:@"path"];
		NSString *name = [image valueForKey:@"name"];
		NSMutableArray *a = [pcmap objectForKey:p.path];
		
		if (a)
			[a addObject:name];
		else
			[pcmap setObject:[NSMutableArray arrayWithObjects:p, name, nil] forKey:p.path];
	}
	
	for (NSString *path in [pcmap allKeys])
	{
		NSMutableArray *a = [pcmap objectForKey:path];
		NSMutableDictionary *cm = [NSMutableDictionary dictionary];
		
		Path *p = [a objectAtIndex:0];
		[a removeObjectAtIndex:0];
		
		NSMutableDictionary *imgdata = [p dataForContents:[pcmap objectForKey:p]];
		[imgdata enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)
		 {
			 [cm setObject:obj forKey:key];
			 [res appendFormat:@"<img style='max-width: 340px' src='content:%@'/><br/>", key];
		 }];
		*outContents = [NSDictionary dictionaryWithDictionary:cm];
	}
	[res appendString:@"</body></html>"];
	return res;
}

- (void)didTurnIntoFault
{
	[super didTurnIntoFault];
	cachedInfo = nil;
	cachedDetails = nil;
}

- (void)updateInfo
{
	cachedDetails = nil;
	cachedInfo = nil;
	[self willChangeValueForKey:@"infoAttributedString"];
	[self infoAttributedString];
	[self didChangeValueForKey:@"infoAttributedString"];
#if 0
	/* Slow and unnecessary. */
	[self willChangeValueForKey:@"detailsHTML"];
	[self detailsHTML];
	[self didChangeValueForKey:@"detailsHTML"];
#endif
}

- (void)updateConfigView
{
	if (!configView)
	{
		configView = [[NSView alloc] initWithFrame:(NSRect){{0, 0}, {0, 0}}];
		[self addObserver:self forKeyPath:@"configSections" options:0 context:nil];
	}
	
	NSSet *sections = [self valueForKey:@"configSections"];
	/* Sort reverse to get index 0 at top. */
	NSArray *sortedSections = [[sections allObjects] sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
							   {
								   int idxa = [[a valueForKey:@"index"] intValue];
								   int idxb = [[b valueForKey:@"index"] intValue];
								   
								   if (idxa < idxb)
									   return NSOrderedDescending;
								   if (idxa > idxb)
									   return NSOrderedAscending;
								   return NSOrderedSame;
							   }];
	
	NSPoint loc = {0, 0};
	NSInteger width = 0;
	for (NSView *newSub in [sortedSections valueForKey:@"view"])
	{
		if ([newSub superview] != configView)
			[configView addSubview:newSub];
		
		[newSub setFrameOrigin:loc];
		
		NSRect subFrame = [newSub frame];
		loc.y += subFrame.size.height;
		if (subFrame.size.width > width)
			width = subFrame.size.width;
	}
	[configView setFrame:(NSRect){{0, 0}, {width, 0}}];
	[[configView animator] setFrame:(NSRect){{0, 0}, {width, loc.y}}];
}

- (BOOL)hasConfigSections
{
	return [[self valueForKey:@"configSections"] count] > 0;
}

- (NSView*)configView
{
	if (!configView)
		[self updateConfigView];
	
	return configView;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == self && [keyPath isEqualToString:@"configSections"])
		[self updateConfigView];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end


@implementation AddInItem

@dynamic RequiresAuthorization;
@dynamic State;

@end


@implementation PRCItem

@dynamic microContentID;
@dynamic ProductID;
@dynamic Title;
@dynamic Version;

@end


@implementation OfferItem

@dynamic Presentation;
@dynamic PRCList;

@end


@implementation Manifest

@end


@implementation AddInManifest

@dynamic AddInsList;

@end

@implementation ConfigSection

- (NSArray*)sortedKeys
{
	return [[[self valueForKey:@"keys"] allObjects] sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
	 {
		 int idxa = [[a valueForKey:@"index"] intValue];
		 int idxb = [[b valueForKey:@"index"] intValue];
		 
		 if (idxa < idxb)
			 return NSOrderedDescending;
		 if (idxa > idxb)
			 return NSOrderedAscending;
		 return NSOrderedSame;
	 }];
}

- (NSView*)view
{
	if (!view)
	{
		[NSBundle loadNibNamed:@"ConfigSection" owner:self];
		NSPoint loc = {8, 10};
		NSInteger width = 0;
		
		for (NSView *newSub in [[self sortedKeys] valueForKey:@"view"])
		{
			if ([newSub superview] != box)
				[box addSubview:newSub];
			
			[newSub setFrameOrigin:loc];
			
			NSRect subFrame = [newSub frame];
			loc.y += subFrame.size.height;
			if (subFrame.size.width > width)
				width = subFrame.size.width;
		}
		[view setFrame:(NSRect){{0, 0}, {width + 22, loc.y + 34}}];
	}
	return view;
}

@end


@implementation ConfigKey

- (NSArray*)sortedValues
{
	return [[[self valueForKey:@"values"] allObjects] sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
			{
				int idxa = [[a valueForKey:@"index"] intValue];
				int idxb = [[b valueForKey:@"index"] intValue];
				
				if (idxa < idxb)
					return NSOrderedAscending;
				if (idxa > idxb)
					return NSOrderedDescending;
				return NSOrderedSame;
			}];
}

- (NSAttributedString*)attributedDescription
{
	NSString *desc = [self valueForKey:@"Description"];
	
	if (!desc)
		return nil;
	
	return [[NSAttributedString alloc] initWithString:desc];
}

- (NSView*)view
{
	if (!view)
	{
		[NSBundle loadNibNamed:@"ConfigKey" owner:self];
		NSRect r = [view frame];
		
		r.size.height = 28;
		
		NSString *desc = [self valueForKey:@"Description"];
		if (desc)
		{
			[[descView textContainer] setHeightTracksTextView:NO];
			[descView sizeToFit];
			r.size.height += [descView frame].size.height + 16;
		}
		
		[view setFrameSize:r.size];
	}
	return view;
}

- (IBAction)valueChanged:(id)sender
{
	/* XXX layering violation */
	[[AddInsList sharedAddInsList] saveDocument:self];
}

@end

@implementation ControlKeyScrollView

- (void)scrollWheel:(NSEvent *)theEvent
{
	[[self superview] scrollWheel:theEvent];
}

@end

