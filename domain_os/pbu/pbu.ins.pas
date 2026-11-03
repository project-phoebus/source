{ pbu/pbu.ins.pas - PBU_ (the processor bus units) constants, types,
  variables and routine headings, for the Domain Pascal tree.

  Two map modules hold PBU's routines on every SAU: PBU (pbu/pbu.pas)
  and EC2_PBU (pbu/ec2_pbu.pas).  On the SAUs with the PBU driver
  (`pbu_driver', base/config.ins.pas) the PBU module is the user-device
  manager, with the hand-written PBU_ASM data (pbu/sau5/pbu_asm.s) and
  the PBU_MAP module beside it.

  No customer insert file declares these.  Include base/base.ins.pas
  and ec/ec.ins.pas before it.
}

const
  { 16#001E000A, "pbu not present" (stcode.db.10.2); PBU_$FAULTED_UNITS
    stores it. }
  status_$pbu_not_present = 16#001E000A;

  { The eventcount numbers of the PBU pool: PBU_$ADVANCE_EC_INT's range,
    compared unsigned. }
  pbu_ec_index_min = 16#101;
  pbu_ec_index_max = 16#120;

type
  { One PBU eventcount record, 0x18 bytes: the eventcount at 0, the owner
    word at 0xC.  With the driver, PBU_$ALLOCATE_EC and PBU_$RELEASE_EC
    keep the records a unit holds on a list through next and prev, whose
    head is in the unit's stack area (pbu_$stack_area_t). }
  pbu_$ec_entry_ptr_t = ^pbu_$ec_entry_t;
  pbu_$ec_entry_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    owner_id: integer;                    { 0x0C }
    reserved1: integer;                   { 0x0E }
    next: pbu_$ec_entry_ptr_t;            { 0x10 }
    prev: pbu_$ec_entry_ptr_t;            { 0x14 }
  end;

var
  { EC2_$PBU_ECS (map symbol, the first of the EC2_PBU data segment,
    PBU_WIRED_DATA): 32 records of 0x18 bytes, from 0, for the
    eventcount numbers 16#101 on.  Defined in pbu/ec2_pbu.pas. }
  ec2_$pbu_ecs: extern array[0..31] of pbu_$ec_entry_t;

  { PBU_$DATA_END (map symbol): one past EC2_$PBU_ECS, a marker, the end
    of PBU_$WIRE_PBU's wired range. }
  pbu_$data_end: extern char;

%if pbu_driver %then
{ ---- The user-device manager (`pbu_driver'). ---- }

const
  { The PBU statuses the manager stores, subsystem 16#1E, with the texts
    of the SR10.2 status-code database.  The I/O map statuses of the
    family (16#1E0010, 16#1E0014, 16#1E0015, 16#1E0032) are
    io/io.ins.pas's. }
  status_$pbu_invalid_csr_page_address = 16#001E0004;
                                        { "invalid csr page address in
                                          ddf" }
  status_$pbu_invalid_unit_number = 16#001E000C;  { "invalid unit number" }
  status_$pbu_unit_in_use = 16#001E000D;          { "unit in use" }
  status_$pbu_unit_not_acquired = 16#001E000E;    { "unit not acquired" }
  status_$pbu_unit_already_acquired = 16#001E000F;
                                        { "unit already acquired" }
  status_$pbu_iomap_already_allocated = 16#001E0013;
                                        { "iomap already allocated" }
  status_$pbu_buffer_too_large = 16#001E0016;     { "buffer too large" }
  status_$pbu_buffer_page_not_wired = 16#001E0017;
                                        { "buffer page not wired" }
  status_$pbu_buffer_not_mapped = 16#001E0018;    { "buffer not mapped" }
  status_$pbu_page_not_wired = 16#001E001B;       { "page not wired" }
  status_$pbu_csr_bus_timeout = 16#001E001C;
                                        { "reference to csr page caused
                                          bus timeout" }
  status_$pbu_protection_violation = 16#001E0020;
                                        { "protection violation" }
  status_$pbu_too_many_wired_pages = 16#001E0023;
                                        { "too many wired pages" }
  status_$pbu_csr_not_in_csr_page = 16#001E0024;
                                        { "csr not in device's csr page" }
  status_$pbu_controller_already_mapped = 16#001E0025;
                                        { "controller already mapped" }
  status_$pbu_bad_controller_memory_length = 16#001E0026;
                                        { "bad controller memory length" }
  status_$pbu_bad_buffer_address = 16#001E0027;   { "bad buffer address" }
  status_$pbu_all_units_in_use = 16#001E002D;     { "all pbu units in use" }
  status_$pbu_wrong_pbulib_version = 16#001E002E;
                                        { "wrong version of /lib/pbulib
                                          in use" }
  status_$pbu_vme_only = 16#001E0030;   { "operation valid only for VME
                                          device" }
  status_$pbu_address_list_too_small = 16#001E0031;
                                        { "physical address list too
                                          small" }
  status_$pbu_global_device = 16#001E003A;
                                        { "unit already in use as a
                                          global device" }
  status_$pbu_unit_is_public = 16#001E003B;
                                        { "unit is publicly owned" }
%if pbu_atbus_units %then
  status_$pbu_illegal_dma_channel = 16#001E0033;
                                        { "illegal dma channel number" }
  status_$pbu_bad_dma_direction = 16#001E0034;
                                        { "bad dma direction specified" }
  status_$pbu_dma_channel_in_use = 16#001E0035;
                                        { "requested dma channel in use" }
  status_$pbu_dma_channel_not_in_use = 16#001E0036;
                                        { "requested dma channel not in
                                          use" }
  status_$pbu_dma_not_at_end = 16#001E0037;
                                        { "dma channel not at end of
                                          range" }
  status_$pbu_buffer_not_contiguous = 16#001E003C;
                                        { "buffer pages not physically
                                          contiguous" }
  status_$pbu_contiguous_not_aligned = 16#001E003D;
                                        { "contiguous buffer not page
                                          aligned" }
%endif

  { The PBU units, 0..15 (0..7 with `pbu_8_units'): the index of
    PBU_$DCTES.  With the VME bus (`vme_bus') the units 0..7 are the
    Multibus's, 8..15 the VME bus's (PBU_$SETUP, PBU_$SETDOWN). }
%if pbu_8_units %then
  pbu_$max_unit = 7;
%else
  pbu_$max_unit = 15;
%endif
  pbu_first_vme_unit = 8;

  { A free DCTE's unit (PBU_$SETDOWN's mark): one past the last unit. }
  pbu_free_unit = pbu_$max_unit + 1;

  { The last of PBU_$DCTE_TABLE's DCTEs: 16 in PBU_ASM with the AT bus's
    units (`pbu_atbus_units'), 8 otherwise. }
%if pbu_atbus_units %then
  pbu_dcte_table_last = 15;
%else
  pbu_dcte_table_last = 7;
%endif

  { The last of a DDF's handlers: a DDF has 16 on every SAU, whatever
    its number of units (PBU_$ACQUIRE_INT fills them all). }
  pbu_ddf_last_handler = 15;

  { The DDF version PBU_$SETUP accepts (a DDF's +0x0E, "ddf has wrong
    version"), and the value of its first argument, the library's
    version ("wrong version of /lib/pbulib in use"). }
  pbu_ddf_version = 7;
  pbu_lib_version = -1;

  { A DDF handler's value for a unit the DDF does not set up. }
  pbu_no_handler = -1;

  { The DCTE's sharing word (+0x50) of a publicly owned unit: such a
    unit may be used by any process ("unit is publicly owned"). }
  pbu_public = 2;

  { PBU_$GET_PTR's selector: which of a unit's addresses it returns. }
  pbu_ptr_stack = 0;                    { the user stack area }
  pbu_ptr_assoc = 1;                    { the associated controller memory }
  pbu_ptr_csr = 2;                      { the CSR pages }
  pbu_ptr_diag = 3;                     { past the CSR pages }
  pbu_ptr_dcte = 4;                     { the DCTE itself }

  { A unit's CSR pages as PBU_$SETUP checks them: the pages' size (the
    CSR address's alignment, and with csr_pages their extent).  On the
    AT bus (`pbu_atbus_units') a CSR page is a group of 8 of the bus's
    I/O ports, 16#100..16#3FF, each group mapped at a page of its own
    from pbu_atbus_io_ppn on. }
%if pbu_atbus_units %then
  pbu_csr_page_size = 8;
  pbu_atbus_csr_first = 16#100;
  pbu_atbus_csr_end = 16#400;
  pbu_atbus_io_ppn = 16#100;

  { The unit PBU_$SHUTDOWN leaves set up. }
  pbu_shutdown_kept_unit = 3;
%else
  pbu_csr_page_size = 1024;
%endif

  { PBU_$GET_INFO's second and third words. }
%if pbu_atbus_units %then
  pbu_info_2 = 8;
%elseif mbus_map_64k %then
  pbu_info_2 = 1;
%else
  pbu_info_2 = 2;
%endif
%if not io_regions %then
  pbu_info_3 = 0;
%elseif pbu_atbus_units %then
  pbu_info_3 = 2;
%else
  pbu_info_3 = 1;
%endif

  { The SM_ controller's PBU unit, which PBU_$SETUP leaves out of
    PBU_$WIRE_PBU and PBU_$FREE_ASID out of its sweep while its DCTE
    exists (sm/sm.ins.pas's sm_pbu_unit). }
  pbu_sm_unit = 4;

  { The PBU page's wired pages: PBU_$WIRE_PBU's page list's length. }
  pbu_max_wired_pages = 21;

  { The first and last elements of PBU_$PPN_OWNERS: the map's PBU_TABLES
    segment is 0x1C00 bytes on the SAU5, a word per physical page from
    16#200, and 0xE00 bytes on the SAU3, a byte per page
    (`pbu_8_units'); 0x4000 bytes on the SAU8, a word per page from
    16#400 (`mmap_ppns_400'); 0x3E00 bytes on the SAU4, a byte per
    page from 16#200 to 16#3FFF (`mmap_ppns_200_3fff').
    TODO(sau) the SAU7's PBU_TABLES size differs (0x18000); a part's
    constant when it is translated. }
%if mmap_ppns_400 %then
  pbu_ppn_owners_first = 16#400;
  pbu_ppn_owners_last = 16#23FF;
%elseif mmap_ppns_200_3fff %then
  pbu_ppn_owners_first = 16#200;
  pbu_ppn_owners_last = 16#3FFF;
%else
  pbu_ppn_owners_first = 16#200;
  pbu_ppn_owners_last = 16#FFF;
%endif

type
  pbu_$byte_t = [byte] 0..255;

  { A set of PBU units, a word (a byte as an element of
    PBU_$PPN_OWNERS' packed array with `pbu_8_units'): PBU_$PPN_OWNERS'
    entries and PBU_$FAULTED_UNITS' answer. }
  pbu_$unit_set_t = set of 0..pbu_$max_unit;

  { A DDF (device descriptor file) as PBU_$SETUP is given it, 0x80 bytes
    (the library maps the unit's DDF and passes its address;
    PBU_$ACQUIRE_INT builds one in its frame).  version and flags are one
    word (a byte at an odd offset of an unpacked record would take its
    own word): flags.wide_iomap asks for IO_$ACQUIRE's wide map,
    kernel_driver for a handler called in the kernel (no user stack, no
    cleanup handler), any_address lifts the CSR and controller address
    checks, global makes the unit usable by every process.  csr_pa is
    16#FFFFFFFF for a unit with no CSR pages.  handlers: one per unit
    number, 16#FFFFFFFF for a unit the DDF does not set up
    (pbu_no_handler), 16 on every SAU. }

  pbu_$ddf_flags_t = packed record
    version: 0..255;                      { bits 15..8: 0x0E }
    wide_iomap: boolean;                  { bit 7 }
    kernel_driver: boolean;               { bit 6 }
    any_address: boolean;                 { bit 5 }
    global: boolean;                      { bit 4 }
    unused_3_0: 0..15;                    { bits 3..0 }
  end;

  pbu_$ddf_t = record
    unused_00: array[1..3] of integer32;  { 0x00 }
    unit: pinteger;                       { 0x0C }
    flags: pbu_$ddf_flags_t;              { 0x0E }
    handler_arg: univ_ptr;                { 0x10 }
    unused_14: integer;                   { 0x14 }
    csr_pages: integer;                   { 0x16 }
    csr_va: linteger;                     { 0x18 }
    csr_pa: integer32;                    { 0x1C }
    unused_20: array[1..7] of integer32;  { 0x20 }
    stack: univ_ptr;                      { 0x3C }
    handlers: array[0..pbu_ddf_last_handler] of univ_ptr;  { 0x40 }
  end;
  pbu_$ddf_ptr_t = ^pbu_$ddf_t;

  { The bytes at a DCTE's +0x10: the IO_ unit IO_$ACQUIRE gave the unit
    (bits 15..11), the bus (bits 10..8), and the address space the unit
    last ran for (pbu_check_unit's current one). }
  pbu_$dcte_unit_t = packed record
    io_unit: 0..31;                       { bits 15..11: 0x10 }
    bus: 0..7;                            { bits 10..8 }
    cur_asid: 0..255;                     { bits 7..0: 0x11 }
  end;

  { The DCTE's flags word, +0x12.  int_pending, set by PBU_$INT_COM when
    the device routine asks for the eventcount, cleared by PBU_$WAIT;
    wired, set by PBU_$SETUP; map_allocated by PBU2_$ALLOCATE_MAP;
    kernel_driver, any_address and global are the DDF's; faulted, set by
    PBU_$GET_DIAG_PTR, read by PBU_$FAULTED_UNITS; dma_bus, set for the
    buses 2 and 3.  cleared_8_7 and cleared_0 PBU_$SETUP clears, and
    nothing in the PBU or PBU_MAP reads; with the AT bus's units
    (`pbu_atbus_units') bit 8 is attr_set, set by PBU_$DMA_START when it
    gives the unit attribute 0 (IO_$ATTR_CNTL). }
  pbu_$dcte_flags_t = packed record
    int_pending: boolean;                 { bit 15 }
    unused_14: boolean;                   { bit 14 }
    active: boolean;                      { bit 13 }
    map_allocated: boolean;               { bit 12 }
    kernel_driver: boolean;               { bit 11 }
    any_address: boolean;                 { bit 10 }
    global: boolean;                      { bit 9 }
%if pbu_atbus_units %then
    attr_set: boolean;                    { bit 8 }
    cleared_7: boolean;                   { bit 7 }
%else
    cleared_8_7: 0..3;                    { bits 8..7 }
%endif
    faulted: boolean;                     { bit 6 }
    unused_5: boolean;                    { bit 5 }
    dma_bus: boolean;                     { bit 4 }
    unused_3_1: 0..7;                     { bits 3..1 }
    cleared_0: boolean;                   { bit 0 }
  end;

  { A unit's transfer control longword (+0x4C), PBU_$CONTROL's.  With
    longword I/O map entries (`long_iomap'): wide (PBU_$CONTROL's answer
    [0] while it is clear, [1] while it is set); mode, 0..2 (the answer's
    member 2, 3 or 4); the module's initial value (16#48000) has wide
    and bit_15 set; PBU2_$WIRE_MAP adds the whole longword to each page
    number it writes to the I/O map: all, as status_$t's.  Without them
    the control is the high word, entry, which PBU2_$WIRE_MAP adds to
    the page number of a word entry: bit_15 (the entry's bit 15, set in
    the module's initial value, 16#80000000), narrow (the answer [0]
    while it is set, [1] while it is clear) and mode, the entry's bits
    14 and 13..12. }
%if long_iomap %then
  pbu_$ctl_t = packed record
    case integer of
      1: (unused_31_19: 0..8191;          { bits 31..19 }
          wide: boolean;                  { bit 18 }
          mode: 0..3;                     { bits 17..16 }
          bit_15: boolean;                { bit 15 }
          unused_14_0: 0..32767);         { bits 14..0 }
      2: (all: integer32);
  end;
%else
  pbu_$ctl_t = packed record
    case integer of
      1: (bit_15: boolean;                { bit 31 }
          narrow: boolean;                { bit 30 }
          mode: 0..3;                     { bits 29..28 }
          unused_27_16: 0..4095;          { bits 27..16 }
          unused_15_0: 0..65535);         { bits 15..0 }
      2: (all: integer32);
      3: (entry: integer;                 { bits 31..16 }
          unused_low: integer);           { bits 15..0 }
  end;

  { An IOMAP entry where the entries are words (no `long_iomap'): entry,
    the page number plus a transfer control's high word; the second
    word, which nothing writes. }
  pbu_$iomap_entry_t = record
    entry: integer;                       { 0x00 }
    unused_02: integer;                   { 0x02 }
  end;
%endif

  { A PBU unit's DCTE, 0x54 bytes: one of the 8 of PBU_$DCTE_TABLE, in
    PBU_$DCTES while the unit is set up.  device_routine, the routine
    PBU_$INT_COM calls with the DCTE in A1 (PBU_$ADVANCE_ONLY,
    PBU_$USER_SPACE_DRIVER or a kernel driver's); vector, the interrupt
    id's vector word; unit, the DDF's unit (pbu_free_unit when free);
    owner, the
    owning process (0 when free); asid, the owner's address space;
    user_handler and user_stack, the user-space handler and its stack
    (PBU_$USER_SPACE_DRIVER's); ec_ptr, the eventcount PBU_$INT_COM
    advances (the DCTE's own ec, or the SM_ controller's, sm/int.pas);
    csr_va, csr_ppn and csr_pages, the CSR pages' virtual address, first
    physical page and count; map_page, map_start and map_end, the I/O
    map space of PBU2_$ALLOCATE_MAP; assoc_va, assoc_length and
    assoc_iova, the controller memory of PBU2_$ASSOC; ctl, the transfer
    control (pbu_$ctl_t); sharing, pbu_public or a kernel unit's mode
    (PBU_$ACQUIRE_INT's last word). }
  pbu_$dcte_ptr_t = ^pbu_$dcte_t;
  pbu_$dcte_t = record
    unused_00: integer32;                 { 0x00 }
    device_routine: univ_ptr;             { 0x04 }
    vector: pbu_$byte_t;                  { 0x08 }
    unit: pbu_$byte_t;                    { 0x09 }
    owner: pbu_$byte_t;                   { 0x0A }
    asid: pbu_$byte_t;                    { 0x0B }
    unused_0c: integer32;                 { 0x0C }
    unit_info: pbu_$dcte_unit_t;          { 0x10 }
    flags: pbu_$dcte_flags_t;             { 0x12 }
    ec: ec_$eventcount_t;                 { 0x14 }
    user_handler: univ_ptr;               { 0x20 }
    ec_ptr: ec_$eventcount_ptr_t;         { 0x24 }
    user_stack: univ_ptr;                 { 0x28 }
    csr_va: linteger;                     { 0x2C }
    csr_ppn: integer32;                   { 0x30 }
    csr_pages: integer;                   { 0x34 }
    map_page: integer;                    { 0x36 }
    map_start: integer32;                 { 0x38 }
    map_end: linteger;                    { 0x3C }
    assoc_va: linteger;                   { 0x40 }
    assoc_length: integer32;              { 0x44 }
    assoc_iova: linteger;                 { 0x48 }
    ctl: pbu_$ctl_t;                      { 0x4C }
    sharing: integer;                     { 0x50 }
    unused_52: integer;                   { 0x52 }
  end;

  { A DCTE as its 0x54 bytes, from 1 (PBU_$SETUP's clear, PBU_$GET_DCTE's
    copy). }
  pbu_$dcte_bytes_t = array[1..84] of char;
  pbu_$dcte_bytes_ptr_t = ^pbu_$dcte_bytes_t;

  { A unit's user stack area: the library keeps the unit's eventcount
    list's head at +0x20 above the stack's start (PBU_$ALLOCATE_EC,
    PBU_$RELEASE_EC).  The size is not seen. }
  pbu_$stack_area_t = record
    unused_00: array[1..8] of integer32;  { 0x00 }
    ecs: pbu_$ec_entry_ptr_t;             { 0x20 }
  end;
  pbu_$stack_area_ptr_t = ^pbu_$stack_area_t;

  { PBU_$GET_INFO's answer, three words: 1, 2 and 1.  What they mean is
    not seen. }
  pbu_$info_t = record
    info_1: integer;                      { 0x00 }
    info_2: integer;                      { 0x02 }
    info_3: integer;                      { 0x04 }
  end;

  { PBU2_$WIRE_SPECIAL's options: member 0, the pages must be wired for
    the unit already; member 1, refused (with the AT bus's units,
    `pbu_atbus_units': a physically contiguous buffer).  The answer
    list: one physical address per page. }
  pbu_$wire_options_t = set of 0..15;
  pbu_$pa_list_t = array[1..1] of integer32;

  { PBU_$CONTROL's request and answer words (pbu_$ctl_t's fields). }
  pbu_$ctl_word_t = set of 0..15;

const
  { A CSR access's kind (TESTPAGE's): a byte or a word read or written.
    A byte is the high half of the data word. }
  pbu_csr_read_byte = 0;
  pbu_csr_read_word = 1;
  pbu_csr_write_byte = 2;
  pbu_csr_write_word = 3;

type
  { pbu_access_csr's data word. }
  pbu_$csr_data_t = record
    case integer of
      1: (word: integer);                 { 0x00 }
      2: (high: char;                     { 0x00 }
          low: char);                     { 0x01 }
  end;

  { A user buffer passed by address, whose address the routines use. }
  pbu_$buffer_t = char;

var
  { PBU_$DCTES (map symbol in PBU_ASM): the DCTE of each unit, nil when
    the unit is not set up.  Hand-written data, reached by its absolute
    address. }
  pbu_$dctes: extern array[0..pbu_$max_unit] of pbu_$dcte_ptr_t;

  { PBU_$DCTE_TABLE (map symbol in PBU_ASM): the addresses of the DCTEs
    PBU_$SETUP hands out. }
  pbu_$dcte_table: extern array[0..pbu_dcte_table_last] of
    pbu_$dcte_ptr_t;

%if pbu_atbus_units %then
  { PBU_$NONSYS_DEVICE (map symbol, PBU's data block +0x56): a set of
    units, all of them initially; PBU_$RELEASE_INT adds the unit it sets
    down.  Nothing in the PBU's code tests it.  Defined in pbu/pbu.pas. }
  pbu_$nonsys_device: extern pbu_$unit_set_t;
%endif

  { PBU_$PPN_OWNERS (map symbol, the one of the map's PBU_TABLES data
    segment, a fixed address in the low region): for each physical page
    from 16#200, the set of units that have it wired.  PBU_$INIT maps the
    pages that cover MMAP_$LPPN..MMAP_$HPPN.  Packed: a byte per page
    with `pbu_8_units' (the SAU3's PBU_TABLES, 0xE00 bytes for the
    0xE00 pages), a word per page otherwise. }
  pbu_$ppn_owners: extern packed array[pbu_ppn_owners_first..
                                       pbu_ppn_owners_last] of
    pbu_$unit_set_t;

  { PBU_IO (map symbol of the I/O definitions, no `$'): the PBU's I/O
    pages' base; a unit's CSR address on the bus is its page's distance
    from it (LPR_$ACQUIRE). }
  pbu_io: extern char;

  { PBU_$PAGE_START (map symbol, PBU_ASM's first byte): with
    PBU_$DATA_END the range PBU_$WIRE_PBU wires.  A marker. }
  pbu_$page_start: extern char;

  { IOMAP (map symbol of the I/O definitions, no `$'): the PBU's I/O
    map, 4 bytes a page (the next symbol is 4 KB on), the page number
    plus the unit's transfer control; PBU2_$WIRE_MAP and the storage
    module drivers write it, pbu_clear_iomap clears it.  A longword with
    `long_iomap' (the SAU5, SAU6); otherwise the entry is the first word
    of the 4 bytes (pbu_$iomap_entry_t), bit 15 its valid bit and the
    page number below the control bits, the second word not written.
    With `word_iomap' the entries are words, 2 bytes a page (the map's
    0x800 bytes to the end of the address space), the page number alone. }
%if long_iomap %then
  iomap: extern array[0..1023] of integer32;
%elseif word_iomap %then
  iomap: extern array[0..1023] of pinteger;
%else
  iomap: extern array[0..1023] of pbu_$iomap_entry_t;
%endif

{ ---- The hand-written routines of PBU_ASM (pbu/sau5/pbu_asm.s) that
  PBU's Pascal names; only their addresses are used. ---- }

{ PBU_$INT_COM: every unit's interrupt routine, IO_$ACQUIRE's handler
  (the DCTE its argument) when the DDF gives no kernel handler. }
procedure pbu_$int_com; extern;

{ PBU_$ADVANCE_ONLY and PBU_$USER_SPACE_DRIVER: a DCTE's device routine
  without and with a user handler. }
procedure pbu_$advance_only; extern;
procedure pbu_$user_space_driver; extern;

{ PBU_$IGNORE_INT: a device routine that advances nothing (D0 0);
  no reference to it in the image. }
procedure pbu_$ignore_int; extern;

{ ---- PBU_$MCB, and the routines other modules call. ---- }


const
  { "page already wired" (stcode.db.10.2): PBU_$SAVE_PPN stores it, and
    its callers take it as no failure. }
  status_$pbu_page_already_wired = 16#001E0019;

type
  { PBU_$MCB (map symbol in the hand-written PBU_ASM data, 4 bytes): the
    PBU's flags word and its count of set-up units.  present, the
    Multibus's (callers test the word's sign; PBU2_$ASSOC clears it when
    a VME controller's memory takes the Multibus's window); wired,
    PBU_$WIRE_PBU's pages wired; high_ok, the upper VME window usable;
    vme_set_up, a VME unit set up; owners_mapped, PBU_$PPN_OWNERS' pages
    mapped by PBU_$INIT; high_window, set by PBU2_$ASSOC for the upper
    window; setups, the count PBU_$SETUP adds to and PBU_$SETDOWN takes
    from. }
  pbu_$mcb_t = packed record
    present: boolean;                     { bit 15 of the first word }
    wired: boolean;                       { bit 14 }
    high_ok: boolean;                     { bit 13 }
    vme_set_up: boolean;                  { bit 12 }
    owners_mapped: boolean;               { bit 11 }
    high_window: boolean;                 { bit 10 }
    unused_9_0: 0..1023;                  { bits 9..0 }
    setups: integer;                      { the second word }
  end;

var
  pbu_$mcb: extern pbu_$mcb_t;

{ PBU_$TRAP6 (hand assembly in PBU_ASM): the trap 6 handler, whose
  address OS_$INIT's vector table holds; only its address is used. }
procedure pbu_$trap6; extern;

{ PBU_$SHUTDOWN - set down the PBU's user units at shutdown. }
procedure pbu_$shutdown(out status: status_$t); extern;

{ PBU_$GET_DIAG_PTR and PBU_$INT_FAULT_COM (hand assembly in PBU_ASM):
  one longword each off the stack, the fault's SSP (FIM_$BUILD_DF's
  calls): `val_param'; PBU_$GET_DIAG_PTR leaves an address in A0, a
  pointer function; PBU_$INT_FAULT_COM takes the value as its stack
  pointer and does not return. }
function pbu_$get_diag_ptr(ssp: integer32): univ_ptr;
  options(extern, val_param);
procedure pbu_$int_fault_com(ssp: integer32); options(extern, val_param);

{ PBU_$WIRE_PBU - wire the PBU page. }
procedure pbu_$wire_pbu; extern;

{ PBU_$ACQUIRE_INT - set up a PBU unit for a kernel driver. }
procedure pbu_$acquire_int(unit: integer; handler: univ_ptr;
                           handler_arg: univ_ptr; csr_va: univ_ptr;
                           csr_pa: integer32; csr_pages: integer;
                           sharing: integer; out status: status_$t);
  options(extern, val_param);

{ PBU_$GET_PTR - one of a PBU unit's addresses. }
function pbu_$get_ptr(in unit: integer; in which: integer;
                      out size: integer32;
                      out status: status_$t): univ_ptr;
  extern;

{ PBU_$ALLOC - allocate I/O map space for a kernel driver's unit. }
function pbu_$alloc(unit: integer; fixed: boolean; npages: integer;
                    iova: linteger; out status: status_$t): integer32;
  options(extern, val_param);

{ PBU_$FREE - free I/O map space a kernel driver's unit allocated. }
procedure pbu_$free(unit: integer; iova: linteger; npages: integer;
                    out status: status_$t);
  options(extern, val_param);

{ PBU_$RELEASE_INT - set down a kernel driver's PBU unit. }
procedure pbu_$release_int(in unit: integer; in mode: integer;
                           out status: status_$t);
  extern;

{ PBU2_$UNWIRE - unwire a buffer a PBU unit wired. }
procedure pbu2_$unwire(in unit: integer; var buffer: univ pbu_$buffer_t;
                       in length: linteger; in touch: boolean;
                       out status: status_$t);
  extern;

{ PBU_$DELETE_PPN - take a unit out of a wired page's owners.
  PBU_$SAVE_PPN - wire a page for a unit. }
procedure pbu_$delete_ppn(unit: integer; ppn: linteger;
                          out status: status_$t);
  options(extern, val_param);
function pbu_$save_ppn(unit: integer; va: linteger;
                       out status: status_$t): integer32;
  options(extern, val_param);

{ PBU2_$WIRE - wire a buffer for a PBU unit. }
procedure pbu2_$wire(in unit: integer; in buffer: univ pbu_$buffer_t;
                     in length: linteger; out status: status_$t);
  extern;

{ PBU_$ENABLE_DEVICE and PBU_$DISABLE_DEVICE (hand assembly in
  PBU_ASM): two addresses off the stack, the unit's word and the
  status. }
procedure pbu_$enable_device(in unit: integer; out status: status_$t);
  extern;
procedure pbu_$disable_device(in unit: integer; out status: status_$t);
  extern;

{ PBU_$DEVICE_INTERRUPTING (hand assembly in PBU_ASM; PBU_$TRAP6's code
  3): the same two addresses; whether the unit's bit of the adapter's
  interrupt byte is set, false when the check fails (`sf'/`sne' in D0):
  a boolean function. }
function pbu_$device_interrupting(in unit: integer;
                                  out status: status_$t): boolean;
  extern;

{ ---- The module's other routines (pbu/pbu.pas), in map order.  The
  system call table holds the
  addresses of the routines reached from user mode: the default
  convention, every argument by address. ---- }

{ PBU_$ADVANCE_EC - advance a PBU eventcount. }
procedure pbu_$advance_ec(in unit: integer; in ec_index: linteger;
                          out status: status_$t);
  extern;

{ PBU_$ALLOCATE_EC - allocate an eventcount for a PBU unit. }
function pbu_$allocate_ec(in unit: integer; out status: status_$t):
  ec2_$ptr_t; extern;

{ PBU2_$ALLOCATE_MAP - allocate I/O map space for a PBU unit. }
function pbu2_$allocate_map(in unit: integer; in length: integer32;
                            in fixed: boolean; in iova: linteger;
                            out status: status_$t): integer32;
  extern;

{ PBU2_$ASSOC - map a PBU unit's controller memory. }
procedure pbu2_$assoc(in unit: integer; in va: linteger; in iova: linteger;
                      in length: integer32; out status: status_$t);
  extern;

{ PBU_$CONTROL - inquire and set a PBU unit's transfer control. }
procedure pbu_$control(in unit: integer; in request: pbu_$ctl_word_t;
                       out answer: pbu_$ctl_word_t; in unused: integer;
                       out status: status_$t);
  extern;

{ PBU_$DISSOC - unmap a PBU unit's controller memory. }
procedure pbu_$dissoc(in unit: integer; out status: status_$t); extern;

{ PBU_$FREE_MAP - free a PBU unit's I/O map space. }
procedure pbu_$free_map(in unit: integer; out status: status_$t); extern;

{ PBU_$GET_DCTE - copy a PBU unit's DCTE. }
procedure pbu_$get_dcte(in unit: pinteger; out buf: univ pbu_$dcte_bytes_t;
                        in max: integer; out len: integer;
                        out status: status_$t);
  extern;

{ PBU_$GET_EC - the EC2 handle of a PBU unit's eventcount. }
procedure pbu_$get_ec(in unit: integer; in which: integer;
                      out ec: ec2_$ptr_t; out status: status_$t);
  extern;

{ PBU_$GET_INFO - the PBU manager's information. }
procedure pbu_$get_info(in len: pinteger; out info: pbu_$info_t;
                        out status: status_$t);
  extern;

{ PBU_$RELEASE_EC - release a PBU unit's eventcount. }
procedure pbu_$release_ec(in unit: integer; in ec: ec2_$ptr_t;
                          out status: status_$t);
  extern;

{ PBU_$SETDOWN - set down the PBU units PBU_$SETUP set up. }
procedure pbu_$setdown(in unit: integer; in ddf: pbu_$ddf_ptr_t;
                       out status: status_$t);
  extern;

{ PBU_$SETUP - set up the PBU units a DDF describes. }
procedure pbu_$setup(in lib_version: integer; in ddf: pbu_$ddf_ptr_t;
                     out status: status_$t);
  extern;

{ PBU_$UNWIRE_USER_PAGES - unwire every page a unit has wired. }
procedure pbu_$unwire_user_pages(in unit: integer); extern;

{ PBU2_$WIRE_MAP - wire a buffer and map it in a PBU unit's I/O map space. }
function pbu2_$wire_map(in unit: integer; in buffer: univ pbu_$buffer_t;
                        in length: linteger; in iova: linteger;
                        out status: status_$t): integer32;
  extern;

{ PBU_$WIRE_SPECIAL - wire a buffer for a VME unit and list its pages'
  physical addresses. }
procedure pbu_$wire_special(in unit: integer;
                            in options: pbu_$wire_options_t;
                            in buffer: univ pbu_$buffer_t;
                            in length: linteger;
                            out pa_list: univ pbu_$pa_list_t;
                            in max: integer; out count: integer;
                            out status: status_$t);
  extern;

{ PBU_$READ_CSR - read a PBU unit's CSR.
  PBU_$WRITE_CSR - write a PBU unit's CSR. }
procedure pbu_$read_csr(in unit: integer; in csr: univ pbu_$buffer_t;
                        out data: pinteger; in word_access: boolean;
                        out status: status_$t);
  extern;
procedure pbu_$write_csr(in unit: integer; in csr: univ pbu_$buffer_t;
                         in data: integer; in word_access: boolean;
                         out status: status_$t);
  extern;

{ ---- The PBU_MAP module (pbu/pbu_map.pas, PBU_WIRED_PROC), in map
  order.  PBU_$TRAP6's table holds PBU2_$MAP, PBU2_$UNMAP and the DMA
  entries, the system call table PBU_$DMA_START, PBU_$DMA_STATUS,
  PBU2_$DMA_START, PBU2_$DMA_STOP and PBU_$WAIT: the default convention
  (PBU_$TRAP6 copies the user's argument addresses).  Where the DMA
  entries are stubs their arguments are not read but the status; their
  names and types are the AT bus's bodies' (`pbu_atbus_units'). ---- }

type
  { PBU_$DMA_START's options: member 0, 1 or 2 selects the channel's
    mode (1, 2 or 4; 0 for none), member 2 also takes the transfer to
    the unit's own memory (no buffer), member 3 a buffer in bus memory;
    members 4..15 are refused. }
  pbu_$dma_options_t = set of 0..15;

  { A longword as its two words (PBU2_$DMA_START's length). }
  pbu_$long_words_t = record
    high: integer;                        { 0x00 }
    low: pinteger;                        { 0x02 }
  end;

{ PBU_$DMA_START - start a PBU unit's DMA transfer.
  PBU_$DMA_STOP - stop a PBU unit's DMA transfer.
  PBU_$DMA_STATUS - a PBU unit's DMA transfer's status.
  PBU2_$DMA_START - start a PBU unit's DMA transfer.
  PBU2_$DMA_STOP - stop a PBU unit's DMA transfer. }
procedure pbu_$dma_start(in unit: integer; in channel: integer;
                         in direction: integer;
                         in buffer: univ pbu_$buffer_t;
                         in length: pinteger;
                         in options: pbu_$dma_options_t;
                         out status: status_$t);
  extern;
function pbu_$dma_stop(in unit: integer; in channel: integer;
                       out status: status_$t): integer32;
  extern;
procedure pbu_$dma_status(in unit: integer; in channel: integer;
                          out status: status_$t);
  extern;
procedure pbu2_$dma_start(in unit: integer; in channel: integer;
                          in direction: integer;
                          in buffer: univ pbu_$buffer_t;
                          in unused_5: integer32; in length: integer32;
                          in options: pbu_$dma_options_t;
                          out status: status_$t);
  extern;
function pbu2_$dma_stop(in unit: integer; in channel: integer;
                        out status: status_$t): integer32;
  extern;

{ PBU2_$MAP - map a wired buffer in a PBU unit's I/O map space. }
function pbu2_$map(in unit: integer; in buffer: univ pbu_$buffer_t;
                   in length: linteger; in iova: linteger;
                   out status: status_$t): integer32;
  extern;

{ PBU2_$UNMAP - unmap a buffer from a PBU unit's I/O map space. }
procedure pbu2_$unmap(in unit: integer; in buffer: univ pbu_$buffer_t;
                      in length: linteger; in iova: linteger;
                      out status: status_$t);
  extern;

{ PBU_$WAIT - wait for a PBU unit's interrupt. }
const
  { PBU_$WAIT's results (MT's names for the last two):
    the interrupt (or one pending), the time-out (or none pending for a
    timeout of 0), a quit. }
  pbu_$wait_interrupt = 0;
  pbu_$wait_timed_out = 1;
  pbu_$wait_quit = 2;

function pbu_$wait(in unit: integer; in timeout: integer32;
                   in allow_quit: boolean; out status: status_$t): integer;
  extern;

var
  { PBU_$DCTE_INT_PTR and PBU_$VME_DISABLE_COUNT (map symbols in the
    PBU_MAP data segment, PBU_WIRED_DATA, 0xC bytes, +4 and +8): zero in
    the image, and nothing in it refers to them, so their types are not
    seen (a pointer and a count, by their names).  Defined in
    pbu/pbu_map.pas. }
  pbu_$dcte_int_ptr: extern univ_ptr;
  pbu_$vme_disable_count: extern integer32;
%endif

{ PBU_$FREE_ASID - free an address space's PBU state. }
procedure pbu_$free_asid(asid: integer); options(extern, val_param);

{ PBU_$FAULTED_UNITS - report the faulted PBU units. }
function pbu_$faulted_units(out status: status_$t): integer; extern;

{ PBU_$INIT - initialize the PBU support. }
%if pbu_driver %then
{ With the driver. }
procedure pbu_$init(init_lock: boolean); options(extern, val_param);
%else
{ Where the driver is configured out. }
procedure pbu_$init; extern;
%endif

{ PBU_$ADVANCE_EC_INT - advance a PBU eventcount at interrupt level. }
procedure pbu_$advance_ec_int(in owner_id: integer; in ec_index: linteger;
                              out status: status_$t);
  extern;
