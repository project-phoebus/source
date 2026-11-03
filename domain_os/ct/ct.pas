{ ct/ct.pas - the CT module, the cartridge tape driver.

  Image addresses:
    sau5  0x00E8CFEC  CT data (.DATA, 0xD18 bytes)
    sau8  0x03C9D43C  CT data (.DATA, 0xD44 bytes)
    sau9  0x3C49D0BC  CT data (.DATA, 0xD8C bytes)

  Configured out on the SAU2..SAU4: the map's CT code segment (.TEXT,
  4 bytes) holds CT_$RELEASE's empty body and the module-end filler.

  With the driver (`ct_driver', base/config.ins.pas), one of two forms:

  - The QIC-02 driver (`ct_qic02'), on the SAU5: the map's CT code
    segment in .TEXT (0xDC0 bytes: five module-local routines, CT_WAIT,
    RESET_DRIVE, DO_CTL_CMD, and CT_$ACQUIRE .. CT_$INT), a CT code
    segment in OS_INIT_PROC (0x74 bytes, CT_$CINIT), and its data
    segment in .DATA (0xD18 bytes).
  - The SCSI tape driver (`ct_scsi'), on the SAU9: the CT code segment
    in .TEXT (0x130C bytes: nine module-local routines, SCSI_WAIT, and
    CT_$ACQUIRE .. CT_$WRITE, four of them with a nested routine), the
    one in OS_INIT_PROC (0x10 bytes, CT_$CINIT, which answers that the
    controller is not in the system), and the data segment (0xD8C
    bytes).  Its globals act only on a drive CT_$ACQUIRE has set up.

  - The QIC-02 driver of the AT bus adapter (`ct_qic02' with
    `ct_atbus_qic02'), on the SAU8: the CT code segment in .TEXT
    (0x136C bytes: six module-local routines, CT_WAIT, RESET_DRIVE,
    DO_CTL_CMD, a seventh module-local routine, ct_transfer, and
    CT_$ACQUIRE .. CT_$INT), the one in OS_INIT_PROC (0xC8 bytes,
    CT_$CINIT), and the data segment (0xD44 bytes, below).  It drives
    the adapter's ports, reads the drive's status bytes after each
    command (ct_read_status), moves each block through the DMA_
    channel ct_dma_channel, and takes its interrupt through a PBU unit.

  See the TODO(sau) below for the SAU6 and SAU7.

  The CT_END_ADDR segment (CT_$PROC_END) is hand assembly,
  ct/m68k/end_addr.s; CT_$PROC_START is a marker at the module's first
  byte.

  The heading names no section; CT_$CINIT is headed
  `[section(os_init_proc, os_init_data)]' and reaches the block by its
  address.

  The data block (zero except the values given), the SAU5's offsets and
  the SAU9's where they differ:

    +0x000  ct_ec            the eventcount CT_$INT advances (QIC-02)
    +0x00C  unused_00c       4 bytes nothing addresses (a stand-in)
    +0x000  ct_sense_cdb     the REQUEST SENSE command (SCSI)
    +0x00C  unused_cdb_00c   4 bytes nothing addresses (a stand-in)
    +0x010  ct_cmd_cdb       the other commands (SCSI)
    +0x01C  unused_cdb_01c   4 bytes nothing addresses (a stand-in)
    +0x020  ct_sense         the REQUEST SENSE answer (SCSI)
    +0x04A  ct_mode          the MODE SENSE and SELECT data (SCSI)
    +0x052  unused_052       22 bytes nothing addresses (a stand-in)

    +0x010  ct_area_flags    the flags of the module's wired pages
                               (+0x068 on the SAU9)
    +0x210  ct_area_pages    the module's wired code and data pages, 20
                               (+0x268)
    +0x260  ct_io_flags      the flags of a transfer's wired pages
                               (+0x2B8)
    +0x460  ct_io_pages      a transfer's wired pages, 512 (+0x4B8)

    +0xCB8  ct_reset_status  SCSI_$RESET_DEVICE's status (SCSI)
    +0xCBC  ct_last_status   the last command's status (SCSI)
    +0xCC0  ct_max_xfer      the largest transfer in bytes (SCSI)
    +0xCC4  ct_req_id        the outstanding command's id (SCSI)
    +0xCC8  ct_handle        the drive's SCSI handle (SCSI)

    +0xC60  ct_status_map    18 entries: the drive status table
                               (+0xCCC; not read by the SCSI driver)
    +0xCF0  ct_wait_value    the value CT_WAIT waits for (+0xD5C)
    +0xCF4  ct_dcte          the controller's DCTE (+0xD60)
    +0xCF8  ct_regs          the controller's window (QIC-02)
    +0xCFC  ct_word_cfc      2, written 2 by CT_$ACQUIRE, not read
                               (QIC-02)
    +0xD64  ct_io_state      the transfer state (SCSI)
    +0xD66  ct_lun           the drive's logical unit, 0 (SCSI)
    +0xD68  ct_max_kb        the largest transfer in KB (SCSI)
    +0xD6A  ct_scsi_state    whether the drive is set up (SCSI)
    +0xCFE  ct_area_count    the module's wired pages' count (+0xD6C)

    +0xD00  ct_io_count      a transfer's wired pages' count (+0xD6E)
    +0xD02  ct_state         the transfer state (+0xD70)
    +0xD04  ct_count         the last command's count (+0xD72)
    +0xD06  ct_cmd           the last command (+0xD74)
    +0xD08  ct_owner         the owning process, 0 for none (+0xD76)
    +0xD0A  ct_total_2e      the totals of the controller's counters
    +0xD0C  ct_total_2c        at 0x2E and 0x2C (CT_$DIAG's counts)
    +0xD0E  ct_dstat         the drive's status word (CT_$INT)
    +0xD10  ct_cstat         the controller's status word (CT_$INT)
    +0xD78  unused_d78       6 bytes nothing addresses (a stand-in)
    +0xD7E  ct_xfer_count    the last command's count (SCSI)
    +0xD80  ct_reset_pending SCSI_WAIT answers ct_reset_status (SCSI)
    +0xD82  ct_clear_on_ok   a success ends the transfer state (SCSI)

    +0xD12  ct_reading       true: the direction is reading (initially)
                               (+0xD84)
    +0xD14  ct_write_ok      the tape is where writing may begin (+0xD86)
    +0xD16  ct_busy          a command is outstanding (+0xD88)

  With the AT bus adapter (the SAU8) the block is the QIC-02 one's to
  +0xCF4, then:

    +0xCF8  ct_residue       the count DMA_$STOP leaves
    +0xCFC  ct_regs          the adapter's ports
    +0xD00  ct_word_cfc      2, written 2 by CT_$ACQUIRE, which sets the
                               PBU unit up while it is 2
    +0xD02  ct_area_count .. ct_owner  as above, 4 bytes on
    +0xD0E  ct_total_2e      the drive's underrun count's total
    +0xD10  ct_total_2c      the drive's data error count's total
    +0xD12  ct_dstat         the drive's status word, as decoded
    +0xD14  ct_blocks        the commands DO_CTL_CMD gave
    +0xD16  ct_underruns     status bytes 4 and 5
    +0xD18  ct_errors        status bytes 2 and 3
    +0xD1A  ct_dma_channel   the DMA_ channel, 1
    +0xD1C  ct_dma_dir       its direction: 0 a read, 1 a write
    +0xD1E  ct_drive_status  status bytes 0 and 1
    +0xD20  ct_pbu_unit      the adapter's PBU unit
    +0xD22  ct_reading .. ct_busy  as above
    +0xD28  ct_eot_seen      the end of tape was reported once
    +0xD2A  ct_dma_active    a transfer's DMA is started
    +0xD2C  ct_exception     CT_$INT saw an exception
    +0xD2E  ct_restart       the next transfer gives its command again
                               (initially true)
    +0xD30  ct_ignore_exception  ct_wait_ready waits for ready alone
    +0xD34  ct_status_delay  ct_read_status's wait, 5 ticks
    +0xD3C  unused_d3c       a clock of 2500 ticks nothing addresses

  The booleans are word aligned, as module variables are.  The SAU9's
  block keeps the QIC-02 driver's status table and initial ct_reading,
  which its code never reads.  The routines live in one fragment file
  each (ct/<name>.pas), in image order.

  Check: tools/pascal_check.sh.
}
module ct;

%include 'base/base.ins.pas';
%if ct_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'io/io.ins.pas';
%include 'os/os.ins.pas';
%if ct_scsi %then
%include 'scsi/scsi.ins.pas';
%endif
%if ct_atbus_qic02 %then
%include 'pbu/pbu.ins.pas';
%include 'dma/dma.ins.pas';
%endif
%endif
%include 'ct/ct.ins.pas';

%if ct_driver %then
{ TODO(sau) the SAU6 and SAU7 CT code

  tools/sau_catalog.py finds every CT routine different on each of the
  SAU5..SAU9.  The SAU6 has the QIC-02 driver's routines in a form of
  its own: it adds a second controller (CT6_$CINIT, CT6_$INT).  The
  SAU7 has both forms: its globals test ct_scsi_state first, run the
  SCSI driver's code (the SAU9's, at other data offsets) for a drive
  that is set up, and the AT bus adapter's QIC-02 code (the SAU8's,
  `ct_atbus_qic02') otherwise.  With both parts enabled this module
  compiles the SCSI form alone, so the SAU7 needs that merge, and the
  SAU6 its own arms. }

var
%if ct_scsi %then
  ct_sense_cdb: scsi_$cdb_t;                    { +0x000 }
  unused_cdb_00c: integer32;                    { +0x00C: stand-in }
  ct_cmd_cdb: scsi_$cdb_t;                      { +0x010 }
  unused_cdb_01c: integer32;                    { +0x01C: stand-in }
  ct_sense: ct_sense_t;                         { +0x020 }
  ct_mode: ct_mode_t;                           { +0x04A }
  unused_052: array[1..11] of integer;          { +0x052: stand-in }
%elseif ct_qic02 %then
  ct_ec: ec_$eventcount_t;                      { +0x000 }
  unused_00c: integer32;                        { +0x00C: stand-in }
%endif
  ct_area_flags: ct_$page_flags_t;              { +0x010; +0x068 }
  ct_area_pages: array[1..20] of integer32;     { +0x210; +0x268 }
  ct_io_flags: ct_$page_flags_t;                { +0x260; +0x2B8 }
  ct_io_pages: ct_$page_list_t;                 { +0x460; +0x4B8 }
%if ct_scsi %then
  ct_reset_status: status_$t;                   { +0xCB8 }
  ct_last_status: status_$t;                    { +0xCBC }
  ct_max_xfer: linteger;                        { +0xCC0 }
  ct_req_id: integer32;                         { +0xCC4 }
  ct_handle: scsi_$handle_t;                    { +0xCC8 }
%endif
  ct_status_map: array[1..18] of ct_$status_map_t := [  { +0xC60; +0xCCC }
    [-16#0089, -16#7000, status_$ct_tape_write_protected],     { FF77 9000 }
    [-16#1001, -16#4000, status_$ct_no_cartridge_in_drive],    { EFFF C000 }
    [-1, -16#1000, status_$ct_drive_does_not_exist],           { FFFF F000 }
    [-1, -16#7800, status_$ct_end_of_tape],                    { FFFF 8800 }
    [-16#1001, -16#7B78, status_$ct_read_write_abort],         { EFFF 8488 }
    [-16#1001, -16#7B70, status_$ct_read_write_abort],         { EFFF 8490 }
    [-16#1001, -16#7C00, status_$ct_read_block_error],         { EFFF 8400 }
    [-16#1001, -16#7A00, status_$ct_read_filler_error],        { EFFF 8600 }
    [-16#1001, -16#7970, status_$ct_read_no_data],             { EFFF 8690 }
    [-16#1001, -16#7960, status_$ct_read_no_data],             { EFFF 86A0 }
    [-16#1001, -16#7160, status_$ct_read_no_data_and_eot],     { EFFF 8EA0 }
    [-16#1017, -16#7958, status_$ct_read_no_data_and_bot],     { EFE9 86A8 }
    [-16#1001, -16#7F00, status_$ct_filemark_detected],        { EFFF 8100 }
    [16#0FF7, 16#00C0, status_$ct_illegal_drive_command],      { 0FF7 00C0 }
    [16#0FF7, 16#0081, status_$ct_tape_power_on_reset],        { 0FF7 0081 }
    [16#0FFF, 16#0088, status_$ct_tape_at_load_point],         { 0FFF 0088 }
    [-1, 0, 0],                                                { FFFF 0000 }
    [-16#1001, -16#7EF0, status_$ct_marginal_block_detected]]; { EFFF 8110 }
  ct_wait_value: integer32;                     { +0xCF0; +0xD5C }
  ct_dcte: dcte_ptr_t;                          { +0xCF4; +0xD60 }
%if ct_scsi %then
  ct_io_state: integer;                         { +0xD64 }
  ct_lun: integer;                              { +0xD66 }
  ct_max_kb: pinteger;                          { +0xD68 }
  ct_scsi_state: integer;                       { +0xD6A }
%elseif ct_atbus_qic02 %then
  ct_residue: integer32;                        { +0xCF8 }
  ct_regs: ct_$atbus_regs_ptr_t;                { +0xCFC }
  ct_word_cfc: integer := 2;                    { +0xD00 }
%elseif ct_qic02 %then
  ct_regs: ct_$regs_ptr_t;                      { +0xCF8 }
  ct_word_cfc: integer := 2;                    { +0xCFC }
%endif
  ct_area_count: integer;                       { +0xCFE; +0xD6C }
  ct_io_count: pinteger;                        { +0xD00; +0xD6E }
  ct_state: integer;                            { +0xD02; +0xD70 }
  ct_count: integer;                            { +0xD04; +0xD72 }
  ct_cmd: integer;                              { +0xD06; +0xD74 }
  ct_owner: pinteger;                           { +0xD08; +0xD76 }
%if ct_scsi %then
  unused_d78: array[1..3] of integer;           { +0xD78: stand-in }
  ct_xfer_count: integer;                       { +0xD7E }
  ct_reset_pending: boolean;                    { +0xD80 }
  ct_clear_on_ok: boolean;                      { +0xD82 }
%elseif ct_atbus_qic02 %then
  ct_total_2e: integer;                         { +0xD0E }
  ct_total_2c: integer;                         { +0xD10 }
  ct_dstat: ct_$stat_t;                         { +0xD12 }
  ct_blocks: integer;                           { +0xD14 }
  ct_underruns: ct_$status_bytes_t;             { +0xD16 }
  ct_errors: ct_$status_bytes_t;                { +0xD18 }
  ct_dma_channel: integer := 1;                 { +0xD1A }
  ct_dma_dir: integer;                          { +0xD1C }
  ct_drive_status: ct_$status_bytes_t;          { +0xD1E }
  ct_pbu_unit: integer;                         { +0xD20 }
%elseif ct_qic02 %then
  ct_total_2e: integer;                         { +0xD0A }
  ct_total_2c: integer;                         { +0xD0C }
  ct_dstat: ct_$stat_t;                         { +0xD0E }
  ct_cstat: ct_$stat_t;                         { +0xD10 }
%endif
  ct_reading: boolean := true;                  { +0xD12; +0xD84; +0xD22 }
  ct_write_ok: boolean;                         { +0xD14; +0xD86; +0xD24 }
  ct_busy: boolean;                             { +0xD16; +0xD88; +0xD26 }
%if ct_atbus_qic02 and not ct_scsi %then
  ct_eot_seen: boolean;                         { +0xD28 }
  ct_dma_active: boolean;                       { +0xD2A }
  ct_exception: boolean;                        { +0xD2C }
  ct_restart: boolean := true;                  { +0xD2E }
  ct_ignore_exception: boolean;                 { +0xD30 }
  ct_status_delay: time_$clock_t := [high := 0, low := 5];  { +0xD34 }
  unused_d3c: time_$clock_t := [high := 0, low := 2500];    { +0xD3C }
%endif
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if ct_scsi %then
  scsi_wait;
%elseif ct_qic02 %then
  ct_wait;
  reset_drive;
  do_ctl_cmd;
%endif
%if ct_driver %then
  ct_$acquire;
  ct_$control;
  ct_$diag;
  ct_$read;
%endif
  ct_$release;
%if ct_driver %then
  ct_$wait;
  ct_$write;
%endif
%if ct_qic02 and not ct_scsi %then
  ct_$int;
%endif
%if ct_driver %then
  ct_$cinit;
%endif

%if ct_scsi %then
{ ---- .TEXT ---- }
%include 'ct/touch_pages.pas';             { ct_touch_pages }
%include 'ct/to_24.pas';                   { ct_to_24 }
%include 'ct/from_24.pas';                 { ct_from_24 }
%include 'ct/init_cdb.pas';                { ct_init_cdb }
%include 'ct/request_sense.pas';           { ct_request_sense }
%include 'ct/scsi_wait.pas';               { SCSI_WAIT }
%include 'ct/scsi_reset.pas';              { ct_scsi_reset }
%include 'ct/scsi_transfer.pas';           { ct_scsi_transfer }
%include 'ct/scsi_control.pas';            { ct_scsi_control }
%include 'ct/unwire_pages.pas';            { ct_unwire_pages }
%include 'ct/check_unit.pas';              { ct_check_unit }
%include 'ct/acquire.pas';                 { CT_$ACQUIRE }
%include 'ct/control.pas';                 { CT_$CONTROL }
%include 'ct/diag.pas';                    { CT_$DIAG }
%include 'ct/read.pas';                    { CT_$READ }
%include 'ct/release.pas';                 { CT_$RELEASE }
%include 'ct/wait.pas';                    { CT_$WAIT }
%include 'ct/write.pas';                   { CT_$WRITE }

{ ---- OS_INIT_PROC ---- }
%include 'ct/cinit.pas';                   { CT_$CINIT }
%elseif ct_atbus_qic02 %then
{ ---- .TEXT ---- }
%include 'ct/touch_pages.pas';             { ct_touch_pages }
%include 'ct/unwire_pages.pas';            { ct_unwire_pages }
%include 'ct/check_unit.pas';              { ct_check_unit }
%include 'ct/wait_ready.pas';              { ct_wait_ready }
%include 'ct/status_cmd.pas';              { ct_status_cmd }
%include 'ct/read_status.pas';             { ct_read_status }
%include 'ct/ct_wait.pas';                 { CT_WAIT }
%include 'ct/reset_drive.pas';             { RESET_DRIVE }
%include 'ct/do_ctl_cmd.pas';              { DO_CTL_CMD }
%include 'ct/transfer.pas';                { ct_transfer }
%include 'ct/acquire.pas';                 { CT_$ACQUIRE }
%include 'ct/control.pas';                 { CT_$CONTROL }
%include 'ct/diag.pas';                    { CT_$DIAG }
%include 'ct/read.pas';                    { CT_$READ }
%include 'ct/release.pas';                 { CT_$RELEASE }
%include 'ct/wait.pas';                    { CT_$WAIT }
%include 'ct/write.pas';                   { CT_$WRITE }
%include 'ct/int.pas';                     { CT_$INT }

{ ---- OS_INIT_PROC ---- }
%include 'ct/cinit.pas';                   { CT_$CINIT }
%elseif ct_qic02 %then
{ ---- .TEXT ---- }
%include 'ct/touch_pages.pas';             { ct_touch_pages }
%include 'ct/unwire_pages.pas';            { ct_unwire_pages }
%include 'ct/check_unit.pas';              { ct_check_unit }
%include 'ct/decode_status.pas';           { ct_decode_status }
%include 'ct/ct_wait.pas';                 { CT_WAIT }
%include 'ct/reset_drive.pas';             { RESET_DRIVE }
%include 'ct/do_ctl_cmd.pas';              { DO_CTL_CMD }
%include 'ct/transfer.pas';                { ct_transfer }
%include 'ct/acquire.pas';                 { CT_$ACQUIRE }
%include 'ct/control.pas';                 { CT_$CONTROL }
%include 'ct/diag.pas';                    { CT_$DIAG }
%include 'ct/read.pas';                    { CT_$READ }
%include 'ct/release.pas';                 { CT_$RELEASE }
%include 'ct/wait.pas';                    { CT_$WAIT }
%include 'ct/write.pas';                   { CT_$WRITE }
%include 'ct/int.pas';                     { CT_$INT }

{ ---- OS_INIT_PROC ---- }
%include 'ct/cinit.pas';                   { CT_$CINIT }
%else

{ ---- .TEXT ---- }
%include 'ct/release.pas';                 { CT_$RELEASE }
%endif
