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

/* All data in the packed structs are in little endian, use above macros to access. */

#define ERF_FILENAME_MAXLEN 32

enum erf_encryption
{
	ERF_ENC_NONE, ERF_ENC_XOR, ERF_ENC_BLOWFISH, ERF_ENC_BLOWFISH_V3
};
#define ERF_FLAGS_ENCRYPTION(x) ((enum erf_encryption)(((x) >> 4) & 0xF))

enum erf_compression
{
	ERF_COMP_NONE, ERF_COMP_BWZLIB, ERF_COMP_UNK1, ERF_COMP_UNK2, ERF_COMP_HLZLIB
};
#define ERF_FLAGS_COMPRESSION(x) ((enum erf_compression)(((x) >> 29) & 0x7))

struct erf_header_entry_2
{
	uint16_t version[8];
	uint32_t num_entries;
	uint32_t year;
	uint32_t day;
	uint32_t unk1;
} __attribute__((packed));

struct erf_header_ext_2_2
{
	uint32_t flags;
	uint32_t module_id;
	uint8_t pw_digest[16];
} __attribute__((packed));

struct erf_header_entry_3
{
	uint16_t version[8];
	uint32_t num_names;
	uint32_t num_entries;
	uint32_t flags;
	uint32_t module_id;
	uint8_t pw_digest[16];
} __attribute__((packed));

struct erf_header
{
	const struct erf_header_entry_2 *entry_2;
	const struct erf_header_ext_2_2 *ext_2_2;
	const struct erf_header_entry_3 *entry_3;
	const char *names;
};

struct erf_file_entry_2
{
	uint16_t name[ERF_FILENAME_MAXLEN];
	uint32_t offset;
	uint32_t length;
} __attribute__((packed));

struct erf_file_ext_2_2
{
	uint32_t unpacked_length;
} __attribute__((packed));

struct erf_file_entry_3
{
	int32_t name_offset;
	uint64_t name_hash;
	uint32_t type_hash;
	uint32_t offset;
	uint32_t length;
	uint32_t unpacked_length;
};

struct erf_file
{
	const struct erf_file_entry_2 *entry_2;
	const struct erf_file_ext_2_2 *ext_2_2;
	const struct erf_file_entry_3 *entry_3;
	const void *data;
	const char *name;
	uint32_t length;
};

typedef void (^erf_entry_block)(struct erf_header *header, struct erf_file *file);

int parse_erf_data(const void *data, size_t length, erf_entry_block block);

#endif /*ERF_H*/
