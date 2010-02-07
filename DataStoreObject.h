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

#import <Cocoa/Cocoa.h>


@interface DataStoreObject : NSManagedObject {
	NSXMLNode *node;
}

@property(retain) NSXMLNode *node;

@end


@interface Content : DataStoreObject
{
}

@property (nonatomic, retain) NSString * name;

@end


@interface Path : DataStoreObject
{
}

@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSString * type;

@end


@interface Modazipin : DataStoreObject
{
}

@property (nonatomic, retain) NSSet* contents;
@property (nonatomic, retain) NSSet* paths;

@end

// coalesce these into one @interface Modazipin (CoreDataGeneratedAccessors) section
@interface Modazipin (CoreDataGeneratedAccessors)
- (void)addContentsObject:(Content *)value;
- (void)removeContentsObject:(Content *)value;
- (void)addContents:(NSSet *)value;
- (void)removeContents:(NSSet *)value;

- (void)addPathsObject:(Path *)value;
- (void)removePathsObject:(Path *)value;
- (void)addPaths:(NSSet *)value;
- (void)removePaths:(NSSet *)value;

@end


@interface LocalizedText : DataStoreObject
{
}

@property (nonatomic, retain) NSString * langcode;
@property (nonatomic, retain) NSString * value;

@end


@interface Text : DataStoreObject
{
}

@property (nonatomic, retain) NSString * DefaultText;
@property (nonatomic, retain) NSSet* languages;
@property (nonatomic, retain) NSString * localizedValue;

@end

// coalesce these into one @interface Text (CoreDataGeneratedAccessors) section
@interface Text (CoreDataGeneratedAccessors)
- (void)addLanguagesObject:(LocalizedText *)value;
- (void)removeLanguagesObject:(LocalizedText *)value;
- (void)addLanguages:(NSSet *)value;
- (void)removeLanguages:(NSSet *)value;

@end


@interface AddInItem : DataStoreObject
{
}

@property (nonatomic, retain) NSDecimalNumber * BioWare;
@property (nonatomic, retain) NSDecimalNumber * Enabled;
@property (nonatomic, retain) NSString * ExtendedModuleUID;
@property (nonatomic, retain) NSDecimalNumber * Format;
@property (nonatomic, retain) NSString * GameVersion;
@property (nonatomic, retain) NSString * Image;
@property (nonatomic, retain) NSString * Name;
@property (nonatomic, retain) NSDecimalNumber * Price;
@property (nonatomic, retain) NSDecimalNumber * Priority;
@property (nonatomic, retain) NSString * ReleaseDate;
@property (nonatomic, retain) NSDecimalNumber * RequiresAuthorization;
@property (nonatomic, retain) NSDecimalNumber * Size;
@property (nonatomic, retain) NSDecimalNumber * State;
@property (nonatomic, retain) NSDecimalNumber * Type;
@property (nonatomic, retain) NSString * UID;
@property (nonatomic, retain) NSString * Version;
@property (nonatomic, retain) Text * Description;
@property (nonatomic, retain) Modazipin * modazipin;
@property (nonatomic, retain) Text * Publisher;
@property (nonatomic, retain) Text * Rating;
@property (nonatomic, retain) Text * RatingDescription;
@property (nonatomic, retain) Text * Title;
@property (nonatomic, retain) Text * URL;

@end


@interface Manifest : DataStoreObject
{
}

@end


@interface AddInManifest : Manifest
{
}

@property (nonatomic, retain) NSSet* AddInsList;

@end

// coalesce these into one @interface AddInManifest (CoreDataGeneratedAccessors) section
@interface AddInManifest (CoreDataGeneratedAccessors)
- (void)addAddInsListObject:(AddInItem *)value;
- (void)removeAddInsListObject:(AddInItem *)value;
- (void)addAddInsList:(NSSet *)value;
- (void)removeAddInsList:(NSSet *)value;

@end
