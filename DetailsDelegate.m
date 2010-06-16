//
//  DetailsDelegate.m
//  modazipin
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

#import "DetailsDelegate.h"
#import "Dazip.h"

@implementation DetailsDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
	if ([[request mainDocumentURL] isFileURL] || [[[request URL] scheme] isEqualToString:@"data"])
		[listener use];
	else if ([[[request URL] scheme] isEqualToString:@"command"])
	{
		NSString *command = [[request URL] resourceSpecifier];
		
		[listener ignore];
		[doc detailsCommand:command];
	}
	else
	{
		[listener ignore];
		[[NSWorkspace sharedWorkspace] openURL:[request mainDocumentURL]];
	}
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	NSMutableArray *res = [NSMutableArray arrayWithCapacity:[defaultMenuItems count]];
	
	for (NSMenuItem *item in defaultMenuItems)
	{
		/* Was planning to white list instead of black list, but eg. Open Link is not documented. */
		switch ([item tag])
		{
			case WebMenuItemTagOpenLinkInNewWindow:
			case WebMenuItemTagDownloadLinkToDisk:
			case WebMenuItemTagOpenImageInNewWindow:
			case WebMenuItemTagDownloadImageToDisk:
			case WebMenuItemTagCopyImageToClipboard:
			case WebMenuItemTagOpenFrameInNewWindow:
			case WebMenuItemTagGoBack:
			case WebMenuItemTagGoForward:
			case WebMenuItemTagStop:
			case WebMenuItemTagReload:
			case WebMenuItemTagCut:
			case WebMenuItemTagPaste:
			case WebMenuItemTagSpellingGuess:
			case WebMenuItemTagNoGuessesFound:
			case WebMenuItemTagIgnoreSpelling:
			case WebMenuItemTagLearnSpelling:
			case WebMenuItemTagOther: /* XXX huh? */
			case WebMenuItemTagOpenWithDefaultApplication:
				break;
				
			default:
				[res addObject:item];
				break;
		}
	}
	return res;
}

- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragDestinationActionNone;
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if ([doc respondsToSelector:@selector(detailsDidLoad)])
		[doc detailsDidLoad];
}


@end
