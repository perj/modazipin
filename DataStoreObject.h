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

@class Item;
@class Modazipin;

@interface DataStoreObject : NSManagedObject {
}

@property(nonatomic, retain) NSXMLNode *node;

@end


@interface Path : DataStoreObject
{
}

@property (nonatomic, retain) Modazipin * modazipin;
@property (nonatomic, retain) NSString * path;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSNumber * verified;

@end


@interface Modazipin : DataStoreObject
{
}

@property (nonatomic, retain) NSMutableSet* contents;
@property (nonatomic, retain) Item * item;
@property (nonatomic, retain) NSSet* paths;
@property (nonatomic, retain) NSString *origGameVersion;

- (void)addContent:(NSString *)value;
- (void)removeContent:(NSString *)value;

@end

@interface Modazipin (CoreDataGeneratedAccessors)
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
@property (retain) Item * item;

- (void)updateLocalizedValue:(NSNotification*)notice;

@end

@interface Text (CoreDataGeneratedAccessors)
- (void)addLanguagesObject:(LocalizedText *)value;
- (void)removeLanguagesObject:(LocalizedText *)value;
- (void)addLanguages:(NSSet *)value;
- (void)removeLanguages:(NSSet *)value;

@end


@interface Item : DataStoreObject
{
	NSMutableAttributedString *cachedInfo;
	NSMutableString *cachedDetails;
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
@property (nonatomic, retain) NSDecimalNumber * Size;
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
@property (nonatomic, retain) NSNumber *displayed;
@property (nonatomic, retain) NSString *missingFiles;

@property (readonly) NSMutableAttributedString * infoAttributedString;
@property (readonly) NSMutableString * detailsHTML;

- (void)updateInfo;

@end


@interface AddInItem : Item
{
}

@property (nonatomic, retain) NSDecimalNumber * RequiresAuthorization;
@property (nonatomic, retain) NSDecimalNumber * State;

@end


/* Probably could inherit Item here but it complicates validation. */
@interface PRCItem : DataStoreObject
{
}

@property (nonatomic, retain) NSString * microContentID;
@property (nonatomic, retain) NSString * ProductID;
@property (nonatomic, retain) Text * Title;
@property (nonatomic, retain) NSString * Version;


@end


@interface OfferItem : Item
{
}

@property (nonatomic, retain) NSDecimalNumber * Presentation;
@property (nonatomic, retain) NSSet* PRCList;

@end

@interface OfferItem (CoreDataGeneratedAccessors)
- (void)addPRCListObject:(PRCItem *)value;
- (void)removePRCListObject:(PRCItem *)value;
- (void)addPRCList:(NSSet *)value;
- (void)removePRCList:(NSSet *)value;

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

@interface AddInManifest (CoreDataGeneratedAccessors)
- (void)addAddInsListObject:(AddInItem *)value;
- (void)removeAddInsListObject:(AddInItem *)value;
- (void)addAddInsList:(NSSet *)value;
- (void)removeAddInsList:(NSSet *)value;

@end


@interface OfferManifest : Manifest
{
}

@property (nonatomic, retain) NSSet* OfferList;

@end

@interface OfferManifest (CoreDataGeneratedAccessors)
- (void)addOfferListObject:(OfferItem *)value;
- (void)removeOfferListObject:(OfferItem *)value;
- (void)addOfferList:(NSSet *)value;
- (void)removeOfferList:(NSSet *)value;

@end
