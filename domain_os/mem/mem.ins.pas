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

%if ecc_memory %then
  { The memory boards' error-correcting controllers (`ecc_memory'): up to
    four boards, each with its controller in one of eight slots of the
    board's 256-byte page of MEM, which MEM_$INIT finds by probing. }
  mem_ecc_boards = 4;
  mem_ecc_slots = 8;

  { The bits of a controller's status (members of its high word, `flags'
    below): set when it has nothing to report (MEM_$ECCC_LOG passes the
    board over), and an uncorrectable error. }
  mem_ecc_no_error = 9;
  mem_ecc_uncorrectable = 8;

  { The control words written to a controller's high word: reporting on,
    and the form MEM_$ECCC_LOG writes once a board has had
    mem_ecc_error_limit corrected errors. }
  mem_ecc_ctl_report = 3;
  mem_ecc_ctl_quiet = 1;
  mem_ecc_error_limit = 2000;
%endif

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

%if ecc_memory %then
  { An error-correcting controller's status as a packed record of 32
    bits (ref 3.10.7): page, bits 23..14, is the failing location's page
    as MEM_$ECCC_LOG records it. }
  mem_$ecc_bits_t = packed record
    bits_31_24: 0..255;                   { bits 31..24 }
    page: 0..1023;                        { bits 23..14 }
    bits_13_0: 0..16#3FFF;                { bits 13..0 }
  end;

%endif
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
%if ecc_memory %then
      4: (ecc: mem_$ecc_bits_t);          { 0x00..0x03: a controller's
                                            status, MEM_$ECCC_LOG's }
%endif
  end;

%if ecc_memory %then
  { A controller's status register, a longword: read whole, its high
    word's bits tested as a set (member k bit 16 + k), the control word
    written to the high word alone. }
  mem_$ecc_csr_t = record
    case integer of
      1: (all: linteger);                 { 0x00..0x03 }
      2: (flags: set of 0..15;            { 0x00 }
          low: pinteger);                 { 0x02 }
      3: (ctl: integer);                  { 0x00 }
      4: (bits: mem_$ecc_bits_t);         { 0x00..0x03 }
  end;

  { A slot of a board's page, 32 bytes: the controller's status register
    at +2. }
  mem_$ecc_slot_t = record
    unused_00: integer;                   { 0x00 }
    csr: mem_$ecc_csr_t;                  { 0x02 }
    unused_06: array[1..26] of char;      { 0x06..0x1F }
  end;

  { A board's page of MEM, 256 bytes. }
  mem_$ecc_board_t = array[1..mem_ecc_slots] of mem_$ecc_slot_t;

  { The entry MEM_$ECCC_LOG adds to the system log, 6 bytes: the board
    and the controller's status. }
  mem_$ecc_log_entry_t = record
    board: integer;                       { 0x00 }
    csr: linteger;                        { 0x02 }
  end;
%endif

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
    (WIRED_DATA; at +8 with `ecc_memory'): the memory's size in bytes,
    which the SAU9's MEM_$INIT reads; nothing in the SAU2 image reads or
    writes it. }
  mem_$size: extern integer32;

  { MEM_$MEM_REC (map symbol), at +4 of the block (+0xC with
    `ecc_memory'). }
  mem_$mem_rec: extern mem_$mem_rec_t;

%if ecc_memory %then
  { MEM (map symbol of the I/O definitions, without `$'): the memory
    boards' pages, the controllers' registers. }
  mem: extern array[1..mem_ecc_boards] of mem_$ecc_board_t;
%endif

{ MEM_$INIT - count the memory boards (map symbol of the SAU4 and
  SAU6..SAU9 MEM_ code; OS_$INIT calls it, no arguments). }
procedure mem_$init; extern;

{ MEM_$PARITY_LOG - count a memory parity error. }
procedure mem_$parity_log(phys_addr: mem_$phys_addr_t);
  options(extern, val_param);

{ MEM_$ECCC_LOG - log and count a corrected memory error (`ecc_memory';
  the hand-written FIM_$ECCC_TRAP calls it, no arguments). }
procedure mem_$eccc_log; extern;
