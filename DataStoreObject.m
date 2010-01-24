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

@synthesize node;

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	DataStore *store = [[[[self managedObjectContext] persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	
	self.node = [[[store cacheNodeForObjectID:[self objectID]] propertyCache] objectForKey:@"node"];
}

@end


@implementation Content

@dynamic name;

@end



@implementation Path

@dynamic path;
@dynamic type;

@end


@implementation Modazipin

@dynamic contents;
@dynamic paths;

@end


@implementation LocalizedText

@dynamic langcode;
@dynamic value;

@end


@implementation Text

@dynamic DefaultText;
@dynamic languages;

@end


@implementation AddInItem

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
@dynamic RequiresAuthorization;
@dynamic Size;
@dynamic State;
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

@end


@implementation Manifest

@end


@implementation AddInManifest

@dynamic AddInsList;

@end

