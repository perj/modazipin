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
#import "DAArchive.h"
#import "Scanner.h"
#import "Game.h"

@implementation AddInsList

static AddInsList *sharedAddInsList;

static NSPredicate *isDisabled;
static NSPredicate *isREADME;

+ (AddInsList*)sharedAddInsList
{
	return sharedAddInsList;
}

@synthesize isBusy;
@synthesize statusMessage;
@synthesize randomScreenshotURL;
@synthesize backgroundURL;

- (id)init 
{
	NSAssert(sharedAddInsList == nil, @"Already a shared AddInsList");
	
    self = [super init];
	if (self != nil) {
		if (!operationQueue)
			operationQueue = [[NSOperationQueue alloc] init];
		[[self managedObjectContext] setUndoManager:nil];
		
		detailsTabSelected = 1;
		
		if (!isDisabled)
			isDisabled = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[c] ' (disabled)'"];
		if (!isREADME)
			isREADME = [NSPredicate predicateWithFormat:@"SELF MATCHES '(?i).*README.*'"];
	}
	sharedAddInsList = self;
    return self;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error
{
	NSURL *addinsURL = [absoluteURL URLByAppendingPathComponent:@"Settings/AddIns.xml"];
	NSURL *offersURL = [absoluteURL URLByAppendingPathComponent:@"Settings/Offers.xml"];
	NSURL *overridesURL = [absoluteURL URLByAppendingPathComponent:@"Settings/ModazipinOverrides.xml"];
	NSURL *nullURL = [NSURL URLWithString:@"file:///dev/null"];
	
	if (![self configurePersistentStoreCoordinatorForURL:addinsURL ofType:@"AddInsListStore" 
									  modelConfiguration:@"addins" storeOptions:nil error:error])
	{
		sharedAddInsList = nil;
		return NO;
	}
	if (![self configurePersistentStoreCoordinatorForURL:offersURL ofType:@"OfferListStore" 
									  modelConfiguration:@"offers" storeOptions:nil error:error])
	{
		sharedAddInsList = nil;
		return NO;
	}
	if (![self configurePersistentStoreCoordinatorForURL:overridesURL ofType:@"OverrideListStore" 
									  modelConfiguration:@"overrides" storeOptions:nil error:error])
	{
		sharedAddInsList = nil;
		return NO;
	}
	if (![self configurePersistentStoreCoordinatorForURL:nullURL ofType:@"NullStore" 
									  modelConfiguration:@"null" storeOptions:nil error:error])
	{
		sharedAddInsList = nil;
		return NO;
	}
	
	/* Figure out what offers to show. */
	NSArray *offers = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"allOffers"] error:nil];
	for (OfferItem *offer in offers)
	{
		offer.displayed = [NSNumber numberWithBool:![[offer valueForKey:@"addins"] count]];
	}
	
	[self searchSpotlightForScreenshots:absoluteURL];
	
	return YES;
}

- (NSString *)windowNibName
{
    return @"AddInsList";
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	return fileType;
}

- (void)updateDefaults:(NSString *)key
{
	if ([key isEqualToString:@"backgroundAlpha"])
		[backgroundImage setAlphaValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"backgroundAlpha"]];
	else if ([key isEqualToString:@"useCustomBackground"] || [key isEqualToString:@"customBackgroundURL"])
		[self updateBackgroundURL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [Game sharedGame])
		[launchGameButton setImage:[Game sharedGame].gameAppImage];
	else if (object == itemsController)
		[self itemsControllerChanged];
	else if ([keyPath isEqualToString:@"uncompressedOffset"])
		[self progressChanged:object session:context];
	else if (object == operationQueue)
		[self updateOperationCount];
	else if (object == [NSUserDefaultsController sharedUserDefaultsController])
		[self updateDefaults:[keyPath substringFromIndex:sizeof("values.") - 1]];
	else if (object == self && [keyPath isEqualToString:@"randomScreenshotURL"])
		[self updateBackgroundURL];
}


- (void)windowControllerDidLoadNib:(NSWindowController *)windowController 
{
    [super windowControllerDidLoadNib:windowController];
	
	[detailsView setDrawsBackground:NO];
	
	NSWindow *window = [windowController window];
	[window setRepresentedURL:[self fileURL]];
	[[window standardWindowButton:NSWindowDocumentIconButton] setImage:[NSImage imageNamed:@"dragon_4"]];
	
	[itemsController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"Title.localizedValue" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
	[itemsController rearrangeObjects];
	[itemsController addObserver:self forKeyPath:@"selectedObjects" options:0 context:nil];
	
	[assignAddInController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"Title.localizedValue" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
	
	NSURL *myURL = [self fileURL];
	NSURL *scanAddinsURL = [myURL URLByAppendingPathComponent:@"Addins"];
	NSURL *scanOffersURL = [myURL URLByAppendingPathComponent:@"Offers"];
	NSURL *scanPackagesURL = [myURL URLByAppendingPathComponent:@"packages"];
	NSURL *scanDisabledPackagesURL = [myURL URLByAppendingPathComponent:@"packages (disabled)"];
	
	[operationQueue addObserver:self forKeyPath:@"operationCount" options:0 context:nil];
	[operationQueue addOperation:[[Scanner alloc] initWithDocument:self URL:scanAddinsURL message:@"addins" split:YES]];
	[operationQueue addOperation:[[Scanner alloc] initWithDocument:self URL:scanOffersURL message:@"offers" split:YES]];
	[operationQueue addOperation:[[Scanner alloc] initWithDocument:self URL:scanPackagesURL message:@"packages" split:NO]];
	[operationQueue addOperation:[[Scanner alloc] initWithDocument:self URL:scanDisabledPackagesURL message:@"disabled packages" split:NO]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[backgroundImage setAlphaValue:[defaults floatForKey:@"backgroundAlpha"]];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.backgroundAlpha" options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.useCustomBackground" options:0 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.customBackgroundURL" options:0 context:nil];
	[self addObserver:self forKeyPath:@"randomScreenshotURL" options:0 context:nil];
	
	[launchGameButton setImage:[Game sharedGame].gameAppImage];
	[[Game sharedGame] addObserver:self forKeyPath:@"gameAppImage" options:0 context:nil];
}

@synthesize detailedItem;

- (void)reloadDetails
{
	NSArray *objects = [itemsController selectedObjects];
	
	if ([objects count] == 1)
	{
		[self willChangeValueForKey:@"detailedItem"];
		detailedItem = [objects objectAtIndex:0];
		[self didChangeValueForKey:@"detailedItem"];
		
		NSMutableString *html = [detailedItem detailsHTML];
		
		[html replaceOccurrencesOfString:@"<!--dazip-->" withString:@"<!--" options:0 range:NSMakeRange(0, [html length])];
		[html replaceOccurrencesOfString:@"<!--/dazip-->" withString:@"-->" options:0 range:NSMakeRange(0, [html length])];
		[[detailsView mainFrame] loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];
		
		[optionsContainer setDocumentView:[detailedItem valueForKey:@"configView"]];
	}
	else
	{
		[self willChangeValueForKey:@"detailedItem"];
		detailedItem = nil;
		[self didChangeValueForKey:@"detailedItem"];
		
		[[detailsView mainFrame] loadHTMLString:@"" baseURL:[[NSBundle mainBundle] resourceURL]];
		
		[[optionsContainer contentView] setDocumentView:nil];
	}
	if (detailsTabSelected == 2 && ![detailedItem hasConfigSections])
		[self setDetailsTabSelected:1];
}

- (void)itemsControllerChanged
{
	NSArray *objects = [itemsController selectedObjects];
	
	if ([objects count] == 1)
	{
		Item *item = [objects objectAtIndex:0];
		
		if (item != detailedItem)
			[self reloadDetails];
	}
	else if ([objects count] == 0)
		[self reloadDetails];
}

- (void)reloadItem:(Item*)item
{
	[item updateInfo];
	
	if (item == detailedItem)
		[self reloadDetails];
}

- (void)selectItemWithUid:(NSString *)uid
{
	NSFetchRequest *req = [[self managedObjectModel] fetchRequestFromTemplateWithName:@"itemWithUID" substitutionVariables:[NSDictionary dictionaryWithObject:uid forKey:@"UID"]];
	NSArray *arr = [[self managedObjectContext] executeFetchRequest:req error:nil];
	
	if ([arr count])
	{
		Item *item = [arr objectAtIndex:0];
		
		if (![item.displayed boolValue] && [item class] == [OfferItem self])
			arr = [item valueForKey:@"addins"];
		[itemsController setSelectedObjects:arr];
	}
}

- (void)addContents:(NSString *)contents data:(NSData*)data forURL:(NSURL *)url
{
	NSMutableArray *cparts = [NSMutableArray arrayWithArray:[url pathComponents]];
	NSArray *mparts = [[self fileURL] pathComponents];
	NSFetchRequest *req;
	Item *item = nil;
	
	for (NSString *p in mparts) {
		if (![[cparts objectAtIndex:0] isEqualToString:p])
			return; /* Exception */
		
		[cparts removeObjectAtIndex:0];
	}
	
	if ([[cparts objectAtIndex:0] caseInsensitiveCompare:@"Addins"] == NSOrderedSame
		|| [[cparts objectAtIndex:0] caseInsensitiveCompare:@"Offers"] == NSOrderedSame)
	{
		req = [[self managedObjectModel] fetchRequestFromTemplateWithName:@"itemWithUID" substitutionVariables:[NSDictionary dictionaryWithObject:[cparts objectAtIndex:1] forKey:@"UID"]];
		
		NSArray *items = [[self managedObjectContext] executeFetchRequest:req error:nil];
		if ([items count])
		{
			item = [items objectAtIndex:0];
			
			if (contents)
				[item.modazipin addContent:contents];
		}
		else
		{
			/* An unknown item. */
		}
	}
	else
	{
		NSString *pathType = @"file";
		NSString *readme = nil;
		NSString *origPath = [NSString pathWithComponents:cparts];
		BOOL disabled;
		
		if ((disabled = [isDisabled evaluateWithObject:[cparts objectAtIndex:0]]))
		{
			NSString *s = [cparts objectAtIndex:0];
			
			[cparts replaceObjectAtIndex:0 withObject:[s substringToIndex:[s length] - sizeof (" (disabled)") + 1]];
		}
		
		if ([isREADME evaluateWithObject:origPath])
			readme = [NSString stringWithFormat:@"README:\n\n%@", [NSString stringWithContentsOfURL:[[self fileURL] URLByAppendingPathComponent:origPath] encoding:NSWindowsCP1252StringEncoding error:nil]];
		
		if ([cparts count] > 4)
		{
			[cparts removeObjectsInRange:NSMakeRange(4, [cparts count] - 4)];
			pathType = @"dir";
		}
		
		NSString *path = [NSString pathWithComponents:cparts];
		
		req = [[self managedObjectModel] fetchRequestFromTemplateWithName:@"path" substitutionVariables:[NSDictionary dictionaryWithObject:path forKey:@"path"]];
		NSArray *paths = [[self managedObjectContext] executeFetchRequest:req error:nil];
		
		if ([paths count])
		{
			Path *p = [paths objectAtIndex:0];
			
			p.verified = [NSNumber numberWithBool:YES];
			item = p.modazipin.item;
		}
		else
		{
			/* An unknown path. */
			item = [NSEntityDescription insertNewObjectForEntityForName:@"UnknownPath" inManagedObjectContext:[self managedObjectContext]];
			Text *title = [NSEntityDescription insertNewObjectForEntityForName:@"Text" inManagedObjectContext:[self managedObjectContext]];
			Path *p = [NSEntityDescription insertNewObjectForEntityForName:@"Path" inManagedObjectContext:[self managedObjectContext]];
			
			p.path = path;
			p.type = pathType;
			p.verified = [NSNumber numberWithBool:YES];
			title.DefaultText = [cparts lastObject];
			[title updateLocalizedValue:nil];
			title.item = item;
			item.Title = title;
			item.modazipin = [NSEntityDescription insertNewObjectForEntityForName:@"Modazipin" inManagedObjectContext:[self managedObjectContext]];
			item.Enabled = disabled ? [NSDecimalNumber zero] : [NSDecimalNumber one];
			item.displayed = [NSNumber numberWithBool:YES];
			[item.modazipin addPathsObject:p];
		}
		
		if (contents)
			[item.modazipin addContent:contents];
		
		Text *desc = !item.Description && readme ? [NSEntityDescription insertNewObjectForEntityForName:@"Text" inManagedObjectContext:[self managedObjectContext]] : nil;
		if (desc)
		{
			desc.DefaultText = readme;
			desc.item = item;
			item.Description = desc;
		}
	}
	
	if (item && contents)
	{
		/* Check if this is the image. */
		if (item.Image && [item.Image isEqualToString:[contents stringByDeletingPathExtension]])
		{
			NSImage *img = [[NSImage alloc] initWithData:data];
			[item setValue:[img TIFFRepresentation] forKey:@"imageData"];
			[item updateInfo];
			if ([[itemsController selectedObjects] indexOfObject:item] != NSNotFound)
				[self performSelectorOnMainThread:@selector(itemsControllerChanged) withObject:nil waitUntilDone:NO];
		}
		else if ([contents caseInsensitiveCompare:@"OverrideConfig.xml"] == NSOrderedSame)
		{
			[self configurePersistentStoreCoordinatorForURL:[url fileReferenceURL] ofType:@"OverrideConfigStore" modelConfiguration:@"overrideconfig" storeOptions:[NSDictionary dictionaryWithObject:item forKey:@"item"] error:nil];
			req = [[self managedObjectModel] fetchRequestFromTemplateWithName:@"configSectionsForItem" substitutionVariables:[NSDictionary dictionaryWithObject:item forKey:@"item"]];
			NSArray *sections = [[self managedObjectContext] executeFetchRequest:req error:nil];
			
			[item setValue:[NSSet setWithArray:sections] forKey:@"configSections"];
		}
	}
}

- (void)addContentsForURL:(NSDictionary*)data
{
	[self addContents:[data objectForKey:@"contents"] data:[data objectForKey:@"data"] forURL:[data objectForKey:@"URL"]];
}

- (NSOperationQueue*)queue
{
	return operationQueue;
}

- (void)updateOperationCount
{
	if ([operationQueue operationCount])
	{
		if (!isBusy)
		{
			[self willChangeValueForKey:@"isBusy"];
			isBusy = YES;
			[self didChangeValueForKey:@"isBusy"];
		}
		
		NSArray *msgs = [[operationQueue operations] valueForKey:@"message"];
		/* Remove duplicates. */
		msgs = [[[NSSet setWithArray:msgs] allObjects] sortedArrayUsingSelector:@selector(compare:)];
		NSString *status = [NSString stringWithFormat:@"Scanning %@.", [msgs componentsJoinedByString:@", "]];
		
		if (![status isEqualToString:statusMessage])
		{
			[self willChangeValueForKey:@"statusMessage"];
			statusMessage = status;
			[self didChangeValueForKey:@"statusMessage"];
		}
	}
	else
	{
		if (isBusy)
		{
			[self willChangeValueForKey:@"isBusy"];
			isBusy = NO;
			[self didChangeValueForKey:@"isBusy"];
		}
		if (![statusMessage isEqualToString:@""])
		{
			[self willChangeValueForKey:@"statusMessage"];
			statusMessage = @"";
			[self didChangeValueForKey:@"statusMessage"];
		}
		NSFetchRequest *req = [[self managedObjectModel] fetchRequestTemplateForName:@"itemsWithAnyPath"];
		NSArray *items = [[self managedObjectContext] executeFetchRequest:req error:nil];
		
		NSMutableArray *missing = [NSMutableArray array];
		
		for (Item *item in items)
		{
			[missing removeAllObjects];
			
			for (Path *p in item.modazipin.paths)
			{
				if (![p.verified boolValue])
					[missing addObject:p.path];
			}
			if ([missing count])
			{
				item.missingFiles = [missing componentsJoinedByString:@", "];
				[self performSelectorOnMainThread:@selector(reloadItem:) withObject:item waitUntilDone:NO];
			}
		}
	}
}

- (void)detailsCommand:(NSString*)command
{
	if ([command isEqualToString:@"uninstall"])
	{
		NSArray *selected = [itemsController selectedObjects];
		
		if ([selected count] == 1)
			[self askUninstall:[selected objectAtIndex:0]];
	}
	else if ([command isEqualToString:@"assign"])
	{
		NSArray *selected = [itemsController selectedObjects];
		
		if ([selected count] == 1)
			[self askAssign:[selected objectAtIndex:0]];
	}
}

@end


@implementation AddInsList (Background)

- (void)updateBackgroundURL
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"useCustomBackground"])
		self.backgroundURL = self.randomScreenshotURL;
	else
		self.backgroundURL = [[NSUserDefaults standardUserDefaults] URLForKey:@"customBackgroundURL"];
}

- (IBAction)updateRandomScreenshot:(id)sender
{
	if ([screenshotSpotlightQuery resultCount] > 0)
	{
		NSMetadataItem *item = [screenshotSpotlightQuery resultAtIndex:arc4random() % [screenshotSpotlightQuery resultCount]];
		
		self.randomScreenshotURL = [NSURL fileURLWithPath:[item valueForAttribute:(NSString *)kMDItemPath] isDirectory:NO];
	}
}

- (BOOL)searchSpotlightForScreenshots:(NSURL*)baseURL
{
	NSURL *sURL = [baseURL URLByAppendingPathComponent:@"Screenshots"];
	
	if (screenshotSpotlightQuery)
		return [screenshotSpotlightQuery isGathering];
	
	screenshotSpotlightQuery = [[NSMetadataQuery alloc] init];
	[screenshotSpotlightQuery setPredicate:[NSPredicate predicateWithFormat:@"kMDItemContentTypeTree = 'public.image'"]];
	[screenshotSpotlightQuery setSearchScopes:[NSArray arrayWithObject:sURL]];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateRandomScreenshot:) name:NSMetadataQueryDidFinishGatheringNotification object:screenshotSpotlightQuery];
	
	if (![screenshotSpotlightQuery startQuery])
	{
		screenshotSpotlightQuery = nil;
		return NO;
	}
	return YES;
}

@end


@implementation AddInsList (Installing)

- (BOOL)installItems:(NSArray*)items withArchive:(DAArchive*)archive name:(NSString*)name uncompressedSize:(int64_t)sz error:(NSError**)error
{
	NSURL *base = [self fileURL];
	AddInsListStore *addinsStore = nil;
	OfferListStore *offersStore = nil;
	OverrideListStore *overridesStore = nil;
	
	if (!archive)
		return NO;
	
	/* Could use persistentStoreForURL:, but this works as well. */
	for (id store in [[[self managedObjectContext] persistentStoreCoordinator] persistentStores])
	{
		if ([store class] == [AddInsListStore self])
			addinsStore = store;
		else if ([store class] == [OfferListStore self])
			offersStore = store;
		else if ([store class] == [OverrideListStore self])
			overridesStore = store;
	}
	
	NSMutableArray *mainDirs = [NSMutableArray arrayWithCapacity:[items count]];
	for (NSXMLElement *node in items)
	{
		if ([[node name] isEqualToString:@"AddInItem"])
			[mainDirs addObject:[NSString stringWithFormat:@"Addins/%@", [[node attributeForName:@"UID"] stringValue]]];
		else if ([[node name] isEqualToString:@"OfferItem"])
			[mainDirs addObject:[NSString stringWithFormat:@"Offers/%@", [[node attributeForName:@"UID"] stringValue]]];
	}
	
	[progressIndicator setMaxValue:sz];
	[progressIndicator setDoubleValue:0];
	[progressWindow setTitle:[NSString stringWithFormat:@"Installing %@", name]];
	NSModalSession modal = [NSApp beginModalSessionForWindow:progressWindow];
	
	[archive addObserver:self forKeyPath:@"uncompressedOffset" options:0 context:modal];
	
	for (DAArchiveMember *entry in archive)
	{
		NSString *path;
		
		if (entry.type == dmtManifest)
			continue;
		
		path = entry.installPath;
		
		if ([path rangeOfString:@"Addins/" options:NSCaseInsensitiveSearch | NSAnchoredSearch].length != 0
			|| [path rangeOfString:@"Offers/" options:NSCaseInsensitiveSearch | NSAnchoredSearch].length != 0)
		{
			BOOL matched = NO;
			
			for (NSString *dir in mainDirs)
			{
				if ([path rangeOfString:dir options:NSCaseInsensitiveSearch | NSAnchoredSearch].length != 0)
				{
					matched = YES;
					break;
				}
			}
			if (!matched && [mainDirs count])
			{
				/* Move the item into the first main dir. */
				NSRange r = [path rangeOfString:@"/"];
				
				path = [NSString stringWithFormat:@"%@/%@", [mainDirs objectAtIndex:0], [path substringFromIndex:r.location + 1]];
			}
		}
		
		NSURL *dst = [base URLByAppendingPathComponent:path];
		/* XXX delete all files on error. */
		if (![entry extractToURL:dst createDirectories:YES error:error])
			return NO;
	}
	
	/* XXX delete all files and items on error. */
	for (NSXMLElement *node in items)
	{
		Item *item = nil;
		
		if ([[node name] isEqualToString:@"AddInItem"])
		{
			item = [addinsStore insertAddInNode:node error:error intoContext:[self managedObjectContext]];
			
			if (!item)
				return NO;
			
			[[item valueForKey:@"offers"] setValue:[NSNumber numberWithBool:NO] forKey:@"displayed"];
		}
		else if ([[node name] isEqualToString:@"OfferItem"])
		{
			item = [offersStore insertOfferNode:node error:error intoContext:[self managedObjectContext]];
			
			if (!item)
				return NO;
			
			NSArray *related = [item valueForKey:@"addins"];
			for (AddInItem *rel in related) {
				[[self managedObjectContext] refreshObject:rel mergeChanges:NO];
				if (![rel.Enabled boolValue])
					item.Enabled = [NSDecimalNumber zero];
			}
			item.displayed = [NSNumber numberWithBool:![related count]];
		}
		else if ([[node name] isEqualToString:@"OverrideItem"])
		{
			item = [overridesStore insertOverrideNode:node error:error intoContext:[self managedObjectContext]];
			
			if (!item)
				return NO;
		}
		
		if (item)
			[self enabledChanged:item canInteract:NO];
	}
	
	[NSApp endModalSession:modal];
	[progressWindow close];
	
	return YES;
}

- (void)progressChanged:(ArchiveWrapper*)archive session:(NSModalSession)modal
{
	[progressIndicator setDoubleValue:archive.uncompressedOffset];
	[progressIndicator displayIfNeeded];
	[NSApp runModalSession:modal];
}

@end

@implementation AddInsList (Editing)

- (void)askAssign:(Item*)item
{
	[NSApp beginSheet:assignSheet modalForWindow:[self windowForSheet] modalDelegate:self didEndSelector:@selector(verifyAssign:returnCode:contextInfo:) contextInfo:item];
}

- (IBAction)closeAssign:(id)sender
{
	[NSApp endSheet:assignSheet returnCode:[sender tag]];
}

- (void)verifyAssign:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet close];
	
	if (returnCode)
	{
		NSArray *selection = [assignAddInController selectedObjects];
		
		if ([selection count] == 1)
		{
			AddInItem *addin = [selection objectAtIndex:0];
			Item *item = contextInfo;
			
			NSBeginCriticalAlertSheet(@"Assign item",
					  @"Assign",
					  @"Cancel",
					  nil,
					  [self windowForSheet],
					  self,
					  @selector(answerAssign:returnCode:contextInfo:),
					  NULL,
					  [NSArray arrayWithObjects:item, addin, nil],
					  @"Permanently assign the item \"%@\" to the addin \"%@\"? This action can not be undone.",
					  item.Title.localizedValue,
					  addin.Title.localizedValue);
			return;
		}
	}
}
	
- (void)answerAssign:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSArray *args = contextInfo;
	
	[sheet close];
	
	if (returnCode != NSOKButton)
		return;
	
	[self assignPath:[args objectAtIndex:0] toAddIn:[args objectAtIndex:1]];
}

- (void)assignPath:(Item*)unkPath toAddIn:(AddInItem*)addin
{
	NSSet *paths = unkPath.modazipin.paths;
	
	[addin.modazipin addPaths:paths];
	[[self managedObjectContext] deleteObject:unkPath];
	[itemsController setSelectedObjects:[NSArray arrayWithObject:addin]];
	[self saveDocument:self];
}

- (IBAction)toggleEnabled:(id)sender
{
	[self enabledChanged:[[itemsController arrangedObjects] objectAtIndex:[sender clickedRow]] canInteract:YES];
}

- (void)enabledChanged:(Item *)item canInteract:(BOOL)canInteract
{
	if ([item.Enabled boolValue])
	{
		NSString *gameVersion = [[Game sharedGame] gameVersion];
		NSString *reqGameVersion = item.GameVersion;
		
		if (gameVersion && reqGameVersion && [reqGameVersion caseInsensitiveCompare:gameVersion] == NSOrderedDescending)
		{
			if (canInteract)
				[self performSelectorOnMainThread:@selector(askOverrideGameVersion:) withObject:item waitUntilDone:NO];
			else
			{
				item.Enabled = [NSDecimalNumber zero];
				[self enabledChanged:item canInteract:NO];
			}
		}
	}
	else
	{
		NSString *origGameVersion = item.modazipin.origGameVersion;
		
		if (origGameVersion && ![origGameVersion isEqualToString:@""] && ![origGameVersion isEqualToString:item.GameVersion])
		{
			item.GameVersion = origGameVersion;
			if ([item class] == [AddInItem self])
				[[item valueForKey:@"offers"] setValue:origGameVersion forKey:@"GameVersion"];
		}
	}
	
	if ([item class] == [AddInItem self])
		[[item valueForKey:@"offers"] setValue:item.Enabled forKey:@"Enabled"];
	
	[self saveDocument:self];
}

- (void)askOverrideGameVersion:(Item*)item
{
	NSBeginAlertSheet(@"Override required game version", @"Override", @"Cancel", nil, [self windowForSheet], self, @selector(answerOverrideGameVersion:returnCode:contextInfo:), nil, item, @"\"%@\" requires game version %@, but you have %@. Override the required game version check?", item.Title.localizedValue, item.GameVersion, [[Game sharedGame] gameVersion]);
}

- (void)answerOverrideGameVersion:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	Item *item = contextInfo;
	
	if (returnCode == NSOKButton)
	{
		if (!item.modazipin)
		{
			Modazipin *modazipin = [NSEntityDescription insertNewObjectForEntityForName:@"Modazipin" inManagedObjectContext:[self managedObjectContext]];
			
			modazipin.item = item;
		}
		
		item.modazipin.origGameVersion = item.GameVersion;
		item.GameVersion = @"";
		
		if ([item class] == [AddInItem self])
			[[item valueForKey:@"offers"] setValue:@"" forKey:@"GameVersion"];
		
		[self saveDocument:self];
	}
	else
	{
		item.Enabled = [NSDecimalNumber zero];
		
		[self enabledChanged:item canInteract:NO];
	}
}

- (int)detailsTabSelected
{
	return detailsTabSelected;
}

- (void)setDetailsTabSelected:(int)value
{
	detailsTabSelected = value;
	[detailsView setHidden:detailsTabSelected != 1];
	[optionsContainer setHidden:detailsTabSelected != 2];
}

@end


@implementation AddInsList (Saving)

- (BOOL)syncFilesFromContext:(NSError **)error
{
	NSURL *base = [self fileURL];	
	NSArray *items = [[self managedObjectContext] executeFetchRequest:[[self managedObjectModel] fetchRequestTemplateForName:@"itemsWithAnyPath"] error:error];
	
	if (!items)
		return NO;
	
	for (Item *item in items)
	{
		NSSet *paths = item.modazipin.paths;
		BOOL isEnabled = [item.Enabled boolValue];
		
		for (Path *path in paths)
		{
			NSString *enabledPath = path.path;
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
				(void)0; /* XXX do something here. */
		}
	}
	return YES;
}

- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	BOOL res = [[self managedObjectContext] save:outError];
	
	if (!res)
		return NO;
	
	return [self syncFilesFromContext:outError];
}

@end


@implementation AddInsList (Uninstalling)

- (IBAction)askUninstall:(id)item
{
	NSString *title;
	NSString *msg;
	
	if (![item isKindOfClass:[Item class]])
		item = [[itemsController selectedObjects] objectAtIndex:0];
	
	if ([[[item entity] name] isEqualToString:@"AddInItem"] && [[item valueForKey:@"offers"] count])
	{
		title = @"Uninstall addin and offer";
		msg = @"This will completely delete the addin \"%@\" and the associated offer. You will not be able to reinstall without the original files.";
	}
	else
	{
		title = @"Uninstall addin";
		msg = @"This will completely delete the addin \"%@\". You will not be able to reinstall it without the original file.";
	}

	NSBeginAlertSheet(title,
					  @"Delete",
					  @"Cancel",
					  nil,
					  [self windowForSheet],
					  self,
					  @selector(answerUninstall:returnCode:contextInfo:),
					  NULL,
					  item,
					  msg,
					  ((Item*)item).Title.localizedValue);
}
								  
- (void)answerUninstall:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode != NSOKButton)
		return;
	
	[self uninstall:contextInfo error:NULL];
}

- (BOOL)uninstall:(Item*)item error:(NSError **)error
{
	NSSet *paths = item.modazipin.paths;
	NSURL *base = [self fileURL];
	
	if ([item class] == [AddInItem self])
	{
		for (Item *offer in [item valueForKey:@"offers"])
		{
			if (![self uninstall:offer error:error])
				return NO; /* XXX inconsitent state. */
		}
	}
	
	for (Path *path in paths)
	{
		NSString *enabledPath = path.path;
		NSRange slash = [enabledPath rangeOfString:@"/"];
		NSString *disabledPath = [enabledPath stringByReplacingCharactersInRange:slash withString:@" (disabled)/"];
		BOOL res;
		NSError *err = nil;
		
		res = [[NSFileManager defaultManager] removeItemAtURL:[base URLByAppendingPathComponent:enabledPath] error:&err];
		if (!res)
			res = [[NSFileManager defaultManager] removeItemAtURL:[base URLByAppendingPathComponent:disabledPath] error:&err];
		
		if (!res)
			[self presentError:err];
	}
	
	NSString *dir = nil;
	if ([item class] == [AddInItem self])
		dir = @"Addins";
	else if ([item class] == [OfferItem self])
		dir = @"Offers";
	
	if (dir)
	{
		NSURL *itemURL = [[base URLByAppendingPathComponent:dir] URLByAppendingPathComponent:item.UID];
		NSError *err = nil;
		BOOL res = [[NSFileManager defaultManager] removeItemAtURL:itemURL error:&err];
		if (!res)
			[self presentError:err];
	}

	[[self managedObjectContext] deleteObject:item];
	[self saveDocument:self];
	return YES;
}

@end
