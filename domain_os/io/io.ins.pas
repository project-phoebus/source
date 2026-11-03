{ io/io.ins.pas - IO_ (the I/O manager) constants, for the Domain Pascal
  tree.

  Only what the Pascal files use.  Apollo's customer insert files of
  SR10.2 declare none of these.  The IO_ module is io/io.pas.  Include
  base/base.ins.pas and ml/ml.ins.pas (for ml_$exclusion_t) before it.
}

const
  { The I/O manager's status codes (subsystem 0x10); the text is the
    SR10.2 status-code database's ("OS / I/O manager", "(100002)
    controller not in system").  SCSI_$CINIT returns it
    (scsi/cinit.pas). }
  status_$io_controller_not_in_system = 16#00100002;

  { "(100001) controller not found" and "(100007) bad dcte length"
    (stcode.db.10.2): IO_$GET_DCTE stores the first, io_$build_dcte_list
    the second. }
  status_$io_controller_not_found = 16#00100001;
  status_$io_bad_dcte_length = 16#00100007;

  { The unit routines' statuses.  No Apollo name exists: the names are
    made from the SR10.2 status-code database's text ("OS / I/O
    manager"), in the form of the two above.  The nested routine of
    IO_$ACQUIRE passes 0x100005 to CRASH_SYSTEM; io_$check_unit stores
    0x100008, 0x100009, IO_$ACQUIRE 0x10000B .. 0x10000E.  0x100004's
    text is 0x10000D's too ("interrupt id already in use"); no SAU2
    routine stores 0x100004, so the name goes to the stored one. }
  status_$io_int_id_not_implemented = 16#00100005;
                                        { "interrupt id not implemented
                                          for this bus" }
  status_$io_illegal_unit_number = 16#00100008;
                                        { "illegal unit number" }
  status_$io_unit_not_acquired = 16#00100009;
                                        { "unit not acquired" }
  status_$io_unit_table_full = 16#0010000B;
                                        { "unit table full" }
  status_$io_illegal_csr_address = 16#0010000C;
                                        { "illegal CSR address" }
  status_$io_int_id_in_use = 16#0010000D;
                                        { "interrupt id already in use" }
  status_$io_csr_page_in_use = 16#0010000E;
                                        { "CSR page already in use" }

  { IO_$INIT's statuses with the PROM's configuration record
    (`prom_config_record'), named from the same texts. }
  status_$io_device_failed_self_test = 16#00100011;
                                        { "device failed self-test" }
  status_$io_boot_device_not_found = 16#00100012;
                                        { "boot device not found" }

  { The I/O map routines' statuses (IO_$ALLOC .. IO_$FREE_MAP_REGION, on
    the SAUs with the PBU, `pbu_driver'): codes of the PBU subsystem
    (0x1E), whose texts are the SR10.2 status-code database's.  No
    Apollo name exists: the names follow the texts, in the form of
    pbu/pbu.ins.pas's status_$pbu_not_present. }
  status_$pbu_bad_parameter = 16#001E0010;
                                        { "bad parameter" }
  status_$pbu_no_room_in_iomap = 16#001E0011;
                                        { "no room in iomap" }
  status_$pbu_iomap_in_use = 16#001E0012;
                                        { "requested iomap in use" }
  status_$pbu_iomap_not_allocated = 16#001E0014;
                                        { "iomap not allocated" }
  status_$pbu_invalid_iova = 16#001E0015;
                                        { "invalid iova" }
  status_$pbu_not_supported = 16#001E0032;
                                        { "function not supported for this
                                          device type" }

  { The code io_$add_region and IO_$FREE_MAP pass to CRASH_SYSTEM when
    the region list is exhausted or a region cannot be freed: 0x2A, which
    has no text in the status-code database (MBUS_$DEFINE_INT crashes
    with the same code). }
  status_$io_region_crash = 16#0000002A;

type
  { A device controller table entry, 0x40 bytes.  SYSBUS_$INIT walks the
    list through nextp, tests ctype as a word and copies the longwords
    at 0x34, 0x38 (sysbus/init.pas).  IO_'s routines (io/io.pas) read
    kind as a word compared with 1; length as a word tested, masked and
    widened unsigned; cnum, compared; cstatus, stored and tested as a
    longword; name, its first byte tested and the array passed by
    address; io_va and io_pa, longwords.  disk_dinit and disk_do_io are
    univ_ptr: DISK_INTERRUPT calls through the copy of disk_do_io and
    reads a word at +6 of disk_dinit's, so a routine pointer and a data
    pointer, whose Pascal types are for that routine's translation
    (disk/). }
  dcte_ptr_t = ^dcte_t;

  { A controller's initialization routine, the DCTE's csrsytr: IO_$INIT
    calls it with the DCTE by address and stores its D0 as the DCTE's
    status: a function of the DCTE, the default convention (one
    address), an integer32 result.  The parameter is `univ' because its
    type, dcte_t, is declared after this type (the field below needs
    it): a routine pointer's parameter types must be declared before it;
    `univ' passes the DCTE by address the same way. }
  dcte_init_proc_t = ^function(var dcte: univ integer32): integer32;

  { (FLP addition.)  The longword at 0x3C is also read as its high word:
    FLP_DO_IO pushes it to ML_$LOCK and ML_$UNLOCK, and FLP_$CINIT passes
    its address to DISK_$REGISTER's word `flags': a variant part over the
    field, the longword's reading kept as the first (no Pascal file names
    it). }
  dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04: the controller type }
    cnum: pinteger;                       { 0x06 }
    nextp: dcte_ptr_t;                    { 0x08 }
    csrsytr: dcte_init_proc_t;            { 0x0C: IO_$INIT's call }
    cstatus: status_$t;                   { 0x10 }
    name: array[1..8] of char;            { 0x14 }
    reserved_1c: array[1..11] of char;    { 0x1C }
    config_flags: [byte] set of 0..7;     { 0x27: member
                                            io_$dcte_crash_line }
    vector_ptr: integer32;                { 0x28 }
    io_va: integer32;                     { 0x2C }
    io_pa: integer32;                     { 0x30 }
    disk_dinit: univ_ptr;                 { 0x34 }
    disk_do_io: univ_ptr;                 { 0x38 }
    case integer of                       { 0x3C }
      1: (disk_error_que: integer32);     { 0x3C }
      2: (disk_error_que_hi: integer;     { 0x3C: FLP_DO_IO's lock number }
          disk_error_que_lo: integer);    { 0x3E }
  end;

const
  { The DCTE's config_flags member SIO16550_$INIT passes to SIO_$INIT as
    its crash argument (sio16550/init.pas). }
  io_$dcte_crash_line = 2;

  { The members IO_$INIT sets with the PROM's configuration record
    (`prom_config_record'): the boot device's DCTE, the network boot
    device's, and the console's (the console line's is
    io_$dcte_crash_line). }
  io_$dcte_boot_device = 0;
  io_$dcte_net_boot_device = 1;
  io_$dcte_console = 3;

  { The interrupt vectors SYSBUS_$INIT installs. }
  io_vector_ring = 16#1B;
  io_vector_disk = 16#1D;

  { The DCTE's controller types (ctype, +0x04), SYSBUS_$INIT's case
    labels.  New descriptive names (no Apollo names exist), after the
    map's three static DCTEs, whose ctype words are these values:
    WIN_DCTE 0, FLP_DCTE 1, RING_DCTE 2.  RING_$GET_ID's 2
    (ring/get_id.pas) agrees. }
  io_ctype_win = 0;
  io_ctype_flp = 1;
  io_ctype_ring = 2;

  { Two more, after the SAU5 map's static DCTEs of these types:
    SMD_DCTE_0 and SMD_DCTE_1 4 (the storage module disk), CTAPE_DCTE 5
    (the cartridge tape).  IO_$GET_CONFIG's CHK arguments on the SAUs
    with them. }
  io_ctype_smd = 4;
  io_ctype_ctape = 5;

  { And after the SAU9 map's: ETH_DCTE_0 and ETH_DCTE_1 6 (the
    Ethernet), RING_8025_DCTE_0 and RING_8025_DCTE_1 8 (the 802.5 ring);
    SCSI9_DCTE, TIMER_DCTE and the SIO DCTEs 16#FFFF, no controller
    type.  The display's 7 is mono9/mono9.ins.pas's mono9_$dcte_ctype. }
  io_ctype_ethernet = 6;
  io_ctype_ring_8025 = 8;
  io_ctype_none = 16#FFFF;

  { The last index of DEV_DCTES, the static DCTEs' list (io/dctes.pas):
    its static DCTEs, then the nil that ends it.  The SAU2's list has
    three (WIN_DCTE, FLP_DCTE, RING_DCTE), the SAU5's five (WIN_DCTE,
    RING_DCTE, SMD_DCTE_0, SMD_DCTE_1, CTAPE_DCTE), the SAU4's five
    (WIN_DCTE, FLP_DCTE, RING_DCTE, SMD_DCTE_0, SMD_DCTE_1), the SAU3's
    three (RING_DCTE, SMD_DCTE_0, SMD_DCTE_1: no Winchester), the SAU9's
    28 (its kind-2 DCTEs, `named_dctes'), the SAU8's 17 (its nine, with
    the floppy's, and the display drivers' eight).  Only these six lists
    are written (TODO(sau) in io/dctes.pas). }
%if named_dctes %then
%if floppy_disk %then
  io_$dev_dctes_last = 17;
%else
  io_$dev_dctes_last = 28;
%endif
%elseif smd_disk %then
%if winchester_config %then
  io_$dev_dctes_last = 5;
%else
  io_$dev_dctes_last = 3;
%endif
%else
  io_$dev_dctes_last = 3;
%endif

var
  { IO_$DCTE_LIST (map symbol, in WIRED_DATA): the list's head.
    SYSBUS_$INIT reads it by its absolute address: another unit's
    variable. }
  io_$dcte_list: extern dcte_ptr_t;

  { HISTOGRAM_ADDRESS (map symbol, the SAU9 map's own 4-byte IO_$TBLS
    data segment): the interrupted program counter the hand-written
    first-level interrupt handler of IO_$TBLS stores for the PC
    histogram (SIO16550_$INT passes it to PCHIST_$INTERRUPT). }
  histogram_address: extern integer32;

{ IO_$TRAP (hand-written, in the IO_$TBLS data segment, PAGE_INIT;
  its transcription in io/m68k/): reads its arguments off the stack, the vector and the
  handler.  Its compiled callers push the pad, the handler's address as
  a longword and the vector as a word (SYSBUS_$INIT).  Both by value:
  `val_param'.  The handler is a routine's address, univ_ptr (`addr' of
  a routine, ref 4, "Addr"). }
procedure io_$trap(m68k_vector_num: integer; handler_addr: univ_ptr);
  options(extern, val_param);

{ ---- IO_'s own declarations ---- }

type
  { A bus's routine, the first longword of a bus entry-point vector:
    IO_$INIT calls each non-nil one with nothing pushed. }
  io_$bus_proc_t = ^procedure;

  { ---- The unit routines' types.  The evidence is the SAU2 image and,
    for names, the bus vectors of the other SR10.2 SAUs. ---- }

const
  { The bus numbers, the index of IO_$BUS_EPV (a request's and a unit
    slot's bus word).  IO_$ACQUIRE's nested int_ids_match switches on it:
    labels 1..4.  The names follow the bus modules whose routines fill
    the entries in the SR10.2 images (the IO_$BUS_EPV cells read off
    each image and named from its map): entry 1 VME_ (SAU5, SAU6: VME_
    at +0, VME_$DEFINE_USERINT at +0xC), entry 2 MBUS_ (SAU3..SAU6),
    entry 3 ATBUS_ (SAU7..SAU9), entry 4 SYSBUS_(SAU2, SAU3, SAU4, SAU6,
    SAU9).  Entry 0 is never filled. }
  io_$bus_vme = 1;
  io_$bus_mbus = 2;
  io_$bus_atbus = 3;
  io_$bus_sysbus = 4;

  { The highest unit number: io_$check_unit's bound and IO_$ACQUIRE's
    free-slot loop count. }
  io_$max_unit = 31;

type
  { A unit number, 0..31: the index of IO_$DCTES.  io_$check_unit tests
    it with one unsigned word compare: `in_range' of a subrange from 0
    stored in a word (the form of sio/k_set_param.pas). }
  io_$unit_num_t = 0..io_$max_unit;

  { An interrupt id, 4 bytes passed by value: IO_$ACQUIRE pushes a
    request's, IO_$RELEASE and the others a unit slot's.  The nested
    int_ids_match compares the first words of two: a record whose first
    word is the id proper.  On the SAU9 SYSBUS_$DEFINE_INT reads that
    word as a vector number (0xA0..0xAF), which names the field.  The
    SAU5's bus routines compare it unsigned (MBUS_$DEFINE_INT against 15,
    VME_$DEFINE_INT): a pinteger (int_ids_match's equality is the same
    either way).  The second word is read by nothing on the SAU2. }
  io_$int_id_t = record
    vector: pinteger;                     { 0x00 }
    unused_02: integer;                   { 0x02 }
  end;

  { A unit's interrupt, 8 bytes: copied whole by IO_$ACQUIRE (an 8-byte
    record assignment); its byte at 4 tested as a boolean and and-ed
    with a slot's.  The 3 bytes after the boolean are read by nothing;
    they make the record's 8 bytes. }
  io_$int_info_t = record
    id: io_$int_id_t;                     { 0x00 }
    has_int: boolean;                     { 0x04 }
    unused_05: char;                      { 0x05 }
    unused_06: integer;                   { 0x06 }
  end;

  { A unit's CSR pages, 12 bytes, copied whole by IO_$ACQUIRE.  va, the
    pages' virtual address (IO_$MAP_CSR passes it to MMU_$INSTALL and
    MMU_$CACHE_INHIBIT_VA and steps it by 0x400); pa, the bus address of
    the first (the argument of the bus's xlate_iova; compared unsigned:
    a `linteger'); pages, a word, the `for' count of IO_$MAP_CSR and
    IO_$UNMAP_CSR, widened signed; has_csr, a boolean.  The last byte is
    read by nothing. }
  io_$csr_info_t = record
    va: integer32;                        { 0x00 }
    pa: linteger;                         { 0x04 }
    pages: integer;                       { 0x08 }
    has_csr: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;

  { A unit's attributes, a word: IO_$ACQUIRE copies the request's into
    the slot, IO_$ATTR_CNTL returns the slot's and replaces them, and
    IO_$ALLOC_MAP tests member io_$attr_wide_iomap (a bit test on the
    word's low byte: a set of 16). }
  io_$attr_t = set of 0..15;

const
  { The member IO_$ALLOC_MAP tests: with it, the unit's map space
    reaches 16#100000 (1 MB), without it 16#10000 (64 KB). }
  io_$attr_wide_iomap = 1;

type
  { An I/O map region a unit holds (the SAUs with the PBU): a node of
    the unit slot's list, 0x10 bytes, taken from the block's free list
    by io_$add_region and returned by io_$remove_region.  next, the list
    link (the free list's too); start and stop, the region's bus
    addresses (IO_$ALLOC_MAP's start and start + length); page, the
    start's page number (start div 1024, a word).  The last word is read
    by nothing. }
  io_$region_ptr_t = ^io_$region_t;
  io_$region_t = record
    next: io_$region_ptr_t;               { 0x00 }
    start: linteger;                      { 0x04 }
    stop: linteger;                       { 0x08 }
    page: integer;                        { 0x0C }
    unused_0e: integer;                   { 0x0E }
  end;

  { What IO_$ACQUIRE is given, by address, and IO_$MAP_CSR and
    IO_$UNMAP_CSR: int at 4 and csr at 0xC (above); tag, a word stored
    into the new slot's tag, whose being nonzero marks the unit acquired
    (io_$check_unit); bus, the bus number (the IO_$BUS_EPV index);
    attrs, stored into the slot's attrs.  The longword at 0 is read by
    nothing on the SAU2, and nothing shows the record's size past 0x1E. }
  io_$acquire_rec_t = record
    unused_00: integer32;                 { 0x00 }
    int: io_$int_info_t;                  { 0x04 }
    csr: io_$csr_info_t;                  { 0x0C }
    tag: integer;                         { 0x18 }
    bus: integer;                         { 0x1A }
    attrs: io_$attr_t;                    { 0x1C }
  end;

  { A unit slot of IO_$DCTES, 0x20 bytes, at IO_$DCTES + 0x20 * unit:
    IO_$ACQUIRE fills it from the request: int at 0, csr at 8, tag at
    0x14 (zero = free; IO_$RELEASE clears it), bus at 0x16, the
    acquiring process at 0x18 (PROC1_$CURRENT, a pinteger), attrs at
    0x1A, and the list of the unit's I/O map regions at 0x1C cleared (on
    the SAUs with the PBU, IO_$ALLOC_MAP adds to it, IO_$FREE_MAP and
    IO_$FREE_MAP_REGION take from it, and IO_$RELEASE frees what is
    left). }
  io_$unit_entry_t = record
    int: io_$int_info_t;                  { 0x00 }
    csr: io_$csr_info_t;                  { 0x08 }
    tag: integer;                         { 0x14 }
    bus: integer;                         { 0x16 }
    owner: pinteger;                      { 0x18 }
    attrs: io_$attr_t;                    { 0x1A }
    regions: io_$region_ptr_t;            { 0x1C }
  end;

  { A bus's routines, called through its vector (all by value: the
    pointer types are `val_param').  The names are those the other SAUs'
    maps give the routines in the vector's cells (SAU9:
    ATBUS_$XLATE_IOVA at +4, ATBUS_$DEFINE_INT at +0xC,
    ATBUS_$ENABLE_DEVICE +0x10, ATBUS_$DISABLE_DEVICE +0x14,
    ATBUS_$DEVICE_INTERRUPTING +0x18, ATBUS_$CLEAR_PENDING +0x1C; the
    SYSBUS_ entry likewise).
    - xlate_iova: one longword, a bus address (IO_$MAP_CSR's or
      IO_$XLATE_IOVA's); the result in D0, a page number given to
      MMU_$INSTALL.  The SAU9 ATBUS_$XLATE_IOVA compares its argument
      unsigned and returns it shifted right by 10: a linteger, an
      integer32 result.
    - define_int: the id and two longwords (IO_$ACQUIRE), or the id and
      two zeros (IO_$RELEASE): pointers, `nil' in the second.  The SAU9
      SYSBUS_$DEFINE_INT stores the first as the vector's handler
      (installing SYSBUS_$UNDEF_INT for nil) and the second beside it:
      the handler and its argument.
    - enable_device, disable_device, clear_pending: the id.
    - device_interrupting: the id; its D0 is IO_$DEVICE_INTERRUPTING's
      result: a boolean function, as the routine's name says. }
  io_$bus_xlate_t = ^function(bus_addr: linteger): integer32;
    options(val_param);
  io_$bus_define_int_t = ^procedure(id: io_$int_id_t;
                                    handler: univ_ptr;
                                    handler_arg: univ_ptr);
    options(val_param);
  io_$bus_int_proc_t = ^procedure(id: io_$int_id_t); options(val_param);
  io_$bus_int_func_t = ^function(id: io_$int_id_t): boolean;
    options(val_param);

  { A bus entry-point vector, 0x24 bytes: init at 0 (above, IO_$INIT's);
    the six routines above at 4, 0xC, 0x10, 0x14, 0x18, 0x1C, read by
    IO_$MAP_CSR, IO_$ACQUIRE, IO_$ENABLE_DEVICE, IO_$DISABLE_DEVICE,
    IO_$DEVICE_INTERRUPTING and IO_$CLEAR_PENDING; csr_align at 0x20, a
    word widened, the request's pa tested against it less 1
    (IO_$ACQUIRE): the CSR alignment (0x400 for entry 1, 8 for 2..4).
    The longword at 8 is read by nothing and never filled (on any SR10.2
    SAU), and the word at 0x22 is read by nothing.  IO_$INIT steps the
    five entries by 0x24. }
  io_$bus_epv_t = record
    init: io_$bus_proc_t;                 { 0x00 }
    xlate_iova: io_$bus_xlate_t;          { 0x04 }
    unused_08: univ_ptr;                  { 0x08 }
    define_int: io_$bus_define_int_t;     { 0x0C }
    enable_device: io_$bus_int_proc_t;    { 0x10 }
    disable_device: io_$bus_int_proc_t;   { 0x14 }
    device_interrupting: io_$bus_int_func_t;
                                          { 0x18 }
    clear_pending: io_$bus_int_proc_t;    { 0x1C }
    csr_align: integer;                   { 0x20 }
    unused_22: integer;                   { 0x22 }
  end;

  { An exclusion lock as ML_$EXCLUSION_INIT sets it (0x12 bytes) is
    ml/ml.ins.pas's ml_$exclusion_t. }

  { The configuration words IO_$GET_CONFIG returns: each cleared, and
    members set in its low byte: a set of 16 (ref 3.9.3; a constant
    member's union is a bit set on its byte). }
  io_$config_t = set of 0..15;

var
  { IO_$BUS_EPV (map symbol, IO_ +0x60 on the SAU2, +0xF0 on the SAU5,
    after the I/O maps): five bus vectors, from 0.  Defined in
    io/io.pas, with its image bytes. }
  io_$bus_epv: extern array[0..4] of io_$bus_epv_t;

  { IO_$WIRING_EXCLUSION (map symbol, IO_ +0x530 on the SAU2, +0x5D8 on
    the SAU5): IO_$INIT initializes it with ML_$EXCLUSION_INIT.  Defined
    in io/io.pas. }
  io_$wiring_exclusion: extern ml_$exclusion_t;

  { IO_$IN_INIT (map symbol, IO_ +0x552 on the SAU2, +0x682 on the
    SAU5): IO_$INIT sets it to true and clears it: boolean.  Defined in
    io/io.pas. }
  io_$in_init: extern boolean;

  { IO_$DCTES (map symbol, IO_ +0x118 on the SAU2, +0x1A8 on the SAU5,
    0x400 bytes to IO_'s exclusion lock): despite its name, the unit
    table of IO_$ACQUIRE .. IO_$FREE_MAP_REGION, 32 slots of 0x20
    (io_$unit_entry_t above), from 0 (IO_$ACQUIRE's first unit is 0).
    Zero in the image.  Defined in io/io.pas. }
  io_$dctes: extern array[io_$unit_num_t] of io_$unit_entry_t;

%if pbu_driver %then
  { PBU_$EXCLUSION_LOCK (map symbol, in IO_'s data on the SAUs with the
    PBU, between IO_'s own exclusion lock and IO_$WIRING_EXCLUSION:
    +0x5C0 on the SAU5): an exclusion lock, ML_$EXCLUSION_INIT's 0x12
    bytes; the SAU5 PBU_$INIT initializes it when its argument is true.
    Defined in io/io.pas. }
  pbu_$exclusion_lock: extern ml_$exclusion_t;
%endif

  { DEV_DCTES (map symbol, in the DCTES data segment after the static
    DCTEs; another unit's data): the static DCTEs' addresses, ended by
    nil, indexed from 0 (io_$build_dcte_list).  Its bound,
    io_$dev_dctes_last, is io/dctes.pas's. }
  dev_dctes: extern array[0..io_$dev_dctes_last] of dcte_ptr_t;

  { DCTE_START and DCTE_END (map markers, both size 0, at one address):
    the dynamic DCTE area, empty on the SAU2 and the SAU5.  IO_'s block
    holds their addresses (io/io.pas).  Extern chars, of which only the
    address is used. }
  dcte_start: extern char;
  dcte_end: extern char;

{ IO_ routine headings, in map order: CHK, IO_$GET_DCTE and IO_$ACQUIRE
  .. IO_$ALLOC (WIRED_PROC), IO_$INIT (OS_INIT_PROC), IO_$GET_CONFIG
  (PROCEDURE$). }

{ CHK - is a controller of a type configured, with a good status. }
function chk(in ctype: pinteger): boolean; extern;

{ IO_$GET_DCTE - find the DCTE of a controller type and number. }
function io_$get_dcte(in ctype: integer; in cnum: integer;
                      out status: status_$t): dcte_ptr_t;
  extern;

{ ---- IO_$ACQUIRE .. IO_$ALLOC.  No compiled caller: Ghidra finds none
  for any of the ten, a byte search of the image for each address finds
  no cell, and the SVC tables (svc/m68k/svc_tables.s) do not name them.
  On the SAU2 nothing calls them (its PBU module is an 0x18-byte stub).
  On the SAU3 (the same IO_ module) the user-device manager does:
  PBU_$SETUP calls IO_$ACQUIRE with a record, two longwords, a word's
  address and a status address; PBU_$SETDOWN calls IO_$RELEASE with a
  word and a status address; PBU_$ALLOC calls IO_$ALLOC.  These agree
  with the SAU2 bodies' slots below, which decide the headings.
  Every routine but IO_$MAP_CSR and IO_$UNMAP_CSR takes a word by value
  first and its next slot 2 bytes on, so `val_param'; the two with only
  addresses are given it too (the code is the same under the default
  convention).  The unit is passed on by value to io_$check_unit and the
  status's address with it: `out', as io_$check_unit's (it writes the
  status first). ---- }

{ IO_$ACQUIRE - acquire a unit for a device: a free slot of the unit
  table, checked against the units already acquired on the same bus. }
procedure io_$acquire(in req: io_$acquire_rec_t; handler: univ_ptr;
                      handler_arg: univ_ptr; out unit: io_$unit_num_t;
                      out status: status_$t);
  options(extern, val_param);

{ IO_$RELEASE - release an acquired unit. }
procedure io_$release(unit: io_$unit_num_t; out status: status_$t);
  options(extern, val_param);

{ IO_$DEVICE_INTERRUPTING - ask a unit's bus whether its device is
  interrupting. }
function io_$device_interrupting(unit: io_$unit_num_t;
                                 out status: status_$t): boolean;
  options(extern, val_param);

{ IO_$CLEAR_PENDING - clear a unit's pending interrupt through its bus. }
procedure io_$clear_pending(unit: io_$unit_num_t; out status: status_$t);
  options(extern, val_param);

{ IO_$DISABLE_DEVICE - disable a unit's device through its bus. }
procedure io_$disable_device(unit: io_$unit_num_t; out status: status_$t);
  options(extern, val_param);

{ IO_$ENABLE_DEVICE - enable a unit's device through its bus. }
procedure io_$enable_device(unit: io_$unit_num_t; out status: status_$t);
  options(extern, val_param);

{ IO_$MAP_CSR - map a unit's CSR pages into the kernel's address space. }
procedure io_$map_csr(in req: io_$acquire_rec_t; out status: status_$t);
  options(extern, val_param);

{ IO_$UNMAP_CSR - unmap a unit's CSR pages. }
procedure io_$unmap_csr(in req: io_$acquire_rec_t; out status: status_$t);
  options(extern, val_param);

{ IO_$XLATE_IOVA - translate a bus address through a unit's bus. }
function io_$xlate_iova(unit: io_$unit_num_t; iova: linteger;
                        out status: status_$t): integer32;
  options(extern, val_param);

{ IO_$ALLOC - allocate I/O map space for a unit. }
function io_$alloc(unit: io_$unit_num_t; length: integer32;
                   fixed: boolean; iova: linteger;
                   out status: status_$t): integer32;
  options(extern, val_param);

%if pbu_driver %then
{ ---- The rest of the I/O map routines, on the SAUs with the PBU
  (`pbu_driver'; the maps' IO_ WIRED_PROC segments of SAU3..SAU8 name
  them, IO_$ATTR_CNTL before IO_$ALLOC, IO_$FREE, IO_$ALLOC_MAP,
  IO_$FREE_MAP and IO_$FREE_MAP_REGION after it).  `val_param', as the
  others: each takes the unit, a word by value, first, and its next
  slot 2 bytes on. ---- }

{ IO_$ATTR_CNTL - set an acquired unit's attributes, returning the old. }
procedure io_$attr_cntl(unit: io_$unit_num_t; new_attrs: io_$attr_t;
                        out old_attrs: io_$attr_t;
                        out status: status_$t);
  options(extern, val_param);

{ IO_$FREE - free I/O map space allocated for a unit. }
procedure io_$free(unit: io_$unit_num_t; iova: linteger;
                   out status: status_$t);
  options(extern, val_param);

{ IO_$ALLOC_MAP - allocate I/O map space for a unit and record it. }
function io_$alloc_map(unit: io_$unit_num_t; length: integer32;
                       fixed: boolean; iova: linteger;
                       out status: status_$t): integer32;
  options(extern, val_param);

{ IO_$FREE_MAP - free all the I/O map space recorded for a unit. }
procedure io_$free_map(unit: io_$unit_num_t; out status: status_$t);
  options(extern, val_param);

{ IO_$FREE_MAP_REGION - free one I/O map region recorded for a unit. }
procedure io_$free_map_region(unit: io_$unit_num_t; iova: linteger;
                              out status: status_$t);
  options(extern, val_param);
%endif

{ TESTPAGE: touches a device location with a bus-error handler in place
  and reports whether the access completed.  Hand-written: it reads its
  three arguments off the stack as addresses (the probe kind, 0..3: read
  or write, byte or word; the location, through a pointer; the data read
  or written), and leaves a boolean in D0.  FLP_$CINIT pushes three
  addresses (a frame buffer, the DCTE's disk_dinit field, a constant
  word cell 0) and tests the byte: the default convention, a boolean
  function.  The map's name (the binder's symbol); the parameter names
  avoid addr, a predeclared function.  kind and location `in'; data
  `var' (read by the write kinds, written by the read kinds), `univ'. }
function testpage(in kind: integer; in location: univ_ptr;
                  var data: univ char): boolean;
  extern;

{ IO_$INIT - initialize the I/O manager and every controller. }
procedure io_$init(in param1: integer32; in verbose: boolean;
                   out status: status_$t);
  extern;

%if prom_config_record %then
{ IO_$LOG_SELF_TESTS (map symbol, OS_INIT_PROC): log the controllers'
  self-test results the PROM's configuration record points at.  The
  record's address in a longword, by address (OS_$INIT passes its
  cfg_ptr, as to IO_$INIT), read only; the status cleared first. }
procedure io_$log_self_tests(in cfg_ptr: integer32; out status: status_$t);
  extern;

%endif
{ IO_$GET_CONFIG - report which optional controllers are configured. }
procedure io_$get_config(out config1: io_$config_t; out config2: io_$config_t;
                         out config3: io_$config_t; out config4: io_$config_t);
  extern;

{ ---- (RING addition) the type of a controller's interrupt routine.
  Nothing above is changed. ---- }

type
  { A controller's interrupt routine, the DCTE's disk_do_io as the
    first-level interrupt routines call it: RING_INTERRUPT pushes the
    controller's DCTE address and calls through ATBUS_'s copy
    (ring/interrupt.pas), DISK_INTERRUPT the same for its two
    controllers.  RING_DCTE's disk_do_io is RING_$INT, a boolean function
    whose result RING_INTERRUPT does not read: the routine type is a
    procedure's.  One address, the default convention. }
  io_$do_io_t = ^procedure(var dcte: dcte_t);

{ ---- Other modules' routines and data that IO_ and DCTES use on the
  SAUs with those modules, declared here for the SAU5 translation. ---- }

{ Other modules' routines IO_ and DCTES name: CT_$CINIT and CT_$INT are
  declared here (they take dcte_t, and only the DCTES block names them);
  PBU_$INIT and PBU_$MCB are pbu/pbu.ins.pas's, MT_$PRESENT is
  mt/mt.ins.pas's, the VME_ and MBUS_ headings IO_$BUS_EPV names are
  vme/vme.ins.pas's and mbus/mbus.ins.pas's (io/io.pas includes them
  all); the SM_ and SM_C_ ones the DCTES block names are sm/sm.ins.pas's
  and sm_c/sm_c.ins.pas's, which io/dctes.pas includes. }

%if ct_driver %then
{ CT_$CINIT and CT_$INT: CTAPE_DCTE's csrsytr and disk_do_io
  (io/dctes.pas).  CT_$CINIT reads the DCTE through the slot and returns
  0 in D0 (WIN_$CINIT's form, win/win.ins.pas); CT_$INT, called as the
  DCTE's interrupt routine with the DCTE by address, leaves 0xFF in D0
  (WIN_$INT's form).  CT_$INT is the QIC-02 driver's (`ct_qic02'); the
  SCSI tape driver's CT_$CINIT is the SCSI_CTAPE_DCTEs' csrsytr. }
function ct_$cinit(var dcte: dcte_t): integer32; extern;
%if ct_qic02 %then
function ct_$int(in dcte: dcte_t): boolean; extern;
%endif
%endif

%if scsi_driver %then
{ SCSI_$INIT (scsi/init.pas): SCSI9_DCTE's csrsytr; it sets up the
  DCTE's bus and returns 0 in D0.  SCSI_$EXCLUSION_LOCK (map symbol, in
  IO_'s data block on the SAU9): the SCSI driver's exclusion lock, which
  SCSI_$INIT initializes. }
function scsi_$init(var dcte: dcte_t): integer32; extern;
var
  scsi_$exclusion_lock: extern ml_$exclusion_t;
%endif

