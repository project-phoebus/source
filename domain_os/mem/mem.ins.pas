{ mem/mem.ins.pas - MEM_ (memory parity statistics) types, variables and
  routine headings, for the Domain Pascal tree.

  The physical address as MEM_$PARITY_LOG reads it, the parity-error
  record MEM_$MEM_REC, the module's two map-global variables and its
  routines; the module is mem/mem.pas.  Apollo's customer insert files
  of SR10.2 declare none of these (fault.ins.pas has only the fault
  status codes).  Include base/base.ins.pas before it.
}

const
  { The number of per-page records in MEM_$MEM_REC: 0x0E + 4 * 0x12 =
    0x56, the record's size. }
  mem_page_error_records = 4;

type
  { A byte of an address, an unsigned 8-bit integer (ref 3.15.5: "[byte]
    0..255 corresponds to the unsigned char data type in Domain/C"), the
    form of suma/suma.ins.pas's suma_$byte_t. }
  mem_$byte_t = [byte] 0..255;

  { A physical address's low 24 bits apart from its high byte, a packed
    record of 32 bits (ref 3.10.7, fields from the most significant
    bit). }
  mem_$addr_bits_t = packed record
    bits_31_24: 0..255;                   { bits 31..24 }
    bits_23_0: 0..16#FFFFFF;              { bits 23..0 }
  end;

  { A physical address as MEM_$PARITY_LOG reads it: the whole longword
    (`all', unsigned), its second byte, whose six low bits are address
    bits 21..16, and its low 24 bits.  A record with two variants (ref 3.10.3), so
    that byte can be read alone.  4 bytes, so `val_param' passes it by
    value (ref 5.5.7, "all arguments four bytes or less").  `all' is
    base.ins.pas's name for status_$t's longword. }
  mem_$phys_addr_t = record
    case integer of
      1: (all: linteger);                 { 0x00..0x03 }
      2: (byte_0: mem_$byte_t;            { 0x00 }
          byte_1: mem_$byte_t;            { 0x01: bits 21..16 in its
                                            low six bits }
          bytes_2_3: pinteger);           { 0x02..0x03 }
      3: (bits: mem_$addr_bits_t);        { 0x00..0x03 }
  end;

  { One per-page parity-error record, 18 bytes: addr at 0, count at 4;
    the 12 bytes from 6 are never addressed in the image. }
  mem_$page_error_t = record
    addr: mem_$phys_addr_t;               { 0x00 }
    count: pinteger;                      { 0x04 }
    reserved: array[1..12] of char;       { 0x06..0x11: never addressed }
  end;

  { MEM_$MEM_REC, 0x56 bytes, which ASKNODE_$INTERNET_INFO copies whole.
    - w_00: a word nothing in the image addresses but the copy (its
      initial value differs by SAU, mem/mem.pas).
    - n_boards: the number of memory boards, 2 in the image; with the
      `mem_ccr_board_size' or `mem_board_jumpers' part MEM_$INIT
      computes it (0 in the image with `mem_board_jumpers').
    - board_errors, from +0x04: the parity errors counted by board, from
      0.  The SAU2's MEM_$PARITY_LOG counts boards 1 (below 3MB) and 2,
      the SAU9's from 0 by the board size; the five words fill the
      record to page_errors.  ASKNODE_$INTERNET_INFO overwrites element
      0 in its copy with MMAP_$REAL_PAGES.
    - page_errors, from +0x0E: indexed 1..4. }
  mem_$mem_rec_t = record
    w_00: pinteger;                       { 0x00 }
    n_boards: pinteger;                   { 0x02 }
    board_errors: array[0..4] of pinteger;{ 0x04..0x0D }
    page_errors: array[1..mem_page_error_records] of mem_$page_error_t;
                                          { 0x0E..0x55 }
  end;

var
  { MEM_$SIZE, the first map symbol of the MEM_ data segment
    (WIRED_DATA): the memory's size in bytes, which the SAU9's MEM_$INIT
    reads; nothing in the SAU2 image reads or writes it. }
  mem_$size: extern integer32;

  { MEM_$MEM_REC (map symbol), at +4 of the block. }
  mem_$mem_rec: extern mem_$mem_rec_t;

{ MEM_$INIT - count the memory boards (map symbol of the SAU4 and
  SAU6..SAU9 MEM_ code; OS_$INIT calls it, no arguments). }
procedure mem_$init; extern;

{ MEM_$PARITY_LOG - count a memory parity error. }
procedure mem_$parity_log(phys_addr: mem_$phys_addr_t);
  options(extern, val_param);
