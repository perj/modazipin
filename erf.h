/*
 *  erf.h
 *  modazipin
 *
 *  Created by Pelle Johansson on 2010-01-07.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
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

/* All data is in little endian, use above macros to access. */

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

void parse_erf_data(const void *data, size_t length, erf_entry_block block);

#endif /*ERF_H*/
