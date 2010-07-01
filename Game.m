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

#import "Game.h"


@implementation Game

static Game *sharedGame = nil;

+ (Game*)sharedGame
{
	if (sharedGame)
		return sharedGame;
	
	return [[self alloc] init];
}

- (id)init
{
	if (sharedGame)
	{
		[self dealloc];
		return sharedGame;
	}
	
	self = [super init];
	if (self)
	{
		self.gameAppImage = [NSImage imageNamed:@"dragon_4"];
		[self updateLaunchButtonImage];
	}
	
	return self;
}

@synthesize gameAppImage;
@synthesize spotlightGameItem;

- (void)updateLaunchButtonImage
{
	NSURL *url = [self gameURL];
	
	if (!url)
	{
		[self searchSpotlightForGame];
		return;
	}
	
	NSBundle *gameBundle = [NSBundle bundleWithURL:url];
	NSDictionary *gameInfo = [gameBundle infoDictionary];
	NSString *imageName = [gameInfo objectForKey:@"CFBundleIconFile"];
	NSURL *imageURL = [gameBundle URLForImageResource:imageName];
	NSImage *img = [[NSImage alloc] initByReferencingURL:imageURL];
	
	if (img)
		self.gameAppImage = img;
}

- (BOOL)searchSpotlightForGame
{
	NSAssert(spotlightGameItem == nil, @"Already have spotlightGameItem!");
	
	if (gameSpotlightQuery)
		return [gameSpotlightQuery isGathering];
	
	gameSpotlightQuery = [[NSMetadataQuery alloc] init];
	[gameSpotlightQuery setPredicate:[NSPredicate predicateWithFormat:@"kMDItemContentType == 'com.apple.application-bundle' AND (kMDItemCFBundleIdentifier == 'com.transgaming.cider.dragonageorigins' OR kMDItemFSName == 'DragonAgeOrigins.app')"]];
	[gameSpotlightQuery setSearchScopes:[NSArray arrayWithObject:NSMetadataQueryLocalComputerScope]];
	
	[gameSpotlightQuery addObserver:self forKeyPath:@"results" options:0 context:nil];
	
	if (![gameSpotlightQuery startQuery])
	{
		gameSpotlightQuery = nil;
		return NO;
	}
	return YES;
}

- (void)gameSpotlightQueryChanged
{
	[gameSpotlightQuery disableUpdates];
	
	if ([gameSpotlightQuery resultCount] > 0)
	{
		self.spotlightGameItem = [gameSpotlightQuery resultAtIndex:0];
		[self updateLaunchButtonImage];
	}
	
	[gameSpotlightQuery enableUpdates];
	return;
}

- (NSURL*)gameURL
{
	NSURL *url;
	NSArray *maybeRunning = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.transgaming.cider.dragonageorigins"];
	NSRunningApplication *running = nil;
	NSString *path;
	
	if ([maybeRunning count])
	{
		running = [maybeRunning objectAtIndex:0];
		return [running bundleURL];
	}
	
	if ((url = [[NSUserDefaults standardUserDefaults] URLForKey:@"game url"]))
	{
		if ([url checkResourceIsReachableAndReturnError:nil])
			return url;
	}
	
	if ((url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.transgaming.cider.dragonageorigins"]))
		return url;
	
	for (running in [[NSWorkspace sharedWorkspace] runningApplications])
	{
		url = [running bundleURL];
		if ([[url lastPathComponent] isEqualToString:@"DragonAgeOrigins.app"])
			return url;
	}
	
	if ((path = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"DragonAgeOrigins.app"]))
		return [NSURL fileURLWithPath:path];
	
	if (spotlightGameItem)
		return [NSURL fileURLWithPath:[spotlightGameItem valueForAttribute:@"kMDItemPath"]];
	
	/* Phew, exhausted */
	return nil;
}

- (IBAction)launchGame:(id)sender
{
	NSURL *url;
	
	if ((url = [self gameURL]))
	{
		NSError *err;
		NSRunningApplication *running;
		
		running = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:nil error:&err];
		
		if (running)
		{
			[[NSUserDefaults standardUserDefaults] setURL:[running bundleURL] forKey:@"game url"];
			if ([[NSUserDefaults standardUserDefaults] boolForKey:@"quitOnGameLaunch"])
				[NSApp terminate:self];
			return;
		}
	}
	
	/* -gameURL works very hard to find the URL, so assume it is not there if it fails. */
}

- (NSString*)gameVersion;
{
	NSURL *url = [self gameURL];
	
	if (!url)
	{
		[self searchSpotlightForGame];
		return nil;
	}
	
	NSBundle *gameBundle = [NSBundle bundleWithURL:url];
	NSDictionary *gameInfo = [gameBundle infoDictionary];
	return [gameInfo objectForKey:@"CFBundleShortVersionString"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == gameSpotlightQuery)
		[self gameSpotlightQueryChanged];
}

@end
