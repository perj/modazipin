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
#import "DataStoreObject.h"
#import "GenericStore.h"

typedef id (^createObjBlock)(NSXMLNode *elem, NSString *entityName);
typedef id (^setDataBlock)(id obj, NSMutableDictionary *data);

@interface DataStore : GenericStore
{
	NSString *identifier;
	NSXMLDocument *xmldoc;
	
	NSError *loadError;
}

@property(copy) NSString *identifier;

- (id)makeCacheNode:(NSXMLNode*)elem forEntityName:(NSString*)name;

@end


@interface AddInsListStore : DataStore
{
}

- (AddInItem*)insertAddInNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context;

@end

@interface OfferListStore : DataStore
{
}

- (OfferItem*)insertOfferNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context;

@end

@interface OverrideListStore : DataStore
{
}

- (Item*)insertOverrideNode:(NSXMLElement*)node error:(NSError **)error intoContext:(NSManagedObjectContext*)context;

@end

@interface ArchiveStore : DataStore
{
	int64_t uncompressedSize;
}

- (NSDictionary*)loadArchive:(NSURL *)url error:(NSError**)error;

- (Class)archiveClass;

@property(readonly) int64_t uncompressedSize;

@end


@interface DazipStore : ArchiveStore
{
}

@end


@interface OverrideStore : ArchiveStore
{
}

@end

@interface OverrideConfigStore : DataStore
{
	Item *item;
}

@end
