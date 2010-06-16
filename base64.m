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

#import "base64.h"

@implementation NSData (base64)

static const char base64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

- (NSMutableString *)base64
{
	const unsigned char *data = [self bytes];
	NSUInteger len = [self length];
	NSUInteger i;
	NSMutableString *res = [NSMutableString stringWithCapacity:(len + 2) / 3 * 4];

	for (i = 0 ; i < len - 2 ; i += 3)
		[res appendFormat:@"%c%c%c%c",
			base64[data[i] >> 2],
			base64[(data[i] & 0x3) << 4 | data[i + 1] >> 4],
			base64[(data[i + 1] & 0xF) << 2 | data[i + 2] >> 6],
			base64[data[i + 2] & 0x3F]];

	switch (len - i)
	{
	case 2:
		[res appendFormat:@"%c%c%c=",
			base64[data[i] >> 2],
			base64[(data[i] & 0x3) << 4 | data[i + 1] >> 4],
			base64[(data[i + 1] & 0xF) << 2]];
		break;
	case 1:
		[res appendFormat:@"%c%c==",
			base64[data[i] >> 2],
			base64[(data[i] & 0x3) << 4]];
		break;
	}

	return res;
}

@end

@implementation NSString (base64)

static const char debase64[] =
	"\76" /* + */
	"\0\0\0"
	"\77\64\65\66\67\70\71\72\73\74\75" /* /, 0 - 9 */
	"\0\0\0"
	"\0" /* = */
	"\0\0\0"
	"\0\1\2\3\4\5\6\7\10\11\12\13\14\15\16\17\20\21\22\23\24\25\26\27\30\31" /* A - Z */
	"\0\0\0\0\0\0"
	"\32\33\34\35\36\37\40\41\42\43\44\45\46\47\50\51\52\53\54\55\56\57\60\61\62\63"; /* a - z */

- (NSMutableData*)debase64
{
	NSUInteger len = [self length];
	NSUInteger i;
	NSMutableData *res = [NSMutableData dataWithCapacity:len / 4 * 3];
	char overflow;
	int state = 0;

	for (i = 0 ; i < len ; i++)
	{
		unichar ch = [self characterAtIndex:i];
		unsigned char b;
		char data;

		if (ch < '+' || ch > 'z')
			continue;

		b = debase64[ch - '+'];
		if (!b && ch != 'A')
			continue;

		switch (state++)
		{
		case 0:
			overflow = b << 2;
			continue;
		case 1:
			data = overflow | b >> 4;
			overflow = b << 4;
			break;
		case 2:
			data = overflow | b >> 2;
			overflow = b << 6;
			break;
		case 3:
			data = overflow | b;
			state = 0;
			break;
		}
		[res appendBytes:&data length:1];
	}

	if (state)
		[res appendBytes:&overflow length:1];

	return res;
}

@end
