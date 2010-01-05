//
//  AddIn.m
//  modazipin
//
//  Created by Pelle Johansson on 2010-01-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AddIn.h"


@implementation AddIn

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
    return @"AddIn";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
    // user interface preparation code
}

@end
