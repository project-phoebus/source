{ mmap/mmap.ins.pas - MMAP_ (the physical memory map and the working set
  lists), for the Domain Pascal tree.

  The page entry and working set list types, the table MMAP, the MMAP_
  block's map-symbol variables and every MMAP_ global's heading, in map
  order.  Include base/base.ins.pas before it.
}

const
  { The statuses the MMAP_ routines store or hand CRASH_SYSTEM (the SR10.2
    status-code database, "OS / MMAP manager"). }
  status_$mmap_bad_avail = 16#00060004;            { "bad avail" }
  status_$mmap_bad_unavail = 16#00060006;          { "bad unavail" }
  status_$mmap_examined_max = 16#00060007;         { "examined max" }
  status_$mmap_inconsistent_mmape = 16#00060008;   { "inconsistent mmape" }
  status_$mmap_illegal_wsl_index = 16#00060009;    { "illegal wsl index" }
  status_$mmap_illegal_pid = 16#0006000A;          { "illegal pid" }
  status_$mmap_ws_lists_exhausted = 16#0006000B;   { "ws lists exhsusted" }
  status_$mmap_bad_install = 16#0006000C;          { "bad install": AST_$TOUCH's
                                          and AST_$TOUCH_AREA's
                                          CRASH_SYSTEM cell (AST part 4) }
  status_$mmap_bad_reclaim = 16#0006000D;          { "bad reclaim" }
  status_$mmap_contig_pages_unavailable = 16#0006000E;
                                          { "contiguous pages unavailable" }

  { A working set list header's in-use member (16#80 of the header's first
    byte): bit 15 of its first word, tested as the word's sign
    (MMAP_$SET_WS_INDEX) and set and cleared as bit 15 on the word's first
    byte (MMAP_$FREE_WSL). }
  mmap_$wsl_in_use = 15;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  mmap_$byte_t = [byte] 0..255;

  { The first word of a page entry as MMAP_$INIT reads it, the memory
    probe's result: bit 15 present, bit 14 pageable.  Read as a word and
    tested by bit and by sign: the members of a word set
    (a member of 8..15 tested on the word, member
    15 its sign). }
  mmap_$probe_t = set of 0..15;

  { One physical page's entry, 16 bytes.  A packed
    record (ref 3.10.7): the flag bits are set and cleared one by one,
    and tested by sign and by bit, and two of them are cleared together on
    the record's word (MMAP_$FREE_PAGES: constant stores into sub-byte
    packed fields on the word).
    The byte fields are 8-bit subranges, bit aligned (Table 3-3), and fall
    on their bytes.
    - wire_count (0x00): compared and stepped as a byte (MMAP_$WIRE,
      _$UNWIRE).
    - wsl_index (0x04): compared unsigned (MMAP_$AVAIL), pushed
      zero-extended; OSINFO_$GET_MMAP reads it zero-extended.  The
      conformance unit mmap_avail.pas types it `char' so that dpc
      compares on the byte; the source's type is not known.
    - in_wsl (0x05 bit 7), impure (0x05 bit 6).
    - flags2_7 (0x09 bit 7), read elsewhere as "on disk" or "wired".  It
      selects between the object's DTM and its location in the dirty-page
      tests (mmap/trim_wsl.pas), and MMAP_$FREE and _$FREE_REMOVE clear
      it.
    - modified (0x09 bit 6), tested beside the page's hardware modified
      bit (the PFT's, or the page descriptor's).
    - the six low bits of each flag byte are not addressed alone
      (stand-ins).
    The second variant is MMAP_$INIT's view of the first word
    (mmap_$probe_t). }
  { A page entry's disk address word (the mask 16#3FFFFF, bit 22 the
    ASTE-dirty bit): read whole and masked (PMAP's write routines, six
    sites), stored whole, and bit 22 tested and cleared on its byte
    (pmap_$write_complete).  So a packed record with two views, and a third,
    the high word as a set of 0..15 and the low word: ast_$update_aste tests
    bit 22 on the word, as member 6 of the high word's set (a word set's
    member test).  Probed with `dpc -o': hi_set +0x00, lo_word +0x02, the
    record 4 bytes; the first view is the whole word. }
%if large_vm %then
  { With the large VM layout the disk address is the low 21 bits, and
    the ASTE-dirty bit bit 21 (AST_$GET_SEG_MAP tests it as member 5 of
    the high word's set). }
  mmap_$daddr_t = packed record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (bits_31_22: 0..1023;            { bits 31..22 }
          aste_dirty: boolean;            { bit 21 }
          daddr: 0..16#1FFFFF);           { bits 20..0 }
      3: (hi_set: set of 0..15;           { 0x00: bits 31..16 }
          lo_word: integer);              { 0x02 }
  end;
%else
  mmap_$daddr_t = packed record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (bits_31_23: 0..511;             { bits 31..23 }
          aste_dirty: boolean;            { bit 22 }
          daddr: 0..16#3FFFFF);           { bits 21..0 }
      3: (hi_set: set of 0..15;           { 0x00: bits 31..16 }
          lo_word: integer);              { 0x02 }
  end;
%endif

%if mmap_ppns_10000 %then
  { With pages above 16#FFFF the list links are 22 bits, each taking the
    six low bits of its flag byte and the word after it: the field
    extract and insert of a packed field (MMAP_$FREE_LIST,
    mmap_$add_to_wsl). }
  mmap_$mmape_t = packed record
    case integer of
      1: (wire_count: mmap_$byte_t;       { 0x00 }
          seg_offset: mmap_$byte_t;       { 0x01 }
          segment: pinteger;              { 0x02 }
          wsl_index: mmap_$byte_t;        { 0x04 }
          in_wsl: boolean;                { 0x05 bit 7 }
          impure: boolean;                { 0x05 bit 6 }
          prev_vpn: 0..16#3FFFFF;         { 0x05 bits 5..0, 0x06 }
          priority: mmap_$byte_t;         { 0x08 }
          flags2_7: boolean;              { 0x09 bit 7 }
          modified: boolean;              { 0x09 bit 6 }
          next_vpn: 0..16#3FFFFF;         { 0x09 bits 5..0, 0x0A }
          disk_addr: mmap_$daddr_t);      { 0x0C }
      2: (probe: mmap_$probe_t);          { 0x00 }
  end;
%else
  mmap_$mmape_t = packed record
    case integer of
      1: (wire_count: mmap_$byte_t;       { 0x00 }
          seg_offset: mmap_$byte_t;       { 0x01 }
          segment: pinteger;              { 0x02 }
          wsl_index: mmap_$byte_t;        { 0x04 }
          in_wsl: boolean;                { 0x05 bit 7 }
          impure: boolean;                { 0x05 bit 6 }
          flags1_5_0: 0..63;              { 0x05 bits 5..0 }
          prev_vpn: pinteger;             { 0x06 }
          priority: mmap_$byte_t;         { 0x08 }
          flags2_7: boolean;              { 0x09 bit 7 }
          modified: boolean;              { 0x09 bit 6 }
          flags2_5_0: 0..63;              { 0x09 bits 5..0 }
          next_vpn: pinteger;             { 0x0A }
          disk_addr: mmap_$daddr_t);      { 0x0C }
      2: (probe: mmap_$probe_t);          { 0x00 }
  end;
%endif

  { A pointer to a page entry: pmap_$write_complete holds one, formed
    exactly from MMAP's address + 16 * page. }
  mmap_$mmape_ptr_t = ^mmap_$mmape_t;

  { A working set list header's flag word: a word set, member 15
    mmap_$wsl_in_use; MMAP_$INIT sets member 13 of list 6 too, and clears
    members 11..15 of every list. }
  mmap_$wsl_flags_t = set of 0..15;

  { One working set list header, 0x24 bytes.  The
    counts are compared unsigned (MMAP_$INSTALL_LIST, mmap_$trim_wsl,
    MMAP_$WS_SCAN): linteger.  OSINFO_$GET_MMAP reads page_count,
    pri_timestamp and ws_timestamp as longwords, and stores ws_floor. }
  mmap_$ws_hdr_t = record
    flags: mmap_$wsl_flags_t;             { 0x00 }
    owner: pinteger;                      { 0x02 }
    page_count: linteger;                 { 0x04 }
    scan_pos: linteger;                   { 0x08 }
    head_vpn: linteger;                   { 0x0C }
    max_pages: linteger;                  { 0x10 }
    field_14: linteger;                   { 0x14 }
    pri_timestamp: integer32;             { 0x18 }
    ws_timestamp: integer32;              { 0x1C }
    ws_floor: linteger;                   { 0x20 }
  end;

  { A list of page numbers, longwords indexed from 1
    (mmap_$add_pages_to_wsl reads element 1 at the address, and element
    count at the end).  The callers pass arrays of every size by address,
    so the formals are `univ'.  The bound is the SAU2 table's size
    (3584 pages); no routine depends on it. }
  mmap_$vpn_list_t = array[1..3584] of integer32;

const
  { The pageable pages, MMAP's index range; the 0x400-byte pages the
    table MMAP fills (16 bytes per entry); a working set list's maximum
    at boot (MMAP_$INIT); MMAP_$LPPN's initial value, which MMAP_$INIT
    lowers to the lowest pageable page. }
%if mmap_ppns_10000 %then
  mmap_$first_ppn = 16#10000;
  mmap_$last_ppn = 16#1FFFF;
  mmap_$table_pages = 1024;
  mmap_$boot_ws_max = 65536;
  mmap_$lppn_seed = 16#FFFF;
%elseif mmap_ppns_400 %then
  mmap_$first_ppn = 16#400;
  mmap_$last_ppn = 16#23FF;
  mmap_$table_pages = 128;
  mmap_$boot_ws_max = 16384;
  mmap_$lppn_seed = 16#3FFF;
%else
  mmap_$first_ppn = 16#200;
  mmap_$last_ppn = 16#FFF;
  mmap_$table_pages = 56;
  mmap_$boot_ws_max = 4096;
  mmap_$lppn_seed = 16#FFF;
%endif

type
  { MMAP_$INIT's table, one longword for each 0x400-byte page of the
    table MMAP: seeded with 16#FFF by a counted loop, indexed from 1 by
    a stepped pointer. }
  mmap_$init_table_t = array[1..mmap_$table_pages] of linteger;

var
  { MMAP (map symbol without `$', the first symbol of the map's
    OS_PMAPS): the page entries, element mmap_$first_ppn at the symbol.
    OSINFO_$GET_MMAP forms an entry's address as MMAP + 16 * page and
    reads its fields with the lower bound folded in (-0x2000 + offset
    for 16#200).  The upper bound: on the SAU2 MMU_$PTTX follows 0xE000
    bytes later, 3584 entries, 16#200..16#FFF; on the SAU9 OS_PMAPS
    follows 0x100000 bytes later, 65536 entries, 16#10000..16#1FFFF; on
    the SAU8 OS_PMAPS follows 0x20000 bytes later, 8192 entries,
    16#400..16#23FF.  Not the MMAP_ module's: OS_PMAPS has no code
    segment, and MMAP_$INIT fills it. }
  mmap: extern array[mmap_$first_ppn..mmap_$last_ppn] of mmap_$mmape_t;

  { The map symbols of the MMAP_ block, defined by mmap/mmap.pas (at
    +0x004 ..).  The block's first longword, the module's spin lock, has
    no map symbol (mmap/mmap.pas mmap_$lock).  MMAP_$HI_INDX and
    MMAP_$LO_INDX, MMAP's bounds, are read by nothing. }
  mmap_$hi_indx: extern integer32;
  mmap_$lo_indx: extern integer32;

  { The counters and sizes OSINFO_$GET_MMAP copies, all longwords read with
    their absolute addresses: integer32.  MMAP_$HPPN and MMAP_$LPPN are
    compared unsigned with a page number (OSINFO_$GET_MMAP, MMAP_$INIT):
    linteger. }
  mmap_$ws_remove: extern integer32;
  mmap_$reclaim_pur_cnt: extern integer32;
  mmap_$reclaim_shar_cnt: extern integer32;
  mmap_$ws_scan_cnt: extern integer32;
  mmap_$ws_overflow: extern integer32;
  mmap_$steal_cnt: extern integer32;
  mmap_$alloc_pages: extern integer32;
  mmap_$alloc_cnt: extern integer32;

  { MMAP_$WSL: the working set lists, 0x9D8 bytes to MMAP_$MIN_RMT_POOL,
    70 headers of 0x24 bytes.  Indexed from 0 at the symbol:
    OSINFO_$GET_MMAP reads pool 0's page_count at +0x4 and indexes from
    the symbol; the MMAP_ routines reach list i at +0x2C of the block +
    i * 0x24. }
  mmap_$wsl: extern array[0..69] of mmap_$ws_hdr_t;

  { MMAP_$MIN_RMT_POOL (66 in the image): NETWORK_$PAGE_SERVER adds
    to it and compares it signed: integer32.
    MMAP_$PAGEABLE_PAGES_LOWER_LIMIT (66), written by NETWORK:
    integer32. }
  mmap_$min_rmt_pool: extern integer32;
  mmap_$hppn: extern linteger;
  mmap_$lppn: extern linteger;
  mmap_$pageable_pages_lower_limit: extern integer32;
  { MMAP_$PAGEABLE_PAGES: linteger, was integer32: MMAP's own code only
    adds to it and subtracts from it, and PMAP_$PURIFIER_L divides it
    unsigned, inline and by M$DIU$LLW: ref 4.3.3, `div' is unsigned only
    when both operands are unsigned.  Its other users (mmap's
    alloc_pages_from_wsl, get_impure, init, internal, ws_scan) add and
    subtract only. }
  mmap_$pageable_pages: extern linteger;
  mmap_$remote_pages: extern integer32;
  { MMAP_$REAL_PAGES: linteger, was integer32: ASKNODE_$INTERNET_INFO
    compares it unsigned with 16#FFFF, and MMAP's own code only counts it
    up, `mmap_$real_pages := mmap_$real_pages + 1' (mmap/init.pas).  Its
    other users, a shift (dbuf/init.pas) and an assignment
    (osinfo/get_mmap.pas), take either type. }
  mmap_$real_pages: extern linteger;

  { MMAP_$FORMAT, a word (1 in the image) that nothing reads: integer. }
  mmap_$format: extern integer;

  { MMAP_$WSL_HI_MARK (8 in the image), a word compared unsigned
    (OSINFO_$GET_MMAP, MMAP_$PURGE): pinteger. }
  mmap_$wsl_hi_mark: extern pinteger;

  { MMAP_$WS_OWNER: a word per address space, 0x80 bytes to
    MMAP_$RMT_LIMIT, 64 words, indexed from 1:
    OSINFO_$GET_MMAP and the MMAP_ routines index it with the lower bound
    folded into the displacement; MMAP_$INIT clears 2..64 and stores 7
    into 1.  The working set list of each address space, read as an
    index into MMAP_$WSL: pinteger. }
  mmap_$ws_owner: extern array[1..64] of pinteger;

  { MMAP_$RMT_LIMIT, the block's last longword; NETWORK tests its first
    byte's sign, which no MMAP_ routine reads: integer32 here, its type
    for NETWORK to settle. }
  mmap_$rmt_limit: extern integer32;

{ The headings of the MMAP_ globals, in map order.  Unless said otherwise
  each is compiled, loads A5 with the MMAP_ block
  and takes its words, bytes and longwords by value, read straight from
  the slots, and its records and arrays by address: `val_param' (ref
  5.2, Table 5-1). }

{ MMAP_$SET_WS_PRI - stamp the current process's working set with the
  time. }
procedure mmap_$set_ws_pri; extern;

{ MMAP_$GET_WS_SIZ - report a working set list's sizes. }
procedure mmap_$get_ws_siz(wsl_index: pinteger; out page_count: linteger;
                           out field_14: linteger; out max_pages: linteger;
                           out status: status_$t);
  options(extern, val_param);

{ MMAP_$GET_WS_INDEX - return an address space's working set list index. }
procedure mmap_$get_ws_index(pid: pinteger; out wsl_index: pinteger;
                             out status: status_$t);
  options(extern, val_param);

{ MMAP_$SET_WS_MAX - set a working set list's maximum. }
procedure mmap_$set_ws_max(wsl_index: pinteger; max_pages: integer32;
                           out status: status_$t);
  options(extern, val_param);

{ MMAP_$FREE - put a page on the free pool. }
procedure mmap_$free(vpn: integer32); options(extern, val_param);

{ MMAP_$FREE_LIST - put a chain of pages on the free pool. }
procedure mmap_$free_list(vpn: integer32); options(extern, val_param);

{ MMAP_$FREE_REMOVE - take a page off its list and put it on the free
  pool. }
procedure mmap_$free_remove(var page: mmap_$mmape_t; vpn: integer32);
  options(extern, val_param);

{ MMAP_$IMPURE_TRANSFER - move a dirty page to the pure pool. }
procedure mmap_$impure_transfer(var page: mmap_$mmape_t; vpn: integer32);
  options(extern, val_param);

{ MMAP_$UNAVAIL_REMOV - take a page off its working set list. }
procedure mmap_$unavail_remov(vpn: integer32; unused_flag: boolean);
  options(extern, val_param);

{ MMAP_$AVAIL - put a page back on its working set list. }
procedure mmap_$avail(vpn: integer32); options(extern, val_param);

{ MMAP_$WIRE - wire a page.
  MMAP_$UNWIRE - unwire a page. }
procedure mmap_$wire(ppn: integer32); options(extern, val_param);
procedure mmap_$unwire(ppn: integer32); options(extern, val_param);

{ MMAP_$INSTALL_LIST - put a list of pages on a working set list. }
procedure mmap_$install_list(in vpn_array: univ mmap_$vpn_list_t;
                             count: pinteger; use_wired: boolean);
  options(extern, val_param);

{ MMAP_$INSTALL_PAGES - put a list of pages on an address space's
  working set list. }
procedure mmap_$install_pages(in vpn_array: univ mmap_$vpn_list_t;
                              count: pinteger; pid: pinteger);
  options(extern, val_param);

{ MMAP_$FREE_PAGES - put a list of pages on the free pool. }
procedure mmap_$free_pages(pid: pinteger;
                           in vpn_array: univ mmap_$vpn_list_t;
                           count: pinteger);
  options(extern, val_param);

{ MMAP_$RELEASE_PAGES - move an address space's unwired pages to the
  global pools. }
procedure mmap_$release_pages(pid: pinteger;
                              in vpn_array: univ mmap_$vpn_list_t;
                              count: pinteger);
  options(extern, val_param);

{ MMAP_$PURGE - empty a working set list. }
procedure mmap_$purge(wsl_index: pinteger); options(extern, val_param);

{ MMAP_$FREE_WSL - release an address space's working set list. }
procedure mmap_$free_wsl(pid: pinteger); options(extern, val_param);

{ MMAP_$SET_WS_INDEX - give an address space a working set list. }
procedure mmap_$set_ws_index(pid: pinteger; in out wsl_index: pinteger);
  options(extern, val_param);

{ MMAP_$WS_SCAN - take pages off a working set list for the paging
  daemon. }
function mmap_$ws_scan(wsl_index: pinteger; mode: boolean;
                       pages_needed: linteger; unused: integer32): linteger;
  options(extern, val_param);

{ MMAP_$GET_IMPURE - take impure pages off a list for the purifier. }
procedure mmap_$get_impure(wsl_index: pinteger;
                           out vpn_array: univ mmap_$vpn_list_t;
                           all_pages: boolean; max_pages: pinteger;
                           out scanned: linteger; out returned: pinteger);
  options(extern, val_param);

{ MMAP_$ALLOC_PURE - allocate pages from the pure and impure pools.
  MMAP_$ALLOC_FREE - allocate pages from the free pool. }
function mmap_$alloc_pure(out vpn_array: univ mmap_$vpn_list_t;
                          count: pinteger): pinteger;
  options(extern, val_param);
function mmap_$alloc_free(out vpn_array: univ mmap_$vpn_list_t;
                          count: pinteger): pinteger;
  options(extern, val_param);

{ MMAP_$ALLOC_CONTIG - allocate contiguous pages.  The page numbers
  go to a list by address (the SAU9's RING_8025 passes six longwords). }
procedure mmap_$alloc_contig(n: integer; out ppns: univ mmap_$vpn_list_t;
                             out status: status_$t);
  options(extern, val_param);

{ MMAP_$RECLAIM - take pages back from the global pools. }
procedure mmap_$reclaim(in vpn_array: univ mmap_$vpn_list_t;
                        count: pinteger; use_wired: boolean);
  options(extern, val_param);

{ MMAP_$INIT - build the memory map at boot. }
procedure mmap_$init(out table: mmap_$init_table_t); extern;

{ MMAP_$REMOTE_POOL - the remote page pool's size for a request. }
function mmap_$remote_pool(param: integer32): integer32;
  options(extern, val_param);
