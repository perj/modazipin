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

/* XXX verify access within length */
void
parse_erf_data(const void *data, size_t length, erf_entry_block block)
{
	const char *ptr = (const char*)data;
	struct erf_header header = {NULL};
	struct erf_file file = {NULL};
	int i, n;
	
	header.entry = (const struct erf_header_entry *)ptr;
	ptr += sizeof (*header.entry);
	
	n = le32toh (header.entry->num_entries);
	
	/* XXX check the whole version number. */
	if (le16toh (header.entry->version[7]) == '2')
	{
		header.ext_2_2 = (const struct erf_header_ext_2_2*)ptr;
		ptr += sizeof (*header.ext_2_2);
	}

	for (i = 0 ; i < n ; i++)
	{
		file.entry = (const struct erf_file_entry*)ptr;
		ptr += sizeof (*file.entry);
		
		if (header.ext_2_2)
		{
			file.ext_2_2 = (const struct erf_file_ext_2_2*)ptr;
			ptr += sizeof (*file.ext_2_2);
		}
		
		file.data = (const char*)data + le32toh (file.entry->offset);
		
		block (&header, &file);
	}
}

