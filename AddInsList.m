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

#import "AddInsList.h"
#import "DataStore.h"
#import "ArchiveWrapper.h"

@implementation AddInsList

static AddInsList *sharedAddInsList;

+ (AddInsList*)sharedAddInsList
{
	return sharedAddInsList;
}

- (id)init 
{
	NSAssert(sharedAddInsList == nil, @"Already a shared AddInsList");
	
    self = [super init];
    if (self != nil) {
        // initialization code
    }
	sharedAddInsList = self;
    return self;
}

- (NSString *)windowNibName 
{
    return @"AddInsList";
}

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
		[launchGameButton setImage:img];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
	
	NSWindow *window = [windowController window];
	[window setRepresentedURL:[self fileURL]];
	[[window standardWindowButton:NSWindowDocumentIconButton] setImage:[NSImage imageNamed:@"dragon_4"]];
	
	[itemsController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"Title.DefaultText" ascending:YES]]];
	[itemsController rearrangeObjects];
	
	[launchGameButton setKeyEquivalent:@"\r"];
	[self updateLaunchButtonImage];
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	return @"AddInsListStore";
}

- (NSURL *)baseDirectory
{
	NSURL *settings = [[self fileURL] URLByDeletingLastPathComponent];
	
	if ([[settings lastPathComponent] caseInsensitiveCompare:@"Settings"] != NSOrderedSame)
		return nil;
	
	return [settings URLByDeletingLastPathComponent];
}

- (BOOL)installAddInItem:(NSXMLElement *)node withArchive:(NSURL*)url error:(NSError**)error
{
	AddInsListStore *store = [[[[self managedObjectContext] persistentStoreCoordinator] persistentStores] objectAtIndex:0];
	Archive *archive = [Archive archiveForReadingFromURL:url encoding:NSWindowsCP1252StringEncoding error:error];
	NSURL *base = [self baseDirectory];
	
	if (!archive)
		return NO;
	
	for (ArchiveMember *entry in archive)
	{
		if ([[entry pathname] hasSuffix:@"/"])
			continue;
		
		/* XXX filter entries */
		NSEnumerator *path = [[[entry pathname] pathComponents] objectEnumerator];
		
		if ([[path nextObject] caseInsensitiveCompare:@"Contents"] == NSOrderedSame)
		{
			NSURL *dst = base;
			NSString *part;
			
			while ((part = [path nextObject]))
			{
				if ([part isEqualToString:@".."] || [part isEqualToString:@"."])
					continue;
				dst = [dst URLByAppendingPathComponent:part];
			}
			
			/* XXX delete all files on error. */
			if (![entry extractToURL:dst createDirectories:YES error:error])
				return NO;
		}
	}
	
	/* XXX delete all files on error. */
	return [store insertAddInNode:node error:error intoContext:[self managedObjectContext]];
}

- (BOOL)syncFilesFromContext:(NSError **)error
{
	NSURL *base = [self baseDirectory];	
	NSArray *addins = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"addinsWithPaths"] error:error];
	
	if (!addins)
		return NO;
	
	for (DataStoreObject *addin in addins)
	{
		NSSet *paths = [[addin valueForKey:@"modazipin"] valueForKey:@"paths"];
		BOOL isEnabled = [[addin valueForKey:@"Enabled"] boolValue];
		
		for (DataStoreObject *path in paths)
		{
			NSString *enabledPath = [path valueForKey:@"path"];
			NSRange slash = [enabledPath rangeOfString:@"/"];
			NSString *disabledPath = [enabledPath stringByReplacingCharactersInRange:slash withString:@" (disabled)/"];
			NSURL *expectedURL = [base URLByAppendingPathComponent:isEnabled ? enabledPath : disabledPath];
			NSURL *otherURL = [base URLByAppendingPathComponent:isEnabled ? disabledPath : enabledPath];
			
			if ([expectedURL checkResourceIsReachableAndReturnError:nil])
				continue;
			
			if (![otherURL checkResourceIsReachableAndReturnError:nil])
				continue; /* XXX more error handling */
			
			NSURL *dirURL = [expectedURL URLByDeletingLastPathComponent];
			
			[[NSFileManager defaultManager] createDirectoryAtPath:[dirURL path] withIntermediateDirectories:YES attributes:nil error:nil];
			if (![[NSFileManager defaultManager] moveItemAtURL:otherURL toURL:expectedURL error:error])
				NULL; /* XXX do something here. */
		}
	}
	return YES;
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error
{
	BOOL res = [super writeToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation originalContentsURL:absoluteOriginalContentsURL error:error];
	
	if (!res)
		return NO;
	
	return [self syncFilesFromContext:error];
}

- (IBAction)askUninstall:(DataStoreObject*)addin
{
	NSBeginAlertSheet(@"Uninstall addin",
					  @"Delete",
					  @"Cancel",
					  nil,
					  [self windowForSheet],
					  self,
					  @selector(answerUninstall:returnCode:contextInfo:),
					  NULL,
					  addin,
					  @"This will completely delete the addin \"%@\". You will not be able to reinstall it without the original file.",
					  [[addin valueForKey:@"Title"] valueForKey:@"DefaultText"]);	
}
								  
- (void)answerUninstall:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode != NSOKButton)
		return;
	
	[self uninstall:contextInfo error:NULL];
}

- (BOOL)uninstall:(DataStoreObject*)addin error:(NSError **)error
{
	NSSet *paths = [[addin valueForKey:@"modazipin"] valueForKey:@"paths"];
	NSURL *base = [self baseDirectory];
	
	for (DataStoreObject *path in paths)
	{
		NSString *enabledPath = [path valueForKey:@"path"];
		NSRange slash = [enabledPath rangeOfString:@"/"];
		NSString *disabledPath = [enabledPath stringByReplacingCharactersInRange:slash withString:@" (disabled)/"];
		BOOL res;
		NSError *err = nil;
		
		res = [[NSFileManager defaultManager] removeItemAtURL:[base URLByAppendingPathComponent:enabledPath] error:&err];
		if (!res)
			res =[[NSFileManager defaultManager] removeItemAtURL:[base URLByAppendingPathComponent:disabledPath] error:&err];
		
		if (!res)
			[self presentError:err];
	}
	
	NSURL *addinURL = [[base URLByAppendingPathComponent:@"Addins"] URLByAppendingPathComponent:[addin valueForKey:@"UID"]];
	NSError *err = nil;
	BOOL res = [[NSFileManager defaultManager] removeItemAtURL:addinURL error:&err];
	if (!res)
		[self presentError:err];

	[[self managedObjectContext] deleteObject:addin];
	[self saveDocument:self];
	return YES;
}

@synthesize spotlightGameItem;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	
	if (object == spotlightQuery)
	{
		[spotlightQuery disableUpdates];
		
		if ([spotlightQuery resultCount] > 0)
		{
			self.spotlightGameItem = [spotlightQuery resultAtIndex:0];
			[self updateLaunchButtonImage];
		}
		
		[spotlightQuery enableUpdates];
		return;
	}
}

- (BOOL)searchSpotlightForGame
{
	NSAssert(spotlightGameItem == nil, @"Already have spotlightGameItem!");
	
	if (spotlightQuery)
		return [spotlightQuery isGathering];
	
	spotlightQuery = [[NSMetadataQuery alloc] init];
	[spotlightQuery setPredicate:[NSPredicate predicateWithFormat:@"kMDItemContentType == 'com.apple.application-bundle' AND (kMDItemCFBundleIdentifier == 'com.transgaming.cider.dragonageorigins' OR kMDItemFSName == 'DragonAgeOrigins.app')"]];
	[spotlightQuery setSearchScopes:[NSArray arrayWithObject:NSMetadataQueryLocalComputerScope]];
	
	[spotlightQuery addObserver:self forKeyPath:@"results" options:0 context:nil];
	
	if (![spotlightQuery startQuery])
	{
		spotlightQuery = nil;
		return NO;
	}
	return YES;
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
			return;
		}
	}
	
	/* -gameURL works very hard to find the URL, so assume it is not there if it fails. */
}

@end
