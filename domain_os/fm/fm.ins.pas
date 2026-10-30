{ fm/fm.ins.pas - FM_ (the file map) types, constants and routine
  headings, for the Domain Pascal tree.

  FM_$READ and FM_$WRITE are routines of the VTOC_ module
  (fm/README.md).  Apollo's customer insert files of SR10.2
  declare none of these.  Include base/base.ins.pas before it.
}

const
  { DBUF_$SET_BUFF's operation word: release (FM_$READ), dirty or
    writeback (FM_$WRITE). }
  fm_buf_release = 16#08;
  fm_buf_dirty = 16#09;
  fm_buf_writeback = 16#0B;

type
  { One file-map entry, 32 block addresses, 0x80 bytes, copied whole.
    The array's lower bound is 0: VTOCE_$TRUNCATE indexes a VTOCE's
    direct map by the file's block number. }
  fm_$entry_t = record
    blocks: array[0..31] of integer32;    { 0x00..0x7F }
  end;
  fm_$entry_ptr_t = ^fm_$entry_t;

  { A block address: a longword whose top 28 bits are the block number
    and whose low 4 bits are the entry's index, a packed record (ref
    3.10.7), passed by value under `val_param' (ref 5.5.7).  The VTOCE
    locations of VTOC_ are this record too (vtoc/vtoc.ins.pas), which
    VTOC_ also tests and compares whole: the variant `all', the
    longword. }
  fm_$block_addr_t = packed record
    case integer of
      1: (block_num: 0..16#0FFFFFFF;      { bits 31..4 }
          entry_idx: 0..15);              { bits 3..0 }
      2: (all: integer32);
  end;

  { A byte of a file reference, an unsigned 8-bit integer (ref 3.15.5),
    the form of suma/suma.ins.pas's suma_$byte_t. }
  fm_$byte_t = [byte] 0..255;

  { The file reference FM_$READ and FM_$WRITE are given, 0x20 bytes, a
    partial layout: the file's UID at 0x08 and the volume index at 0x1C.
    The callers pass the address 0x9C into an AST entry. }
  fm_$file_ref_t = record
    reserved_00: integer32;               { 0x00 }
    reserved_04: integer32;               { 0x04 }
    file_uid: uid_$t;                     { 0x08 }
    reserved_10: integer32;               { 0x10 }
    reserved_14: integer32;               { 0x14 }
    reserved_18: integer32;               { 0x18 }
    vol_idx: fm_$byte_t;                  { 0x1C }
    reserved_1d: char;                    { 0x1D }
    reserved_1e: char;                    { 0x1E }
    reserved_1f: char;                    { 0x1F: (layout)
                                            three chars, not a 3-char
                                            array, which is word aligned
                                            (ref 3.10.5.5) and made the
                                            record 0x22 bytes }
  end;

{ FM_$READ - read one file-map entry out of a VTOC block or a file-map
  block. }
procedure fm_$read(in file_ref: fm_$file_ref_t;
                   block_addr: fm_$block_addr_t;
                   level: pinteger;
                   out entry_out: fm_$entry_t;
                   out status: status_$t);
  options(extern, val_param);

{ FM_$WRITE - write one file-map entry into a VTOC block or a file-map
  block. }
procedure fm_$write(in file_ref: fm_$file_ref_t;
                    block_addr: fm_$block_addr_t;
                    level: pinteger;
                    in entry_in: fm_$entry_t;
                    write_now: boolean;
                    out status: status_$t);
  options(extern, val_param);
