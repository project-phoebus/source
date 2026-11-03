{ win_scsi/win_scsi.ins.pas - WIN_SCSI_ (the SCSI Winchester disk
  driver) constants, types, variables and routine headings, for the Domain
  Pascal tree.

  The WIN_SCSI_ module (win_scsi/win_scsi.pas), with the part
  win_scsi_disk (base/config.ins.pas).  Apollo's customer insert files of
  SR10.2 declare nothing of it: the names below are the map's, the SCSI
  standard's, or descriptive.  Include base/base.ins.pas, io/io.ins.pas,
  disk/disk.ins.pas and scsi/scsi.ins.pas before it.
}

const
  { The disk statuses disk/disk.ins.pas does not declare (the SR10.2
    status-code database, "OS / disk manager"; its texts in the
    comments; the first three are also in win/win.ins.pas, which this
    module does not include). }
  status_$disk_seek_error = 16#00080015;          { disk seek error }
  status_$unknown_error_status_from_drive = 16#00080023;
  status_$unrecognized_drive_id = 16#00080024;    { unrecognized drive id }
                                        { unknown error status from
                                          drive }
  status_$disk_unit_attention = 16#0008002B;      { unit attention
                                                    presented by device }
  status_$disk_mfg_badspots_not_available = 16#0008002C;
                                        { manufacturing badspot
                                          information not available or
                                          no needed }

  { WIN_SCSI_$DINIT's crash status for a fixed disk that answers neither
    the format device page nor the rigid disk geometry page; the
    database has no text for it. }
  win_scsi_no_geometry = 16#00880037;

  { The controller numbers, 0..8: a target's bus times 8 plus its
    target number (WIN_SCSI_DCTE_0..7 and the units' table). }
  win_scsi_max_ctlr = 8;

  { The commands the driver sends (the SCSI standard's operation
    codes). }
  win_scsi_op_test_unit_ready = 16#00;
  win_scsi_op_request_sense = 16#03;
  win_scsi_op_format_unit = 16#04;
  win_scsi_op_inquiry = 16#12;
  win_scsi_op_mode_select = 16#15;
  win_scsi_op_reserve = 16#16;
  win_scsi_op_release = 16#17;
  win_scsi_op_mode_sense = 16#1A;
  win_scsi_op_start_stop_unit = 16#1B;
  win_scsi_op_prevent_allow = 16#1E;
  win_scsi_op_read_capacity = 16#25;
  win_scsi_op_read10 = 16#28;
  win_scsi_op_write10 = 16#2A;

  { The sense keys the request sense routine maps (the SCSI
    standard's). }
  win_scsi_key_recovered_error = 1;
  win_scsi_key_not_ready = 2;
  win_scsi_key_medium_error = 3;
  win_scsi_key_hardware_error = 4;
  win_scsi_key_illegal_request = 5;
  win_scsi_key_unit_attention = 6;
  win_scsi_key_data_protect = 7;
  win_scsi_key_blank_check = 8;
  win_scsi_key_vendor_unique = 9;

  { The additional sense codes it tells apart (the SCSI standard's). }
  win_scsi_asc_no_seek_complete = 16#02;
  win_scsi_asc_unrecovered_read_error = 16#11;
  win_scsi_asc_positioning_error = 16#15;
  win_scsi_asc_recovered_with_retries = 16#17;
  win_scsi_asc_recovered_with_ecc = 16#18;
  win_scsi_asc_medium_changed = 16#28;

  { The extended sense format's error class. }
  win_scsi_extended_sense = 7;

  { The mode pages it reads and writes. }
  win_scsi_error_recovery_page = 1;
  win_scsi_format_device_page = 3;
  win_scsi_rigid_geometry_page = 4;

  { The timeouts passed to SCSI_$WAIT, in its ticks: a command, a
    START STOP UNIT, a FORMAT UNIT. }
  win_scsi_timeout = 120000;
  win_scsi_start_timeout = 45000;
  win_scsi_format_timeout = 1200000;

  { The disk's block, in bytes: the driver's requests are 1024-byte
    blocks, a device block 512 or 1024 bytes. }
  win_scsi_block_size = 1024;

  { The pages a transfer takes at first (a unit's max_pages, CINIT),
    which DINIT lowers to the SCSI driver's limit. }
  win_scsi_max_pages = 32;

type
  { An 8-bit field of the device's data. }
  win_scsi_byte_t = [byte] 0..255;

  { A command's data buffer: its first byte (passed to SCSI_$DO_COMMAND
    as the buffer). }
  win_scsi_data_ptr_t = ^char;

  { A REQUEST SENSE answer, 18 bytes: the extended sense format.  The
    information bytes 3..6 are a byte-aligned longword at byte 3
    (`[aligned(0)]', which the MC68020 modes let cross two word
    boundaries). }
  win_scsi_sense_t = record
    case integer of
      1: (f: packed record
            valid: boolean;               { 0x00, bit 7 }
            err_class: 0..7;              { 0x00, bits 6..4 }
            err_code: 0..15;              { 0x00, bits 3..0 }
            segment: 0..255;              { 0x01 }
            flags: 0..15;                 { 0x02, bits 7..4 }
            key: 0..15;                   { 0x02, bits 3..0 }
          end);
      2: (b: array[0..17] of char);       { 0x00: byte 12 the additional
                                            sense code }
      3: (unused_00: array[0..2] of char; { 0x00 }
          info: [aligned(0)] integer32);  { 0x03 }
  end;

  { A sense log entry, 10 bytes: the sense key, the additional sense
    code, the valid bit and the information bytes. }
  win_scsi_log_entry_t = record
    key: integer;                         { 0x00 }
    asc: integer;                         { 0x02 }
    valid: boolean;                       { 0x04 }
    info: [aligned(0)] integer32;         { 0x05 }
  end;

  { A logical unit's statistics, 22 bytes (DISK_$GET_STATS's
    disk_$stats_t): the blocks read and written, then seven counts, of
    which the request sense routine keeps four. }
  win_scsi_stats_t = record
    reads: integer32;                     { 0x00 }
    writes: integer32;                    { 0x04 }
    unused_08: pinteger;                  { 0x08 }
    unused_0a: pinteger;                  { 0x0A }
    seek_errors: pinteger;                { 0x0C }
    equip_checks: pinteger;               { 0x0E }
    not_ready: pinteger;                  { 0x10 }
    data_checks: pinteger;                { 0x12 }
    unused_14: pinteger;                  { 0x14 }
  end;

  { A logical unit, 0x4C bytes: its block size and blocks to a disk
    block (from MODE SENSE or READ CAPACITY), the INQUIRY strings, the
    statistics, the error recovery page's length, the last sense
    information and flags. }
  win_scsi_lun_t = record
    block_len: integer32;                 { 0x00 }
    blocks_per: integer32;                { 0x04: device blocks in a
                                            1024-byte block }
    unused_08: integer32;                 { 0x08 }
    vendor: array[1..8] of char;          { 0x0C }
    product: array[1..16] of char;        { 0x14 }
    revision: array[1..4] of char;        { 0x24 }
    stats: win_scsi_stats_t;              { 0x28 }
    page_len: pinteger;                   { 0x3E }
    info: integer32;                      { 0x40: the last sense's
                                            information bytes }
    ansi_version: pinteger;               { 0x44 }
    unused_46: pinteger;                  { 0x46 }
    removable: boolean;                   { 0x48 }
    valid: boolean;                       { 0x49: info is the last
                                            sense's }
    recovered: boolean;                   { 0x4A: the last sense was a
                                            recovered error }
    unused_4b: char;                      { 0x4B }
  end;
  win_scsi_lun_ptr_t = ^win_scsi_lun_t;

  { The unit's data buffer as a MODE SENSE or MODE SELECT parameter
    list: the header, then the block descriptor (when bd_len is 8),
    then the page. }
  win_scsi_mode_hdr_t = record
    data_len: win_scsi_byte_t;            { 0x00 }
    medium: win_scsi_byte_t;              { 0x01 }
    dev_spec: win_scsi_byte_t;            { 0x02 }
    bd_len: win_scsi_byte_t;              { 0x03 }
  end;
  win_scsi_mode_hdr_ptr_t = ^win_scsi_mode_hdr_t;

  { A block descriptor, 8 bytes. }
  win_scsi_block_desc_t = packed record
    density: 0..255;                      { 0x00 }
    blocks: 0..16#FFFFFF;                 { 0x01 }
    unused_04: 0..255;                    { 0x04 }
    block_len: 0..16#FFFFFF;              { 0x05 }
  end;
  win_scsi_block_desc_ptr_t = ^win_scsi_block_desc_t;

  { The error recovery page, 8 bytes: the page code, the length (6),
    the recovery flags, the retry count and the correction span. }
  win_scsi_error_page_t = packed record
    ps: 0..3;                             { 0x00, bits 7..6 }
    code: 0..63;                          { 0x00, bits 5..0 }
    len: 0..255;                          { 0x01 }
    awre: 0..1;                           { 0x02, bit 7 }
    arre: 0..1;                           { 0x02, bit 6 }
    tb: 0..1;                             { 0x02, bit 5 }
    rc: 0..1;                             { 0x02, bit 4 }
    eer: 0..1;                            { 0x02, bit 3 }
    per: 0..1;                            { 0x02, bit 2 }
    dte: 0..1;                            { 0x02, bit 1 }
    dcr: 0..1;                            { 0x02, bit 0 }
    retries: 0..255;                      { 0x03 }
    span: 0..255;                         { 0x04 }
    unused_5: 0..255;                     { 0x05 }
    unused_6: 0..255;                     { 0x06 }
    unused_7: 0..255;                     { 0x07 }
  end;
  win_scsi_error_page_ptr_t = ^win_scsi_error_page_t;

  { The geometry pages, as far as the driver reads them: the format
    device page's sectors per track and bytes per sector (bytes 10..13),
    the rigid disk geometry page's cylinders and heads (bytes 2..5). }
  win_scsi_page_t = record
    case integer of
      1: (geom: packed record
            unused_00: 0..255;            { 0x00 }
            unused_01: 0..255;            { 0x01 }
            cylinders: 0..16#FFFFFF;      { 0x02 }
            heads: 0..255;                { 0x05 }
          end);
      2: (bytes: array[0..9] of win_scsi_byte_t;  { 0x00 }
          sec_per_track: pinteger;        { 0x0A }
          sector_bytes: pinteger);        { 0x0C }
  end;
  win_scsi_page_ptr_t = ^win_scsi_page_t;

  { An INQUIRY answer's first bytes. }
  win_scsi_inquiry_t = packed record
    dev_type: 0..255;                     { 0x00 }
    rmb: boolean;                         { 0x01, bit 7 }
    type_mod: 0..127;                     { 0x01, bits 6..0 }
    iso: 0..3;                            { 0x02, bits 7..6 }
    ecma: 0..7;                           { 0x02, bits 5..3 }
    ansi: 0..7;                           { 0x02, bits 2..0 }
  end;
  win_scsi_inquiry_ptr_t = ^win_scsi_inquiry_t;

  { An INQUIRY answer of 36 bytes: the first bytes, the vendor, the
    product and the revision. }
  win_scsi_inquiry_data_t = record
    case integer of
      1: (f: win_scsi_inquiry_t);         { 0x00 }
      2: (b: array[0..7] of char;         { 0x00 }
          vendor: array[1..8] of char;    { 0x08 }
          product: array[1..16] of char;  { 0x10 }
          revision: array[1..4] of char); { 0x20 }
  end;

  { The registration word CINIT gives DISK_$REGISTER (its unit word). }
  win_scsi_reg_word_t = record
    case integer of
      1: (all: integer);                  { 0x00 }
      2: (bits: set of 0..15);            { 0x00 }
  end;

  { A READ CAPACITY answer: the last block and the block size. }
  win_scsi_capacity_t = record
    last_block: linteger;                 { 0x00 }
    block_len: linteger;                  { 0x04 }
  end;
  win_scsi_capacity_ptr_t = ^win_scsi_capacity_t;

  { The unit's data buffer in words, as MODE SELECT's parameter list is
    cleared. }
  win_scsi_buf_words_t = array[1..128] of integer;
  win_scsi_buf_words_ptr_t = ^win_scsi_buf_words_t;

  { A system device command's data or sense buffer: at most 255 bytes
    are copied, through WIN_SCSI_$DO_SYS_COMMAND's 256-byte buffer. }
  win_scsi_sys_buf_t = array[1..256] of char;

  { A unit, 0x160 bytes: a controller number's target (one logical
    unit, 0).  buf is the target's data buffer, buf_ptr its address
    (CINIT); max_pages the 1024-byte pages a transfer may take; lock the
    DCTE's lock number; ready set by DINIT, cleared by SHUTDOWN. }
  win_scsi_unit_t = record
    buf: array[0..255] of char;           { 0x000 }
    buf_ptr: univ_ptr;                    { 0x100 }
    handle: scsi_$handle_t;               { 0x104 }
    max_pages: integer32;                 { 0x108 }
    lock: integer;                        { 0x10C }
    unused_10e: pinteger;                 { 0x10E }
    luns: array[0..0] of win_scsi_lun_t;  { 0x110 }
    ready: boolean;                       { 0x15C }
    unused_15e: pinteger;                 { 0x15E }
  end;
  win_scsi_unit_ptr_t = ^win_scsi_unit_t;

  { The device flags word WIN_SCSI_$DINIT returns: the low byte the
    disk's size in units of 10 MB, the high byte its class. }
  win_scsi_dev_flags_t = record
    case integer of
      1: (all: pinteger);                 { 0x00 }
      2: (class: win_scsi_byte_t;         { 0x00 }
          size: win_scsi_byte_t);         { 0x01 }
  end;

  { The two words of the label information WIN_SCSI_$DINIT returns:
    zero, then the bytes in a sector. }
  win_scsi_label_info_t = array[0..1] of pinteger;

var
  { WIN_PAGE (map symbol, in the BUFFER_PAGES region): the page a
    single-block transfer is mapped at. }
  win_page: extern array[0..1023] of char;

{ TODO(pascal) MMU's SAU9 headings belong in mmu/mmu.ins.pas

  On the SAU4 and SAU6..SAU9 MMU_$REMOVE takes a virtual address and a
  word (IO_$UNMAP_CSR's calls there: the address, then 0, stepping by
  1024; the SAU9's MMU_$REMOVE reads only the longword).
  mmu/mmu.ins.pas declares the SAU2's MMU_$REMOVE (a page number), which
  its thirty-odd callers use under every configuration: the other form
  needs a part of its own there, with those callers' forms, when MMU is
  translated for those SAUs.  Until then this module declares the three
  MMU headings it calls here and does not include mmu/mmu.ins.pas. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);
procedure mmu_$cache_inhibit_va(va: univ_ptr); options(extern, val_param);

{ ---- The globals' headings, in map order. ---- }

{ WIN_SCSI_$DINIT - the unit initialization entry. }
function win_scsi_$dinit(unit: integer; ctlr: pinteger;
                         var num_blocks: integer32;
                         var sec_per_track: pinteger;
                         var num_heads: pinteger;
                         out label_info: win_scsi_label_info_t;
                         out flags: win_scsi_dev_flags_t): integer32;
  options(extern, val_param);

{ WIN_SCSI_$DO_IO - the driver's I/O entry. }
procedure win_scsi_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                          in param_3: univ integer32; out result: boolean);
  extern;

{ WIN_SCSI_$ERROR_QUE - the error queue entry: the driver has none. }
procedure win_scsi_$error_que;
  extern;

{ WIN_SCSI_$GET_STATS - the statistics entry. }
procedure win_scsi_$get_stats(cnum: pinteger; unit: integer;
                              out stats: win_scsi_stats_t);
  options(extern, val_param);

{ WIN_SCSI_$SHUTDOWN - the shutdown entry. }
procedure win_scsi_$shutdown(ctlr: pinteger; unit: integer);
  options(extern, val_param);

{ WIN_SCSI_$SPIN_DOWN - the spin down entry. }
function win_scsi_$spin_down(in ctlr: pinteger): integer;
  extern;

{ WIN_SCSI_$DO_SYS_COMMAND - run a system device command for the SCSI
  driver. }
procedure win_scsi_$do_sys_command(in bus: integer; in target: integer;
                                   in cdb: scsi_$cdb_t;
                                   var buf: univ win_scsi_sys_buf_t;
                                   in len: linteger; in dir: integer;
                                   out result_status: status_$t;
                                   out scsi_status: integer;
                                   var sense: univ win_scsi_sys_buf_t;
                                   in sense_len: linteger;
                                   out sense_valid: boolean;
                                   out status: status_$t);
  extern;

{ WIN_SCSI_$CINIT - the controller initialization. }
function win_scsi_$cinit(var dcte: dcte_t): integer32;
  extern;
