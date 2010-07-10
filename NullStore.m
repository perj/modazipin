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

#import "NullStore.h"
#import "base64.h"

@implementation NullStore

@synthesize identifier;

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options
{
	self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
	
	if (self)
	{
		uuid_t uuid;
		
		uuid_generate(uuid);
		self.identifier = [[NSData dataWithBytes:uuid length:sizeof(uuid)] base64];
		cntr = 0;
	}
	return self;
}

- (NSString *)type {
    return @"NullStore";
}

- (NSDictionary*)metadata {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[self type],
			NSStoreTypeKey,
			[self identifier],
			NSStoreUUIDKey,
			nil];
}

- (BOOL)load:(NSError **)error
{
	return YES;
}

- (BOOL)save:(NSError **)error
{
	return YES;
}

@end

@implementation NullStore (AtomicStoreCallbacks)

- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
	for (NSPropertyDescription *prop in [managedObject entity])
	{
		NSString *key = [prop name];
		id value = [managedObject valueForKey:key];
		
		/* Simplest possible for now. */
		if ([value isKindOfClass:[NSManagedObject self]])
			value = [(NSAtomicStore*)[[value objectID] persistentStore] cacheNodeForObjectID:[value objectID]];
		
		[node setValue:value forKey:key];
	}
}

- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{
	return [NSString stringWithFormat:@"%d", cntr++];
}

- (void)willRemoveCacheNodes:(NSSet *)cacheNodes
{
	/* Noop */
}

@end
