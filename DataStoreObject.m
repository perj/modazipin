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


@implementation DataStoreObject

@dynamic node;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	DataStore *store = (DataStore*)[[self objectID] persistentStore];
	
	self.node = [[[store cacheNodeForObjectID:[self objectID]] propertyCache] objectForKey:@"node"];
}

@end


@implementation Content

@dynamic name;
@dynamic modazipin;

@end



@implementation Path

@dynamic modazipin;
@dynamic path;
@dynamic type;

@end


@implementation Modazipin

@dynamic contents;
@dynamic item;
@dynamic paths;

@end


@implementation LocalizedText

@dynamic langcode;
@dynamic value;

@end


@implementation Text

@dynamic DefaultText;
@dynamic languages;

@synthesize localizedValue;

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
	
	if (![value isEqualToString:localizedValue])
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
					if ([[self valueForKey:[prop name]] boolValue])
						repTo = [[self valueForKey:[prop name]] stringValue];
					else
						repTo = @"";
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
	while (1)
	{
		NSRange rs = [str rangeOfString:@"%?"];
		
		if (rs.location == NSNotFound)
			break;
		
		while ([str characterAtIndex:rs.location + rs.length] != '%')
			rs.length++;
		
		NSString *secEnd = [NSString stringWithFormat:@"%%!%@%", [str substringWithRange:NSMakeRange(rs.location + 2, rs.length - 1)]];
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
	
	NSURL *infoURL = [[NSBundle mainBundle] URLForResource:@"ItemInfo" withExtension:@"rtf"];
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

- (void)didTurnIntoFault
{
	cachedInfo = nil;
	cachedDetails = nil;
}

@end


@implementation AddInItem

@dynamic Enabled;
@dynamic RequiresAuthorization;
@dynamic State;

- (BOOL)canToggleEnabled
{
	return YES;
}

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

- (BOOL)Enabled
{
	return YES;
}

- (BOOL)canToggleEnabled
{
	return NO;
}

@end


@implementation Manifest

@end


@implementation AddInManifest

@dynamic AddInsList;

@end


