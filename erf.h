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

#ifndef ERF_H
#define ERF_H

#include <stdint.h>
#include <machine/endian.h>
#include <sys/types.h>

#if BYTE_ORDER == LITTLE_ENDIAN
#define le16toh(x) (x)
#define le32toh(x) (x)
#else
#define le16toh(x) (((x) >> 8 & 0xFF) | ((x) << 8 & 0xFF00))
#define le32toh(x) (((x) >> 24 & 0xFF) | ((x) >> 8 & 0xFF00) | ((x) << 8 & 0xFF0000) | ((x) << 24 & 0xFF000000))
#endif

/* All data (except pointers) is in little endian, use above macros to access. */

#define ERF_FILENAME_MAXLEN 32

struct erf_header_entry
{
	uint16_t version[8];
	uint32_t num_entries;
	uint32_t unk1;
	uint32_t unk2;
	uint32_t unk3;
} __attribute__((packed));

struct erf_header_ext_2_2
{
	uint32_t unk[6];
} __attribute__((packed));

struct erf_header
{
	const struct erf_header_entry *entry;
	const struct erf_header_ext_2_2 *ext_2_2;
};

struct erf_file_entry
{
	uint16_t name[ERF_FILENAME_MAXLEN];
	uint32_t offset;
	uint32_t length;
} __attribute__((packed));

struct erf_file_ext_2_2
{
	uint32_t unk;
} __attribute__((packed));

struct erf_file
{
	const struct erf_file_entry *entry;
	const struct erf_file_ext_2_2 *ext_2_2;
	const void *data;
};

typedef void (^erf_entry_block)(struct erf_header *header, struct erf_file *file);

int parse_erf_data(const void *data, size_t length, erf_entry_block block);

#endif /*ERF_H*/
