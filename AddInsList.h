//
//  MyDocument.h
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright __MyCompanyName__ 2010 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AddInsList : NSPersistentDocument {
}

+ (AddInsList*)sharedAddInsList;

- (BOOL)installAddInItem:(NSXMLElement *)node error:(NSError**)error;

@end
