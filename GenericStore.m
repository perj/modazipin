/* Copyright (c) 2014 Per Johansson, per at morth.org
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

#import "GenericStore.h"

@implementation GenericStore

- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
	/* This function is completely generic, except it requires all stores to be NSAtomicStore */
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
					cnode = [(NSAtomicStore*)[[o objectID] persistentStore] cacheNodeForObjectID:[o objectID]];
					
					if (!cnode)
					{
						cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[o objectID]];
						[(NSAtomicStore*)[[o objectID] persistentStore] addCacheNodes:[NSSet setWithObject:cnode]];
					}
					[set addObject:cnode];
				}
				[data setObject:set forKey:key];
			}
			else
			{
				NSManagedObject *o = value;
				
				cnode = [(NSAtomicStore*)[[o objectID] persistentStore] cacheNodeForObjectID:[o objectID]];
				if (!cnode)
				{
					cnode = [[NSAtomicStoreCacheNode alloc] initWithObjectID:[o objectID]];
					[(NSAtomicStore*)[[o objectID] persistentStore] addCacheNodes:[NSSet setWithObject:cnode]];
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
