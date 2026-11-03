{ disk/disk.ins.pas - DISK_ (the disk manager): its routine headings,
  types and variables, for the Domain Pascal tree.

  What the Pascal files use.  No Apollo customer insert file of SR10.2
  declares these; the status texts are stcode.db.10.2's.  The headings are
  justified by the bodies (disk/*.pas) and their callers' pushes.  Include
  base/base.ins.pas, ec/ec.ins.pas and time/time.ins.pas before it.
}

const
  { 16#00080007, "disk write protected" (stcode.db.10.2).
    flop_$mount_floppy forgives it after DIR_$SET_DAD (flop/boot.pas);
    DISK_$WRITE_PROTECT's test returns it. }
  status_$disk_write_protected = 16#00080007;

  { The disk manager's codes DMA_$CHECK returns or crashes with
    (stcode.db.10.2: "disk equipment check", "floppy is not 2-sided",
    "bus error occurred during disk DMA transfer", "unknown status
    returned by hardware", "dma not at end of range"; dma/check.pas).
    The floppy's are here too: the Pascal tree has no flp insert, and all
    five are subsystem 0x08's. }
  status_$disk_equipment_check = 16#00080005;
  status_$floppy_is_not_2_sided = 16#00080006;

  { 16#00080008, "bad disk format" (stcode.db.10.2): FLP's EXCS, the AT
    bus WIN_'s win_$check_status and WIN_SCSI_'s sense mapping store
    it. }
  status_$bad_disk_format = 16#00080008;
  status_$bus_error_occurred_during_disk_dma_transfer = 16#00080017;
  status_$unknown_status_returned_by_hardware = 16#00080019;
  status_$dma_not_at_end_of_range = 16#0008001D;

  { 16#0008001B, "floppy door has been opened or storage module has
    been stopped" (stcode.db.10.2).  DBUF_$GET_BLOCK forgives it when
    asked (dbuf/get_block.pas). }
  status_$storage_module_stopped = 16#0008001B;

  { 16#00080016, "drive timed out before operation completed"
    (stcode.db.10.2): the SM_, SM_C and SAU5 WIN_ drivers return it when
    a command's completion eventcount is not advanced within the clock's
    wait. }
  status_$drive_timed_out = 16#00080016;

  { 16#0008001E, "disk already mounted": VOLX_$MOUNT and VOLX_$DISMOUNT
    compare DISK_$PV_MOUNT's status with it. }
  status_$disk_already_mounted = 16#0008001E;

  { The disk manager's codes the floppy driver returns (FLP, flp/*.pas):
    flp_format_track and FLP_DO_IO the busy code, SHAKE and FLP_$CINIT
    the timeout and the controller error, EXCS not ready, the data
    check, the overrun and the parity error, FLP_$DINIT the invalid
    unit. }
  status_$disk_not_ready = 16#00080001;
  status_$disk_controller_busy = 16#00080002;
  status_$disk_controller_timeout = 16#00080003;
  status_$disk_controller_error = 16#00080004;
  status_$disk_data_check = 16#00080009;
  status_$dma_overrun = 16#0008000A;
  status_$invalid_unit_number = 16#00080018;
  status_$memory_parity_error_during_disk_write = 16#00080025;

  { 16#00010002, "disk is full", and 16#00010005, "disk needs salvaging"
    (stcode.db.10.2, OS / BAT manager): BAT_$ALLOCATE and BAT_$RESERVE
    store the first, BAT_$MOUNT the second (bat/*.pas). }
  status_$disk_is_full = 16#00010002;
  status_$disk_needs_salvaging = 16#00010005;

  { The DISK_ module's own codes:
    - 16#0008000D "volume not properly mounted or assigned": DISK_$WRITE,
      DISK_$READ, DISK_$READ_MULTI, DISK_$FORMAT_WHOLE, DISK_$FORMAT;
    - 16#0008000F "invalid volume index": DISK_IO, DISK_$READ_MULTI,
      DISK_$FORMAT_WHOLE, DISK_$FORMAT;
    - 16#00080011 "disk block header error": DISK_IO, DISK_$READ_MULTI;
    - 16#00080012 "invalid disk address": disk_$map_request, tested by
      disk_$io_error;
    - 16#0008001C "read after write failed", 16#0008001F "software
      detected checksum error", 16#00080020 "checksum error in read
      after write": DISK_IO, each crashing the system;
    - 16#0008002A "illegal request for device": DISK_$FORMAT;
    - 16#0008002D "disk striping not yet supported on this device":
      disk_$map_request;
    - 16#0008002E "queued drivers not yet supported on this disk":
      DISK_$ADD_QUE's crash status;
    - 16#0008002F, 16#00080030, 16#00080031, the "completed successfully
      after retry / crc correction / device recovery" codes, which
      DISK_IO, DISK_$WRITE_MULTI and DISK_$READ_MULTI turn into
      status_$ok. }
  status_$volume_not_properly_mounted = 16#0008000D;
  status_$invalid_volume_index = 16#0008000F;
  status_$disk_block_header_error = 16#00080011;
  status_$invalid_disk_address = 16#00080012;
  status_$read_after_write_failed = 16#0008001C;
  status_$software_detected_checksum_error = 16#0008001F;
  status_$checksum_error_in_read_after_write = 16#00080020;
  status_$disk_illegal_request_for_device = 16#0008002A;
  status_$disk_striping_not_supported = 16#0008002D;
  status_$disk_queued_drivers_not_supported = 16#0008002E;
  status_$disk_ok_after_retry = 16#0008002F;
  status_$disk_ok_after_crc_correction = 16#00080030;
  status_$disk_ok_after_device_recovery = 16#00080031;

type
  { A byte of the disk records, an unsigned 8-bit value (suma's form). }
  disk_$byte_t = [byte] 0..255;

  { A device registration entry, 12 bytes: DISK_$REGISTER stores the
    five fields; FLP reads the controller word through a volume's
    dev_info. }
  disk_$device_entry_t = record
    jump_table: univ_ptr;                 { 0x00 }
    device_type: pinteger;                { 0x04 }
    controller: pinteger;                 { 0x06 }
    unit_count: pinteger;                 { 0x08 }
    flags: pinteger;                      { 0x0A }
  end;
  disk_$device_entry_ptr_t = ^disk_$device_entry_t;

  { A striped set's member volume indices, part_volx[1..8] as one record:
    disk_$pv_mount_internal copies its eight-word local into a
    descriptor's part_volx[1..8] as one 16-byte object. }
  disk_$part_list_t = array[1..8] of pinteger;
  { A volume descriptor, 0x48 bytes.  FLP reads dev_info (0x18), dev_unit
    (0x1C), sec_per_track (0x20; tested for 0 before a `dbf' count:
    unsigned) and the async options' member 1 (a word set, member 1 in
    its low byte), and FLP_$DINIT clears that word in a local
    descriptor.  lv_start, addr_start and addr_end are linteger:
    disk_$map_request compares the request's address with the last two
    unsigned and adds the first to it.  as_options' member 0 is the
    write protection (DISK_$WRITE_PROTECT).  part_volx is the first
    variant of the record's last part; the second names part_volx[1..8]
    as one 16-byte array, which disk_$pv_mount_internal assigns whole
    (disk_$part_list_t, above). }
  disk_$volume_t = record
    lv_uid: uid_$t;                       { 0x00 }
    lv_start: linteger;                   { 0x08 }
    addr_start: linteger;                 { 0x0C }
    addr_end: linteger;                   { 0x10 }
    mount_state: pinteger;                { 0x14 }
    mount_proc: integer;                  { 0x16 }
    dev_info: disk_$device_entry_ptr_t;   { 0x18 }
    dev_unit: pinteger;                   { 0x1C }
    unit_id: pinteger;                    { 0x1E }
    sec_per_track: pinteger;              { 0x20 }
    num_heads: pinteger;                  { 0x22 }
    blocks_per_cyl: pinteger;             { 0x24 }
    bat_step: pinteger;                   { 0x26 }
    as_options: set of 0..15;             { 0x28 }
    sector_size_code: pinteger;           { 0x2A }
    num_parts: pinteger;                  { 0x2C }
    stripe_blk_mask: pinteger;            { 0x2E }
    stripe_blk_shift: pinteger;           { 0x30 }
    stripe_vol_mask: pinteger;            { 0x32 }
    stripe_vol_shift: pinteger;           { 0x34 }
    case integer of
      1: (part_volx: array[0..8] of pinteger);  { 0x36 }
      2: (part_word0: pinteger;           { 0x36: part_volx[0] }
          part_list: disk_$part_list_t);  { 0x38: part_volx[1..8] }
  end;

  { A request's disk address: the longword, or for the floppy its
    cylinder word and head and sector bytes (FLP_DO_IO).  The longword
    is linteger: DISK_$SORT orders requests by it unsigned. }
  disk_$daddr_t = record
    case integer of
      1: (daddr: linteger);               { 0x00 }
      2: (cyl: pinteger;                  { 0x00 }
          head: disk_$byte_t;             { 0x02 }
          sector: disk_$byte_t);          { 0x03 }
  end;

  { The eight-longword block header DISK_$READ and DISK_$WRITE take by
    address, the formal type of their `univ' parameter; DBUF passes its
    dbuf_$hdr_t (dbuf/dbuf.ins.pas). }
  disk_$info_t = array[1..8] of integer32;

  { A request's block header, 0x20 bytes at +0x20, in three views.
    - The caller's eight longwords (l): DISK_IO copies them in whole,
      compares the first three after a read, and disk_$io_error copies
      them out whole.
    - The fields (the second view): the first three longwords are the
      object's UID and the hint (DBUF's dbuf_$ident_t, dbuf/dbuf.ins.pas,
      which this file cannot name: it comes after).  DISK_IO and
      DISK_$READ_MULTI  compare the first eight bytes as one record and the
      third longword alone, and step or complement it.  DISK_IO writes the
      clock at +0x0C, clears the longwords at +0x12 and +0x16, stores the
      checksum word at +0x1A; disk_$map_request stores the absolute disk
      address at +0x1C, which DISK_$SORT and DISK_$ADD_QUE compare unsigned:
      linteger.
    - The bytes pmap_$fill_write_qblks writes one by one in a page
      write's header (the third view): 0x10 cleared, 0x11 the AOTE's sub
      type or 0, 0x12..0x1B cleared in a byte loop (a `for' fill of a
      character array); the UID, the hint and the
      clock it writes through the second view.
    sub_type is the AOTE's. }
  disk_$block_hdr_t = record
    case integer of
      1: (l: disk_$info_t);               { 0x00 }
      2: (uid: uid_$t;                    { 0x00 }
          hint: integer32;                { 0x08 }
          written: time_$clockh_t;        { 0x0C }
          unused_10: pinteger;            { 0x10 }
          unused_12: integer32;           { 0x12 }
          unused_16: integer32;           { 0x16 }
          chksum: pinteger;               { 0x1A }
          abs_daddr: linteger);           { 0x1C }
      3: (unused_3_00: array[1..16] of char;
                                          { 0x00..0x0F }
          byte_10: char;                  { 0x10 }
          sub_type: char;                 { 0x11 }
          bytes_12: array[1..10] of char; { 0x12..0x1B }
          unused_3_1c: integer32);        { 0x1C }
  end;

  { A request's bytes 0x1E, 0x1F: the owner and the operation flags

    Why the two bytes are one record.  An unpacked record's size is even,
    "the smallest possible record is 2 bytes", and its fields longer than
    a byte (a record among them) start on word boundaries (ref 3.10.5.5,
    p. 3-26); a packed record's structured fields are word aligned too
    (3.10.7, p. 3-35).  So a record field, packed or not, cannot sit at
    0x1F, where the image has the flags: as a field of disk_$io_req_t
    the 1-byte packed record took 0x20..0x21 and the request grew to 0x44
    bytes.  A size attribute cannot make a record 1 byte (a
    size attribute "must specify at least the number of bits required
    for the type", 3.15.5, p. 3-61, and a record needs 16), nor can a type
    transfer view one byte as a record ("the size of the argument must be
    the same as the size of the destination type", p. 4-197).  The packed
    record of the two bytes keeps every access in the image's form: in a
    packed record a byte-sized subrange is bit aligned and starts at the
    next free bit, and the variant part follows the fixed field (3.10.7),
    so owner is bits 15..8 (0x1E), the flags bits 7..0 (0x1F), the whole
    2 bytes word aligned at 0x1E, and the request 0x40 bytes (a dpc probe).

    The image's accesses, each the packed field's form:
    - owner read and stored as a byte (FLP, WIN's format_track;
      disk_$get_qblks_internal stores PROC1_$CURRENT's low byte);
    - the whole flags byte (all): the callers of DISK_$WRITE_MULTI and
      _$READ_MULTI put a volume index there (DISK_$AS_XFER_MULTI,
      pmap_$fill_write_qblks), DISK_$WRITE_MULTI reads it whole;
      disk_$map_request and disk_$get_qblks_internal clear it;
    - op, bits 3..0: disk_$map_request merges the operation ("Wider
      field, value"), DISK_$FORMAT and _$FORMAT_WHOLE a constant;
      FLP_DO_IO and WIN_$DO_IO read it;
    - mark, bit 6: DISK_$ADD_QUE's merges set it ("Boolean field,
      constant");
    - chksum, bit 7: DISK_IO stores a computed boolean, WIN_$DO_IO tests
      it as the byte's sign ("Boolean field, test").
    Bits 5 and 4 have no reader.
    (Alternatives: the whole request a packed record with the flags'
    four fields inline, which leaves no form for the whole byte the image
    stores and reads, since a variant part must come last and the header
    follows; a byte field op_flags with the flags reached through a
    pointer view, `disk_$..._ptr_t(addr(req.op_flags))^', whose loads and
    stores dpc forms through an address register, not the image's
    displacements; both rejected.) }
  disk_$owner_op_t = packed record
    owner: disk_$byte_t;                  { 0x1E, bits 15..8 }
    case integer of
      1: (all: disk_$byte_t);             { 0x1F, the whole byte }
      2: (chksum: boolean;                { 0x1F bit 7 }
          mark: boolean;                  { 0x1F bit 6 }
          unused_54: 0..3;                { 0x1F bits 5..4 }
          op: 0..15);                     { 0x1F bits 3..0 }
  end;

  { A disk request, 0x40 bytes.  FLP reads daddr, ppn (0x14), owner
    (0x1E) and the operation (0x1F), and writes status (0xC); +0x10 is
    the block's physical address (disk_$grow_qblk_pool); +0x18 a
    request's address, the end of its run, stored by DISK_$ADD_QUE and
    dereferenced by its merges.  owner and the flags are the one 2-byte
    record owner_op (above), which puts the flags at 0x1F and the request
    at 0x40 bytes, as the image has them. }
  disk_$io_req_t = record
    next: univ_ptr;                       { 0x00 }
    daddr: disk_$daddr_t;                 { 0x04 }
    free_next: univ_ptr;                  { 0x08 }
    status: status_$t;                    { 0x0C }
    phys: integer32;                      { 0x10 }
    ppn: integer32;                       { 0x14 }
    reserved_18: univ_ptr;                { 0x18 }
    flags: pinteger;                      { 0x1C }
    owner_op: disk_$owner_op_t;           { 0x1E: owner, 0x1F: the
                                            flags (above) }
    header: disk_$block_hdr_t;            { 0x20 }
  end;

  { A pointer to a request, the link of a request chain (DISK_$SORT
    takes the chain's head by address). }
  disk_$io_req_ptr_t = ^disk_$io_req_t;

  { A page of the queue-block pool, sixteen requests:
    disk_$grow_qblk_pool chains a page's blocks 0x40 bytes apart, the
    last one's link at the page's end less 0x38. }
  disk_$qblk_page_t = array[1..16] of disk_$io_req_t;

  { One process's slot of DISK_BPTBL, 0x1C bytes: the two eventcounts,
    then io_pending at 0x18.  DISK_$INIT passes the eventcounts to
    EC_$INIT, disk_$wait_io to EC_$WAIT, and DISK_$WRITE_MULTI reads
    their values; so the file needs ec/ec.ins.pas before it. }
  disk_$bp_slot_t = record
    io_ec: ec_$eventcount_t;              { 0x00 }
    err_ec: ec_$eventcount_t;             { 0x0C }
    io_pending: boolean;                  { 0x18 }
    pad_19: char;                         { 0x19 }
    pad_1a: char;                         { 0x1A }
    pad_1b: char;                         { 0x1B: (layout)
                                            three chars, not a 3-char
                                            array, which is word aligned
                                            (ref 3.10.5.5) and made the
                                            slot 0x1E bytes where
                                            DISK_BPTBL's are 0x1C }
  end;


  { A set of volume indices in a word (DISK_$WAIT_QUE's mask):
    disk_$wait_io tests member i of its by-value word, DISK_$WRITE_MULTI
    builds it. }
  disk_$vol_set_t = set of 0..15;

  { A request queue's position, the longword at +0x04 of disk_$que_t
    (bit 31 the scan direction, bits 19..4 the current cylinder).  The
    direction is member 15 of the high word as a set: DISK_$INIT_QUE
    sets it (the member's bit reduced through an address register) and
    DISK_$ADD_QUE tests it as the word's sign.  The cylinder
    is a 16-bit packed field of the longword:  INIT_QUE clears it, ADD_QUE
    reads it.  The other bits have no reader. }
  disk_$que_pos_t = packed record
    case integer of
      1: (dir: set of 0..15;              { 0x04: member 15, bit 31 }
          unused_06: pinteger);           { 0x06 }
      2: (unused_31_20: 0..4095;          { bits 31..20 }
          cyl: 0..65535;                  { bits 19..4 }
          unused_3_0: 0..15);             { bits 3..0 }
  end;

  { A queue's end marker, 8 bytes shaped as a request's first six:
    DISK_$INIT_QUE sets next nil and the cylinder 16#FFFF. }
  disk_$que_sentinel_t = record
    next: univ_ptr;                       { 0x00 }
    daddr: disk_$daddr_t;                 { 0x04 }
  end;

  { An elevator queue, 0x20 bytes.  Its first longword is DISK_$ADD_QUE's
    spin lock (ML_$SPIN_LOCK): integer32, as ml/ml.ins.pas's lock.  The two
    lists' heads are requests, each first the sentinel's address. }
  disk_$que_t = record
    current: integer32;                   { 0x00 }
    position: disk_$que_pos_t;            { 0x04 }
    list_a: disk_$io_req_ptr_t;           { 0x08 }
    list_b: disk_$io_req_ptr_t;           { 0x0C }
    sentinel_a: disk_$que_sentinel_t;     { 0x10 }
    sentinel_b: disk_$que_sentinel_t;     { 0x18 }
  end;

  { A driver's jump table.  The entry at 0x0C is FLP's revalidate entry
    (flp/flp.ins.pas), which DISK_$REVALID calls.  The entries are called
    through the routine types below, converted at each call; a driver's
    table is initialized with addr(...) of its routines (win/win.pas,
    flp/flp.pas). }
  disk_$jump_table_t = record
    spin_down: univ_ptr;                  { 0x00 }
    shutdown: univ_ptr;                   { 0x04 }
    dinit: univ_ptr;                      { 0x08 }
    revalidate: univ_ptr;                 { 0x0C }
    do_io: univ_ptr;                      { 0x10 }
    error_que: univ_ptr;                  { 0x14 }
    get_stats: univ_ptr;                  { 0x18 }
  end;
  disk_$jump_table_ptr_t = ^disk_$jump_table_t;

  { The record a driver's dinit fills, as FLP_$DINIT's 10 bytes
    (flp/flp.ins.pas flp_$pvlabel_info_t, its names; WIN_$DINIT's is 4
    bytes, so the entry takes it `univ'). }
  disk_$pvlabel_info_t = record
    l_00: integer32;                      { 0x00 }
    w_04: pinteger;                       { 0x04 }
    w_06: pinteger;                       { 0x06 }
    w_08: pinteger;                       { 0x08 }
  end;

  { The statistics block DISK_$GET_STATS hands out, 22 bytes (WIN_$CNT's
    layout, win/win.ins.pas win_$cnt_t): two longwords, which GET_STATS
    tests, then seven words. }
  disk_$stats_t = record
    xfers: array[1..2] of integer32;      { 0x00 }
    counts: array[1..7] of pinteger;      { 0x08 }
  end;

  { The jump table's entries (the drivers' headings, flp/flp.ins.pas and
    win/win.ins.pas), from how DISK_'s dispatchers call them: spin_down
    takes the controller word by address and returns a word; shutdown two
    words by value; dinit two words by value and five slots, a longword
    result; revalidate the volume by address; do_io four addresses;
    error_que an address, a word and an address after the pad; get_stats
    two words and an address. }
  disk_$spin_down_proc_t = ^function(in ctlr: pinteger): integer;
  disk_$shutdown_proc_t = ^function(ctlr: pinteger; unit: pinteger): integer;
    options(val_param);
  disk_$dinit_proc_t = ^function(unit: pinteger; ctlr: pinteger;
                                 var num_blocks: integer32;
                                 var sec_per_track: pinteger;
                                 var num_heads: pinteger;
                                 out pvlabel_info: univ disk_$pvlabel_info_t;
                                 out flags: pinteger): integer32;
    options(val_param);
  disk_$revalidate_proc_t = ^procedure(in vol: disk_$volume_t);
  disk_$do_io_proc_t = ^procedure(in vol: disk_$volume_t;
                                  var req: disk_$io_req_t;
                                  in param_3: univ integer32;
                                  out result: boolean);
  disk_$error_que_proc_t = ^procedure(in vol: disk_$volume_t;
                                      is_timeout: integer;
                                      out result: boolean);
    options(val_param);
  disk_$get_stats_proc_t = ^procedure(cnum: integer; unit: integer;
                                      out stats: univ disk_$stats_t);
    options(val_param);

  { The per-volume request lists DISK_IO, DISK_$WRITE_MULTI and
    _$READ_MULTI build through disk_$map_request, 8 bytes a volume: the
    map appends a request at volume volx's element of an array from 1. }
  disk_$vol_map_entry_t = record
    head: disk_$io_req_ptr_t;             { 0x00 }
    tail: disk_$io_req_ptr_t;             { 0x04 }
  end;
  disk_$vol_map_t = array[1..10] of disk_$vol_map_entry_t;

  { The last disk error, 0x56 bytes, DISK_$ERROR_INFO, written only by
    disk_$io_error.  The geometry is two words, the physical volume's
    sec_per_track and num_heads, stored as one longword (two adjacent
    stores merged); the header's longwords as the request's. }
  disk_$geometry_t = record
    sec_per_track: pinteger;              { 0x00 }
    num_heads: pinteger;                  { 0x02 }
  end;
  disk_$error_info_t = record
    timestamp: time_$clockh_t;            { 0x00 }
    daddr: linteger;                      { 0x04 }
    geometry: disk_$geometry_t;           { 0x08 }
    info: disk_$info_t;                   { 0x0C }
    header: disk_$block_hdr_t;            { 0x2C }
    ppn: integer32;                       { 0x4C }
    status: status_$t;                    { 0x50 }
    vol_idx: pinteger;                    { 0x54 }
  end;


var
  { DISK_$DVTBL (map symbol, inside the map's first DISK_ data segment,
    0xB90 bytes, .DATA, at +0xC4): the volume descriptors, from volume 1.
    BAT_$MOUNT reaches volume v's by the symbol's address, the index
    scaled by 0x48 and the lower bound folded into the displacements:
    another unit's array, element 1 at the symbol.  Ten: DISK_BPTBL
    follows 10 * 0x48 bytes on. }
  disk_$dvtbl: extern array[1..10] of disk_$volume_t;

  { DISK_BPTBL (a map symbol without `$', MARKED, inside the same
    segment, at +0x394; a global): the per-process slots
    from process 1.  The floppy driver clears the pending byte of the
    process a request names, by the symbol's address, the index scaled
    by 0x1C and the displacement 0x18 - 0x1C, so the element of index 1
    is at the symbol.  64 slots. }
  disk_bptbl: extern array[1..64] of disk_$bp_slot_t;

  { The other map symbols inside the same segment, defined by
    disk/disk.pas:
    - DISK_$ERROR_INFO (+0xA94), the last error (above);
      DISK_$GET_ERROR_INFO reads it by its address;
    - DISK_$RAW_PPN (+0xAEC), the physical page DISK_IO reads a written
      block back into;
    - DISK_$NFBLKS (+0xAF8), the free queue blocks, a word compared
      signed (disk_$grow_qblk_pool): integer;
    - DISK_$DIAG (+0xAFE) and DISK_$DO_CHKSUM (+0xB00), bytes tested and
      cleared by other units: booleans. }
  { DISK_BLK_POOL (a map symbol without `$' in the DISK_BUFFERS region,
    a load section of 0x14C00 bytes with no module segment: a label of
    that region, as DBUF_BLKS, dbuf/dbuf.ins.pas): the queue-block
    pool's sixteen pages to the region's end, from page 1.
    disk_$grow_qblk_pool reaches page p at the symbol plus p * 0x400 less
    0x400, the free list's first page. }
  disk_blk_pool: extern array[1..16] of disk_$qblk_page_t;

  disk_$error_info: extern disk_$error_info_t;
  disk_$raw_ppn: extern integer32;
  disk_$nfblks: extern integer;
  disk_$diag: extern boolean;
  disk_$do_chksum: extern boolean;

{ DISK_INTERRUPT - the disk controllers' first-level interrupt routine. }
procedure disk_interrupt; extern;

{ DISK_INTERRUPT's crash status, a cell after its code
  (disk/interrupt.pas).  The SR10.2 status-code database: "(80026)
  unrecognized interrupt from disktape controller".  No Apollo insert
  file names it. }
const
  status_$disk_unrecognized_interrupt = 16#00080026;

{ DISK_$SORT - order a request chain for the drive. }
procedure disk_$sort(in vol: disk_$volume_t;
                     in out queue: disk_$io_req_ptr_t);
  extern;

{ DISK_$WRITE - write one block to a mounted volume.
  DISK_$READ - read one block from a mounted or assigned volume. }
procedure disk_$write(vol_idx: integer; daddr: integer32; ppn: integer32;
                      var info: univ disk_$info_t; out status: status_$t);
  options(extern, val_param);
procedure disk_$read(vol_idx: integer; daddr: integer32; ppn: integer32;
                     var info: univ disk_$info_t; out status: status_$t);
  options(extern, val_param);

{ DISK_$PV_MOUNT - mount a physical volume.
  DISK_$LV_UID - the UID of a physical volume's logical volume.
  DISK_$LV_MOUNT - mount a logical volume by its UID.
  DISK_$DISMOUNT - dismount a volume and, when it was the last on its
  device, the device's physical volume and its striped members.
  DISK_$REVALIDATE - ask a volume's driver to revalidate it. }
function disk_$pv_mount(dev: integer; bus: integer; ctlr: integer;
                        out status: status_$t): integer;
  options(extern, val_param);
procedure disk_$lv_uid(pv_idx: integer; lv_num: pinteger; out lv_uid: uid_$t;
                       out status: status_$t); options(extern, val_param);
function disk_$lv_mount(lv_uid: uid_$t; out status: status_$t): integer;
  extern;
procedure disk_$dismount(vol_idx: integer); options(extern, val_param);
procedure disk_$revalidate(vol_idx: integer); options(extern, val_param);

{ DISK_$REGISTER - enter a driver in the device table. }
function disk_$register(in dev_type: integer; in ctlr: integer;
                        units: integer; in flags: integer;
                        in jump_table: univ_ptr): boolean;
  extern;

{ DISK_$WRITE_PROTECT - set or test a volume's write protection. }
procedure disk_$write_protect(mode: integer; vol_idx: integer;
                              out status: status_$t);
  options(extern, val_param);

{ DISK_$GET_BLOCK - DBUF_$GET_BLOCK under the disk lock. }
function disk_$get_block(vol_idx: integer; block: integer32;
                         in uid: uid_$t; block_hint: integer32;
                         block_type: integer; flags: integer;
                         out status: status_$t): univ_ptr;
  options(extern, val_param);

{ DISK_$SET_BUFF - DBUF_$SET_BUFF under the disk lock.
  DISK_$INVALIDATE - drop a volume's buffers, under the disk lock. }
procedure disk_$set_buff(buffer: univ_ptr; flags: integer;
                         out status: status_$t);
  options(extern, val_param);
procedure disk_$invalidate(vol_idx: integer);
  options(extern, val_param);

{ DISK_$GET_QBLKS - take count queue blocks, waiting in turn.
  DISK_$RTN_QBLKS - give a chain of queue blocks back. }
procedure disk_$get_qblks(count: integer; out qblk_head: disk_$io_req_ptr_t;
                          out qblk_tail: disk_$io_req_ptr_t);
  options(extern, val_param);
procedure disk_$rtn_qblks(count: integer; qblk_head: disk_$io_req_ptr_t;
                          qblk_tail: disk_$io_req_ptr_t);
  options(extern, val_param);

{ DISK_$INIT - initialize the disk module's eventcounts and locks. }
procedure disk_$init;
  extern;

{ DISK_$INIT_QUE - initialize an elevator queue. }
procedure disk_$init_que(out queue: disk_$que_t);
  extern;

{ DISK_$ADD_QUE - add a chain of requests to a driver's elevator queue. }
procedure disk_$add_que(flags: integer; in dev: disk_$device_entry_t;
                        var queue: disk_$que_t; req_list: disk_$io_req_ptr_t);
  options(extern, val_param);

{ DISK_$WAIT_QUE - wait for the current process's queued I/O. }
procedure disk_$wait_que(disk_mask: disk_$vol_set_t; var io_wait_val: integer32;
                         var error_wait_val: integer32);
  options(extern, val_param);

{ DISK_$WRITE_MULTI - write a chain of requests, a volume at a time.
  DISK_$READ_MULTI - read a chain of queue blocks from one volume. }
procedure disk_$write_multi(all_mounted: boolean; req_list: disk_$io_req_ptr_t;
                            out status: status_$t);
  options(extern, val_param);
procedure disk_$read_multi(vol_idx: pinteger; mounted: boolean;
                           check_hdr: boolean; qblk_head: disk_$io_req_ptr_t;
                           qblk_tail: disk_$io_req_ptr_t;
                           out pages_read: integer; out status: status_$t);
  options(extern, val_param);

{ DISK_$FORMAT_WHOLE - format a whole volume.
  DISK_$FORMAT - format one track of a volume. }
procedure disk_$format_whole(in vol_idx: integer; out status: status_$t);
  extern;
procedure disk_$format(in vol_idx: integer; in cyl: integer; in head: pinteger;
                       out status: status_$t);
  extern;

{ DISK_IO - one block's transfer, read, write or format. }
function disk_io(op: integer; vol_idx: pinteger; ppn: integer32;
                 daddr: linteger; var info: univ disk_$block_hdr_t): integer32;
  options(extern, val_param);

{ DISK_$GET_DRTE - find a driver's entry in the device table. }
function disk_$get_drte(in ctype: integer; in cnum: integer):
  disk_$device_entry_ptr_t;
  extern;

{ DISK_$MNT_DINIT - initialize a drive through its driver. }
function disk_$mnt_dinit(unit: pinteger; var dev: disk_$device_entry_ptr_t;
                         var num_blocks: univ integer32;
                         var sec_per_track: pinteger;
                         var num_heads: pinteger;
                         out pvlabel_info: univ disk_$pvlabel_info_t;
                         out flags: pinteger): integer32;
  options(extern, val_param);

{ DISK_$DO_IO - start a transfer through the volume's driver. }
procedure disk_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
  extern;

{ DISK_$ERROR_QUE - ask the volume's driver about an error or a timeout. }
procedure disk_$error_que(in vol: disk_$volume_t; is_timeout: integer;
                          out result: boolean);
  options(extern, val_param);

{ DISK_$SPIN_DOWN - spin down every drive and wait for the slowest. }
procedure disk_$spin_down;
  extern;

{ DISK_$REVALID - let the volume's driver revalidate it. }
procedure disk_$revalid(in vol: disk_$volume_t);
  extern;

{ DISK_$GET_STATS - a driver's statistics. }
procedure disk_$get_stats(ctype: integer; cnum: integer; unit: integer;
                          out has_stats: boolean;
                          out stats: disk_$stats_t);
  options(extern, val_param);

{ DISK_$SHUTDOWN - shut a drive down through its driver. }
procedure disk_$shutdown(in dev_info: disk_$device_entry_t; unit: integer);
  options(extern, val_param);

const
  { The third unit's codes (stcode.db.10.2's texts):
    - 16#0008000B "volume in use": the slot finder, DISK_$DIAG_IO,
      DISK_$LV_ASSIGN;
    - 16#0008000C "volume table full": the slot finder, DISK_$LV_MOUNT,
      DISK_$LV_ASSIGN;
    - 16#0008000E "operation requires a physical volume": DISK_$DIAG_IO,
      DISK_$LV_UID, DISK_$LV_ASSIGN;
    - 16#00080010 "logical volume not found": DISK_$LV_MOUNT,
      DISK_$LVUID_TO_VOLX;
    - 16#00080013 "disk buffer is not page aligned": AS_IO_SETUP,
      DISK_$AS_XFER_MULTI, DISK_$DIAG_IO;
    - 16#00080014 "invalid logical volume index or list": DISK_$LV_UID,
      DISK_$LV_ASSIGN;
    - 16#0008001A "invalid physical volume label": the label check,
      disk_$pv_mount_internal;
    - 16#00080022 "disk driver logic error": DISK_$DISMOUNT's crash
      status (and WIN_$CHECK_DISK_STATUS's: declared here, not in
      win/win.ins.pas, which disk.ins.pas precedes in win/win.pas);
    - 16#00080029 "transfer not executed": DISK_$AS_XFER_MULTI. }
  status_$volume_in_use = 16#0008000B;
  status_$volume_table_full = 16#0008000C;
  status_$operation_requires_a_physical_volume = 16#0008000E;
  status_$logical_volume_not_found = 16#00080010;
  status_$disk_buffer_not_page_aligned = 16#00080013;
  status_$invalid_logical_volume_index = 16#00080014;
  status_$invalid_physical_volume_label = 16#0008001A;
  status_$disk_driver_logic_error = 16#00080022;
  status_$disk_transfer_not_executed = 16#00080029;

type
  { A page buffer of the asynchronous and diagnostic transfers, 1024
    bytes: the callers' by-address argument, its address checked for the
    page boundary, and its first word touched before a read: words. }
  disk_$page_t = array[1..512] of integer;
  disk_$info_ptr_t = ^disk_$info_t;

  { DISK_$AS_XFER_MULTI's arrays, one element a page, at most sixteen
    (its frame's arrays: 16 headers, statuses, disk addresses, buffer
    addresses and wired pages), from 1.  The callers' arrays are
    `univ'. }
  disk_$xfer_daddr_list_t = array[1..16] of linteger;
  disk_$xfer_info_list_t = array[1..16] of disk_$info_ptr_t;
  disk_$xfer_va_list_t = array[1..16] of integer32;
  disk_$xfer_status_list_t = array[1..16] of status_$t;
  disk_$xfer_hdr_list_t = array[1..16] of disk_$info_t;

  { A logical volume table of a PV label, ten disk addresses:
    DISK_$LV_MOUNT copies it whole, and DISK_$LV_UID and _$LV_ASSIGN
    index it from 1; compared unsigned with addr_start: linteger. }
  disk_$lv_daddr_list_t = array[1..10] of linteger;

  { The physical volume label, block 0 of a volume, the 0xC0 bytes read
    here.
    version is compared unsigned: pinteger; apollo is the six characters
    compared with `APOLLO'; the disk addresses are compared and
    subtracted unsigned (DISK_$LV_ASSIGN): linteger; num_parts is
    compared unsigned: pinteger; part_dev is copied whole into the
    mount's local, disk_$part_list_t. }
  disk_$pv_label_t = record
    version: pinteger;                    { 0x00 }
    apollo: array[1..6] of char;          { 0x02 }
    name: array[1..32] of char;           { 0x08 }
    pv_uid: uid_$t;                       { 0x28 }
    reserved_30: pinteger;                { 0x30 }
    drive_type: pinteger;                 { 0x32 }
    total_blocks: linteger;               { 0x34 }
    blocks_per_track: pinteger;           { 0x38 }
    tracks_per_cyl: pinteger;             { 0x3A }
    lv_daddr: disk_$lv_daddr_list_t;      { 0x3C }
    alt_lv_daddr: disk_$lv_daddr_list_t;  { 0x64 }
    badspot_daddr: linteger;              { 0x8C }
    diag_daddr: linteger;                 { 0x90 }
    sector_start: pinteger;               { 0x94 }
    sector_size: pinteger;                { 0x96 }
    precomp_cyl: pinteger;                { 0x98 }
    reserved_9a: array[1..3] of pinteger; { 0x9A }
    addr_end: linteger;                   { 0xA0 }
    reserved_a4: integer32;               { 0xA4 }
    num_parts: pinteger;                  { 0xA8 }
    part_num: pinteger;                   { 0xAA }
    part_dev: disk_$part_list_t;          { 0xAC }
    interleave: pinteger;                 { 0xBC }
    sectors_per_block: pinteger;          { 0xBE }
  end;
  disk_$pv_label_ptr_t = ^disk_$pv_label_t;

  { The geometry record of a mount, 16 bytes (the dinit fills its first
    ten as disk_$pvlabel_info_t): DISK_$PV_ASSIGN_N copies it in and out
    whole, and DISK_$PV_ASSIGN hands its first six bytes to the caller
    (a 6-byte record's copy). }
  disk_$pvlabel_head_t = record
    l_00: integer32;                      { 0x00 }
    w_04: pinteger;                       { 0x04 }
  end;
  disk_$pvlabel_head_ptr_t = ^disk_$pvlabel_head_t;
  disk_$pvlabel_buf_t = record
    case integer of
      1: (info: disk_$pvlabel_info_t);    { 0x00..0x09 }
      2: (head: disk_$pvlabel_head_t);    { 0x00..0x05 }
      3: (l: array[1..4] of integer32);   { 0x00..0x0F }
  end;

  { A descriptor's async options word, as_options (disk_$volume_t: a word
    set, member 0 the write protection): DISK_$AS_OPTIONS stores the
    caller's word whole. }
  disk_$as_options_t = set of 0..15;

  { The mount information DISK_$GET_MNT_INFO returns, 0x2A bytes.  A
    partition's word is a packed record: bits 15..11 the device type,
    bits 10..8 the controller, bits 7..4 the unit, each merged unmasked
    (pinteger sources); the word is
    cleared whole.  The flags word at 0x28 is seven booleans and a 9-bit
    field: bit 15 from a computed boolean, bit 14 set or cleared, bits
    13..9 from computed booleans, bits 8..0 cleared.  ASKNODE_$INTERNET_INFO
    tests bits 15 and 14. }
  disk_$part_info_t = packed record
    case integer of
      1: (all: pinteger);
      2: (dev_type: 0..31;                { bits 15..11 }
          ctrl: 0..7;                     { bits 10..8 }
          unit: 0..15;                    { bits 7..4 }
          unused_3_0: 0..15);             { bits 3..0 }
  end;
  disk_$mnt_flags_t = packed record
    mounted: boolean;                     { bit 15 }
    logical: boolean;                     { bit 14 }
    dev_not_neg: boolean;                 { bit 13 }
    write_protected: boolean;             { bit 12 }
    dev_bit_11: boolean;                  { bit 11 }
    dev_bit_13: boolean;                  { bit 10 }
    dev_bit_9: boolean;                   { bit 9 }
    unused_8_0: 0..511;                   { bits 8..0 }
  end;
  disk_$mnt_info_t = record
    vol_start: linteger;                  { 0x00 }
    vol_end: linteger;                    { 0x04 }
    dev_type: pinteger;                   { 0x08 }
    unit_id: pinteger;                    { 0x0A }
    bat_step: pinteger;                   { 0x0C }
    sectors_per_track: pinteger;          { 0x0E }
    heads: pinteger;                      { 0x10 }
    sectors_per_block: pinteger;          { 0x12 }
    n_partitions: pinteger;               { 0x14 }
    part_info: array[1..8] of disk_$part_info_t;   { 0x16 }
    interleave: pinteger;                 { 0x26 }
    flags: disk_$mnt_flags_t;             { 0x28 }
  end;

{ The third unit's globals, in map order.  The SVC entries
  (DISK_$READ_MFG_BADSPOTS, _$AS_READ, _$AS_WRITE, _$AS_XFER_MULTI,
  _$DIAG_IO, _$UNASSIGN, _$GET_MNT_INFO, _$GET_ERROR_INFO, _$AS_OPTIONS,
  _$PV_ASSIGN_N, _$PV_ASSIGN, _$LV_ASSIGN) take every argument by
  address, the default convention; their bodies copy the value
  parameters into the frame or a register at entry. }

{ AS_IO_SETUP - check and wire the page of an asynchronous transfer. }
function as_io_setup(var vol_idx: integer; buffer: univ_ptr;
                     out status: status_$t): integer32;
  options(extern, val_param);

{ DISK_$READ_MFG_BADSPOTS - read a volume's manufacturer's bad-spot page.
  DISK_$AS_READ - read one block into a page, asynchronously addressed.
  DISK_$AS_WRITE - write one page to a block, asynchronously addressed. }
procedure disk_$read_mfg_badspots(vol_idx: integer; daddr: linteger;
                                  var buffer: univ disk_$page_t;
                                  out status: status_$t);
  extern;
procedure disk_$as_read(vol_idx: integer; daddr: linteger;
                        var buffer: univ disk_$page_t;
                        out info: disk_$info_t; out status: status_$t);
  extern;
procedure disk_$as_write(vol_idx: integer; daddr: linteger;
                         var buffer: univ disk_$page_t;
                         in info: disk_$info_t; out status: status_$t);
  extern;

{ DISK_$AS_XFER_MULTI - transfer up to sixteen pages in one chain. }
procedure disk_$as_xfer_multi(in vol_idx: integer; in count: integer;
                              in op_type: integer;
                              in daddr_array: univ disk_$xfer_daddr_list_t;
                              in info_array: univ disk_$xfer_info_list_t;
                              in buffer_array: univ disk_$xfer_va_list_t;
                              out status_array: univ disk_$xfer_status_list_t;
                              out status: status_$t);
  extern;

{ DISK_$DIAG_IO - a diagnostic transfer of one block. }
procedure disk_$diag_io(in op: integer; in vol_idx: integer;
                        in daddr: linteger; var buffer: univ disk_$page_t;
                        var info: disk_$info_t; out status: status_$t);
  extern;

{ DISK_$UNASSIGN - give up a volume assigned to the calling process.
  DISK_$UNASSIGN_ALL - give up every volume assigned to the process. }
procedure disk_$unassign(in vol_idx: integer; out status: status_$t);
  extern;
procedure disk_$unassign_all;
  extern;

{ DISK_$GET_MNT_INFO - describe a mounted or assigned volume. }
procedure disk_$get_mnt_info(vol_idx: integer; in param_2: integer;
                             var info: disk_$mnt_info_t;
                             out status: status_$t);
  extern;

{ DISK_$GET_ERROR_INFO - hand out the last disk error record. }
procedure disk_$get_error_info(out buffer: disk_$error_info_t);
  extern;

{ DISK_$AS_OPTIONS - set the async options of an assigned volume. }
procedure disk_$as_options(in vol_idx: integer; in options: disk_$as_options_t;
                           out status: status_$t);
  extern;

{ DISK_$PV_ASSIGN_N - assign a physical volume (the flags form).
  DISK_$PV_ASSIGN - assign a physical volume (the older form). }
procedure disk_$pv_assign_n(unit_type: integer; device: integer;
                            unit: integer; flags: integer;
                            out vol_idx: pinteger;
                            var num_blocks: integer32;
                            var sec_per_track: pinteger;
                            var num_heads: pinteger;
                            var pvlabel_info: disk_$pvlabel_buf_t;
                            out status: status_$t);
  extern;
procedure disk_$pv_assign(unit_type: integer; device: integer;
                          unit: integer; out vol_idx: pinteger;
                          var info: integer32;
                          var sec_per_track: pinteger;
                          var num_heads: pinteger;
                          out status: status_$t);
  extern;

{ DISK_$LV_ASSIGN - assign a logical volume of a physical volume. }
function disk_$lv_assign(in vol_idx: integer; in lv_idx: pinteger;
                         out blocks_avail: integer32;
                         out status: status_$t): pinteger;
  extern;

{ DISK_$LVUID_TO_VOLX - the volume index of a mounted logical volume. }
procedure disk_$lvuid_to_volx(lv_uid: uid_$t; out vol_idx: integer;
                              out status: status_$t);
  extern;

{ DISK_IO's operation (its `case op of', entries 0..4, and its compares
  of op with 1, 3, 2, 4): 0 a read
  (DISK_$READ), 1 a write (DISK_$WRITE, DISK_$AS_WRITE), 2 a read
  without the block-header check (DISK_$AS_READ, DISK_$DIAG_IO's read,
  the read-after-write verification), 3 a raw write (DISK_$DIAG_IO's), 4
  the manufacturer's bad-spot read (DISK_$READ_MFG_BADSPOTS; no header
  check either).

  A queue block's operation (disk_$io_req_t's owner_op.op, bits 3..0 of
  +0x1F, which DISK_$DO_IO's drivers dispatch on): 1, 2 and 9 the codes
  DISK_IO hands disk_$map_request (read, write, format); 3 a track
  format (DISK_$FORMAT; FLP_$DO_IO and WIN_$DO_IO call their
  format_track routines for it), 10 a whole-disk format
  (DISK_$FORMAT_WHOLE).  

  DISK_$WRITE_PROTECT's mode (its `case mode of'): set and test.

  No Apollo insert declares any of these. }
const
  disk_$io_read = 0;
  disk_$io_write = 1;
  disk_$io_read_no_check = 2;
  disk_$io_write_raw = 3;
  disk_$io_read_badspots = 4;

  disk_$req_op_read = 1;
  disk_$req_op_write = 2;
  disk_$req_op_format_track = 3;
  disk_$req_op_format = 9;
  disk_$req_op_format_whole = 10;

  disk_$write_protect_set = 0;
  disk_$write_protect_test = 1;
