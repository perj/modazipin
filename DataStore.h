//
//  DataStore.h
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DataStore : NSAtomicStore {

}

@end

@interface AddInsListStore : DataStore
{
}

@end

@interface AddInStore : DataStore
{
}

@end
