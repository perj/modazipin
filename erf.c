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

#include "erf.h"

#include <stdlib.h>
#include <errno.h>
#include <string.h>

/* ptr < data is paranoia */
#define CHECKLEN(x) if (ptr < (const char*)data || ptr - (const char *)data + sizeof (x) > length) return -1

const char erf_v2_0[16] = { 'E', 0, 'R', 0, 'F', 0, ' ', 0, 'V', 0, '2', 0, '.', 0, '0', 0 };
const char erf_v2_2[16] = { 'E', 0, 'R', 0, 'F', 0, ' ', 0, 'V', 0, '2', 0, '.', 0, '2', 0 };
const char erf_v3_0[16] = { 'E', 0, 'R', 0, 'F', 0, ' ', 0, 'V', 0, '3', 0, '.', 0, '0', 0 };

int
parse_erf_data(const void *data, size_t length, erf_entry_block block)
{
	const char *ptr = (const char*)data;
	struct erf_header header = {NULL};
	struct erf_file file = {NULL};
	int i, n;
	int perrno = errno;
	char name[ERF_FILENAME_MAXLEN + 1];
	int len;
	
	errno = EINVAL;
	
	if (length < 16)
		return -1;
	
	if (memcmp(data, erf_v2_0, 16) == 0)
	{
		CHECKLEN (*header.entry_2);
		
		header.entry_2 = (const struct erf_header_entry_2 *)ptr;
		ptr += sizeof (*header.entry_2);
		
		n = le32toh (header.entry_2->num_entries);
	}
	else if (memcmp(data, erf_v2_2, 16) == 0)
	{
		CHECKLEN (*header.entry_2);
		
		header.entry_2 = (const struct erf_header_entry_2 *)ptr;
		ptr += sizeof (*header.entry_2);
		
		n = le32toh (header.entry_2->num_entries);
		
		CHECKLEN (*header.ext_2_2);
		header.ext_2_2 = (const struct erf_header_ext_2_2*)ptr;
		ptr += sizeof (*header.ext_2_2);
	}
	else if (memcmp(data, erf_v3_0, 16) == 0)
	{
		CHECKLEN (*header.entry_3);
		
		header.entry_3 = (const struct erf_header_entry_3 *)ptr;
		ptr += sizeof (*header.entry_3);
		
		n = le32toh (header.entry_3->num_entries);
	}
	else
		return -1;

	for (i = 0 ; i < n ; i++)
	{
		if (header.entry_3)
		{
			CHECKLEN (*file.entry_3);
			file.entry_3 = (const struct erf_file_entry_3*)ptr;
			ptr += sizeof (*file.entry_3);
			
			file.data = (const char*)data + le32toh (file.entry_3->offset);
			file.length = le32toh(file.entry_3->length);
			file.name = file.entry_3->name_offset != -1 ? header.names + le32toh(file.entry_3->name_offset) : NULL;
		}
		else
		{
			CHECKLEN (*file.entry_2);
			file.entry_2 = (const struct erf_file_entry_2*)ptr;
			ptr += sizeof (*file.entry_2);
		
			if (header.ext_2_2)
			{
				CHECKLEN (*file.ext_2_2);
				file.ext_2_2 = (const struct erf_file_ext_2_2*)ptr;
				ptr += sizeof (*file.ext_2_2);
			}
			file.data = (const char*)data + le32toh (file.entry_2->offset);
			file.length = le32toh(file.entry_2->length);
			file.name = name;
			
			for (len = 0 ; len < ERF_FILENAME_MAXLEN && file.entry_2->name[len] != 0 ; len++)
			{
				/* Assumes ascii/latin1, but that's probably safe. */
				name[len] = le16toh(file.entry_2->name[len]);
			}
			name[len] = '\0';
		}
		if (file.data < data || (const char*)file.data + file.length > (const char *)data + length)
			return -1;
		
		block (&header, &file);
	}
	
	errno = perrno;
	return 0;
}
