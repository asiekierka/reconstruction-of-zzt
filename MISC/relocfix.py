#!/usr/bin/python3
#
# Copyright (c) 2020 Adrian Siekierka
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
# RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
# CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
# CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import collections, struct, sys

def fsize(fp):
	curr_pos = fp.tell()
	fp.seek(0, 2)
	fp_size = fp.tell()
	fp.seek(curr_pos, 0)
	return fp_size

def read8(fp, pos):
	fp.seek(pos)
	return struct.unpack("<B", fp.read(2))[0]

def read16(fp, pos):
	fp.seek(pos)
	return struct.unpack("<H", fp.read(2))[0]

segment_list = collections.OrderedDict()

with open(sys.argv[1], "r+b") as fp:
	fp_size = fsize(fp)
	if fp_size < 0x1C:
		raise Exception("Not a valid MZ .EXE file!")
	header = read16(fp, 0x00)
	if header != 0x5A4D:
		raise Exception("Not a valid MZ .EXE file!")
	rel_count = read16(fp, 0x06)
	if rel_count <= 0:
		raise Exception("No relocation entries in .EXE file!")
	rel_offs = read16(fp, 0x18)
	if rel_offs < 0x1C:
		raise Exception("Invalid relocation offset in .EXE file!")
	exe_offs = read16(fp, 0x08) * 16
	if exe_offs < (0x1C + (rel_count * 4)):
		raise Exception("Invalid? header size in .EXE file!")
	for rel_pos in range(0, rel_count):
		rel_entry_pos = rel_offs + (rel_pos * 4)
		rel_entry_offs = read16(fp, rel_entry_pos)
		rel_entry_seg = read16(fp, rel_entry_pos + 2)
		file_entry_pos = exe_offs + (rel_entry_seg * 16) + rel_entry_offs
		file_entry_offs = read16(fp, file_entry_pos + 2)
		file_entry_seg = read16(fp, file_entry_pos)
		segment_list[file_entry_seg] = 1
	segment_list[0] = 1 # ... yeah
	segment_list = collections.OrderedDict(sorted(segment_list.items()))
	print(segment_list)
	for rel_pos in range(0, rel_count):
		rel_entry_pos = rel_offs + (rel_pos * 4)
		rel_entry_offs = read16(fp, rel_entry_pos)
		rel_entry_seg = read16(fp, rel_entry_pos + 2)
		rel_entry_abs = (rel_entry_seg * 16 + rel_entry_offs)
		rel_entry_best_seg = 0
		for i in segment_list.keys():
			if (rel_entry_abs - (i * 16)) < 0:
				break
			rel_entry_best_seg = i
		rel_entry_best_offs = rel_entry_abs - (rel_entry_best_seg * 16)
		if rel_entry_best_offs >= 65536:
			raise Exception("Could not calculate replacement for %04X:%04X (%04X:%04X?)" % (rel_entry_seg, rel_entry_offs, rel_entry_best_seg, rel_entry_best_offs))
		print("%04X:%04X -> %04X:%04X" % (rel_entry_seg, rel_entry_offs, rel_entry_best_seg, rel_entry_best_offs))
		fp.seek(rel_entry_pos)
		fp.write(struct.pack("<HH", rel_entry_best_offs, rel_entry_best_seg))
