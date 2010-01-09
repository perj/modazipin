
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

