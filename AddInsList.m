//
//  MyDocument.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright __MyCompanyName__ 2010 . All rights reserved.
//

#import "AddInsList.h"

@implementation AddInsList

- (id)init 
{
    self = [super init];
    if (self != nil) {
        // initialization code
    }
    return self;
}

- (NSString *)windowNibName 
{
    return @"AddInsList";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

@end
