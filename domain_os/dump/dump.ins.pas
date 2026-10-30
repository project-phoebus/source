{ dump/dump.ins.pas - DUMP (the crash-dump page), for the Domain Pascal
  tree.

  Only what the Pascal files use: DUMP_$ADDRS, the memory ranges
  MMAP_$INIT records.  No customer insert file declares these.  Include
  base/base.ins.pas before it.
}

type
  { One memory range, two longwords: MMAP_$INIT writes the start and the
    end, and masks the start to a 512 KB boundary. }
  dump_$mem_range_t = record
    start: integer32;                     { 0x00 }
    end_addr: integer32;                  { 0x04 }
  end;

var
  { DUMP_$ADDRS (a map symbol inside the DUMP data segment, hand-written,
    dump/sau2/dump.s): the ranges, indexed from 1; range n is at the
    symbol + 8 * (n - 1).  Two ranges: MMAP_$INIT crashes when its count
    passes 2, and the map's DUMP segment ends 0x14 bytes after the
    symbol. }
  dump_$addrs: extern array[1..2] of dump_$mem_range_t;
