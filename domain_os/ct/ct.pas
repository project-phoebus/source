{ ct/ct.pas - the CT module, the cartridge tape driver.

  Image addresses:
    sau5  0x00E8CFEC  CT data (.DATA, 0xD18 bytes)
    sau6  0x7809FCEC  CT data (.DATA, 0xD64 bytes)
    sau7  0x3C4ADE34  CT data (.DATA, 0x15B8 bytes)
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

  - Both drivers (`ct_scsi' with `ct_qic02' and `ct_atbus_qic02'), on
    the SAU7: the CT code segment in .TEXT (0x2684 bytes: the SCSI
    driver's nine module-local routines and SCSI_WAIT, the AT bus
    driver's module-local routines, CT_WAIT, RESET_DRIVE and DO_CTL_CMD,
    the globals CT_$ACQUIRE .. CT_$WRITE with the SCSI driver's nested
    routines, and CT_$INT), the one in OS_INIT_PROC (0xE4 bytes,
    CT_$CINIT), and the data segment (0x15B8 bytes, below).  A global
    runs the SCSI driver's code for a drive CT_$ACQUIRE found on the bus
    (ct_scsi_state), the AT bus adapter's QIC-02 code otherwise;
    CT_$CINIT probes the adapter only when the SCSI controller is
    absent.  The adapter's DMA goes through the AT bus's I/O map
    (`ct_iomap').

  - The QIC-02 driver of the turbo boards (`ct_qic02' with
    `ct_vectored_ctlr' and `win6_ct6_board'), on the SAU6: the CT code
    segment in .TEXT (0x1464 bytes: the QIC-02 driver's module-local
    routines with ct6_map_cmd and ct6_decode_status after
    ct_check_unit, CT_WAIT, RESET_DRIVE, DO_CTL_CMD, ct_transfer, and
    CT_$ACQUIRE .. CT_$INT with CT6_$INT after CT_$ACQUIRE), the one in
    OS_INIT_PROC (0x174 bytes, CT_$CINIT and CT6_$CINIT), and the data
    segment (0xD64 bytes, below).  The controller interrupts on its
    DCTE's vector; when CT6_$CINIT found the second board (ct6_page),
    the globals drive the tape through its controller's command blocks
    instead (the declarations below).

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
    +0xD14  ct_xfer_count    the commands DO_CTL_CMD gave
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

  With the second board (the SAU6) the block is the QIC-02 one's to
  +0xCF4, then:

    +0xCF8  ct6_page         the second board's page, nil without it
    +0xCFC  ct_regs .. ct_word_cfc  as above, 4 bytes on
    +0xD02  ct6_cmd_map      16 entries: the driver's commands and the
                               second controller's operations
    +0xD42  ct_area_count .. ct_dstat  as above, 0x44 bytes on
    +0xD54  ct6_resid        the finished chain's blocks from the
                               failed one on
    +0xD56  ct6_status       the failed block's status word
    +0xD58  ct_cstat .. ct_busy  as above, 0x48 bytes on
    +0xD60  ct_eot_seen      the end of tape was reported once
    +0xD62  ct6_loading      a load command is outstanding

  With both drivers (the SAU7) the block holds both forms' variables in
  one order: the SCSI driver's command blocks and answers (+0x000 ..
  +0x051), ct_ec at +0x058, the wired page lists from +0x068 as on the
  SAU9, the transfer's page numbers for the I/O map at +0xCB8
  (ct_io_ppns, `ct_iomap'), the SCSI driver's statuses and handle from
  +0x14B8, the status table at +0x14CC, ct_wait_value and ct_dcte, the
  adapter's ct_residue and ct_regs, the SCSI driver's words to
  ct_scsi_state at +0x1572 (the slot of the other forms' ct_word_cfc),
  ct_area_count .. ct_owner, the totals and ct_dstat, ct_xfer_count at
  +0x1586 (the commands DO_CTL_CMD gave, or the SCSI command's count),
  the adapter's words to ct_pbu_unit, the SCSI driver's two flags, the
  three shared booleans, and the adapter's booleans and clocks from
  +0x159E.

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
%if ct_iomap %then
%include 'iomap/iomap.ins.pas';
%endif
%if ct_vectored_ctlr or (ct_qic02 and win6_ct6_board) %then
%include 'sysbus/sysbus.ins.pas';
%endif
%if ct_qic02 and win6_ct6_board %then
%include 'disk/disk.ins.pas';
%include 'win/win.ins.pas';
%endif
%endif
%include 'ct/ct.ins.pas';

%if ct_qic02 and win6_ct6_board %then
{ ---- The tape on the second board's controller (`win6_ct6_board',
  base/config.ins.pas: the SAU6).  The WIN6 page the WIN6_ driver uses
  (win/win.ins.pas) holds
  the tape's commands in its command blocks too: the driver takes a
  chain of blocks (WIN6_$GET_IOPBS), fills them, and starts the chain
  through the tape's start mailbox; CT6_$INT takes the finished chain
  from the tape's completion mailbox and gives the blocks back
  (WIN6_$RTN_IOPBS). ---- }

const
  { 16#8028000C: "unexpected ct interrupt" (16#0028000C, stcode.db.10.2)
    with the fail bit, CT6_$INT's crash when the completion mailbox is
    empty. }
  status_$ct_unexpected_ct_interrupt_fail = 16#8028000C;

  { The number of entries of the table that maps the driver's commands
    to the second controller's operations (ct6_cmd_map). }
  ct6_cmd_map_size = 16;

  { A command block's kind (its state's low two bits) when the driver
    starts a control command, and when CT6_$INT has taken it back. }
  ct6_kind_started = 2;
  ct6_kind_done = 3;

type
  { A command block's status word (+0x04): the controller's answer, its
    severity in the top two bits. }
  ct6_$err_t = packed record
    sev: 0..3;                            { bits 15..14 }
    unused_13_0: 0..16383;                { bits 13..0 }
  end;

  { The operation word (+0x06): the operation byte and the drive. }
  ct6_$opu_t = packed record
    op: [byte] 0..255;                    { 0x06 }
    unused_72: 0..63;                     { 0x07 bits 7..2 }
    unit: 0..3;                           { 0x07 bits 1..0 }
  end;

  { The state word (+0x08): a control command's count and the block's
    kind. }
  ct6_$state_t = packed record
    unused_15_6: 0..1023;                 { bits 15..6 }
    count: 0..15;                         { bits 5..2 }
    kind: 0..3;                           { bits 1..0 }
  end;

  { A command block of the WIN6 page as the tape driver fills it, 32
    bytes: the request (none), the status (-1 until the controller
    answers), the operation and drive, the state, the link to the next
    block of the chain (its offset from the first block), and the
    operation's parameters: a transfer's buffer address (+0x10), and in
    a finished block the drive's status word and the two counts the
    driver totals (+0x14..+0x19). }
  ct6_$iopb_t = record
    req: univ_ptr;                        { 0x00 }
    case integer of
      1: (status: integer;                { 0x04 }
          opu: ct6_$opu_t;                { 0x06 }
          state: ct6_$state_t;            { 0x08 }
          unused_0a: integer32;           { 0x0A }
          link: integer;                  { 0x0E }
          case integer of
            1: (buf: integer32;           { 0x10 }
                l_14: integer32;          { 0x14 }
                l_18: integer32;          { 0x18 }
                l_1c: integer32);         { 0x1C }
            2: (unused_10: integer32;     { 0x10 }
                dstat: integer;           { 0x14 }
                count_16: integer;        { 0x16 }
                count_18: integer));      { 0x18 }
      2: (err: ct6_$err_t);               { 0x04 }
  end;

  { The WIN6 page as the tape driver addresses it, `[device]' as the
    WIN6_ driver's view: the command blocks, the initialization byte
    whose bit 1 CT6_$CINIT clears, the tape's start mailbox (the offset
    of the chain to start) and its completion mailbox (the offset of the
    chain the controller finished). }
  ct6_$page_t = [device] record
    data: array[0..16#5FFF] of [byte] 0..255; { 0x0000 }
    iopbs: array[0..win6_last_iopb] of ct6_$iopb_t; { 0x6000 }
    pad_7f40: array[0..16#78] of [byte] 0..255; { 0x7F40 }
    init_b9: [byte] 0..255;               { 0x7FB9 }
    pad_7fba: array[1..7] of integer;     { 0x7FBA }
    tape_start: win6_$mbox_t;             { 0x7FC8 }
    tape_start_iopb: integer;             { 0x7FCA }
    tape_done: win6_$mbox_t;              { 0x7FCC }
    tape_done_iopb: integer;              { 0x7FCE }
  end;
  ct6_$page_ptr_t = ^ct6_$page_t;

  { An entry of the table that maps one of the driver's commands (the
    ct_cmd_ constants and four codes the driver does not give) to the
    second controller's tape operation byte; -1: none. }
  ct6_$cmd_map_t = record
    cmd: integer;                         { 0x00 }
    op: integer;                          { 0x02 }
  end;

%endif

%if ct_driver %then
var
%if ct_scsi and ct_qic02 %then
  ct_sense_cdb: scsi_$cdb_t;                    { +0x000 }
  unused_cdb_00c: integer32;                    { +0x00C: stand-in }
  ct_cmd_cdb: scsi_$cdb_t;                      { +0x010 }
  unused_cdb_01c: integer32;                    { +0x01C: stand-in }
  ct_sense: ct_sense_t;                         { +0x020 }
  ct_mode: ct_mode_t;                           { +0x04A }
  unused_052: array[1..3] of integer;           { +0x052: stand-in }
  ct_ec: ec_$eventcount_t;                      { +0x058 }
  unused_064: integer32;                        { +0x064: stand-in }
  ct_area_flags: ct_$page_flags_t;              { +0x068 }
  ct_area_pages: array[1..20] of integer32;     { +0x268 }
  ct_io_flags: ct_$page_flags_t;                { +0x2B8 }
  ct_io_pages: ct_$page_list_t;                 { +0x4B8 }
%if ct_iomap %then
  ct_io_ppns: ct_$page_list_t;                  { +0xCB8: the physical
                                                  page numbers of a
                                                  transfer's pages }
%endif
  ct_reset_status: status_$t;                   { +0x14B8 }
  ct_last_status: status_$t;                    { +0x14BC }
  ct_max_xfer: linteger;                        { +0x14C0 }
  ct_req_id: integer32;                         { +0x14C4 }
  ct_handle: scsi_$handle_t;                    { +0x14C8 }
  ct_status_map: array[1..18] of ct_$status_map_t := [  { +0x14CC }
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
  ct_wait_value: integer32;                     { +0x155C }
  ct_dcte: dcte_ptr_t;                          { +0x1560 }
  ct_residue: integer32;                        { +0x1564 }
  ct_regs: ct_$atbus_regs_ptr_t;                { +0x1568 }
  ct_io_state: integer;                         { +0x156C }
  ct_lun: integer;                              { +0x156E }
  ct_max_kb: pinteger;                          { +0x1570 }
  ct_scsi_state: integer;                       { +0x1572 }
  ct_area_count: integer;                       { +0x1574 }
  ct_io_count: pinteger;                        { +0x1576 }
  ct_state: integer;                            { +0x1578 }
  ct_count: integer;                            { +0x157A }
  ct_cmd: integer;                              { +0x157C }
  ct_owner: pinteger;                           { +0x157E }
  ct_total_2e: integer;                         { +0x1580 }
  ct_total_2c: integer;                         { +0x1582 }
  ct_dstat: ct_$stat_t;                         { +0x1584 }
  ct_xfer_count: integer;                       { +0x1586 }
  ct_underruns: ct_$status_bytes_t;             { +0x1588 }
  ct_errors: ct_$status_bytes_t;                { +0x158A }
  ct_dma_channel: integer := 1;                 { +0x158C }
  ct_dma_dir: integer;                          { +0x158E }
  ct_drive_status: ct_$status_bytes_t;          { +0x1590 }
  ct_pbu_unit: integer;                         { +0x1592 }
  ct_reset_pending: boolean;                    { +0x1594 }
  ct_clear_on_ok: boolean;                      { +0x1596 }
  ct_reading: boolean := true;                  { +0x1598 }
  ct_write_ok: boolean;                         { +0x159A }
  ct_busy: boolean;                             { +0x159C }
  ct_eot_seen: boolean;                         { +0x159E }
  ct_dma_active: boolean;                       { +0x15A0 }
  ct_exception: boolean;                        { +0x15A2 }
  ct_restart: boolean := true;                  { +0x15A4 }
  ct_ignore_exception: boolean;                 { +0x15A6 }
  ct_status_delay: time_$clock_t := [high := 0, low := 5];  { +0x15A8 }
  unused_15b0: time_$clock_t := [high := 0, low := 2500];   { +0x15B0 }
%else
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
%if win6_ct6_board %then
  ct6_page: ct6_$page_ptr_t;                    { +0xCF8 }
%endif
  ct_regs: ct_$regs_ptr_t;                      { +0xCF8; +0xCFC }
  ct_word_cfc: integer := 2;                    { +0xCFC; +0xD00 }
%if win6_ct6_board %then
  ct6_cmd_map: array[1..ct6_cmd_map_size] of ct6_$cmd_map_t := [  { +0xD02 }
    [ct_cmd_read, 16#01],                       { 001A 0001 }
    [ct_cmd_write, 16#10],                      { 0018 0010 }
    [ct_cmd_rewind, 16#40],                     { 0015 0040 }
    [ct_cmd_load, 16#04],                       { 0014 0004 }
    [ct_cmd_space_fwd, 16#02],                  { 001B 0002 }
    [ct_cmd_write_filemark, 16#11],             { 0019 0011 }
    [ct_cmd_file_fwd, 16#03],                   { 001D 0003 }
    [ct_cmd_reset, 16#20],                      { 001F 0020 }
    [ct_cmd_erase, 16#12],                      { 0016 0012 }
    [ct_cmd_retension, 16#41],                  { 0017 0041 }
    [ct_cmd_space_rev, -1],                     { 001C FFFF }
    [ct_cmd_file_rev, -1],                      { 001E FFFF }
    [16, -1],                                   { 0010 FFFF }
    [17, -1],                                   { 0011 FFFF }
    [18, -1],                                   { 0012 FFFF }
    [19, -1]];                                  { 0013 FFFF }
%endif
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
  ct_xfer_count: integer;                       { +0xD14 }
  ct_underruns: ct_$status_bytes_t;             { +0xD16 }
  ct_errors: ct_$status_bytes_t;                { +0xD18 }
  ct_dma_channel: integer := 1;                 { +0xD1A }
  ct_dma_dir: integer;                          { +0xD1C }
  ct_drive_status: ct_$status_bytes_t;          { +0xD1E }
  ct_pbu_unit: integer;                         { +0xD20 }
%elseif ct_qic02 %then
  ct_total_2e: integer;                         { +0xD0A; +0xD4E }
  ct_total_2c: integer;                         { +0xD0C; +0xD50 }
  ct_dstat: ct_$stat_t;                         { +0xD0E; +0xD52 }
%if win6_ct6_board %then
  ct6_resid: integer;                           { +0xD54 }
  ct6_status: integer;                          { +0xD56 }
%endif
  ct_cstat: ct_$stat_t;                         { +0xD10; +0xD58 }
%endif
  ct_reading: boolean := true;                  { +0xD12; +0xD84; +0xD22 }
  ct_write_ok: boolean;                         { +0xD14; +0xD86; +0xD24 }
  ct_busy: boolean;                             { +0xD16; +0xD88; +0xD26 }
%if ct_qic02 and win6_ct6_board %then
  ct_eot_seen: boolean;                         { +0xD60 }
  ct6_loading: boolean;                         { +0xD62 }
%endif
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
%endif

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
%if ct_scsi %then
  scsi_wait;
%endif
%if ct_qic02 %then
  ct_wait;
  reset_drive;
  do_ctl_cmd;
%endif
%if ct_driver %then
  ct_$acquire;
%endif
%if ct_qic02 and win6_ct6_board %then
  ct6_$int;
%endif
%if ct_driver %then
  ct_$control;
  ct_$diag;
  ct_$read;
%endif
  ct_$release;
%if ct_driver %then
  ct_$wait;
  ct_$write;
%endif
%if ct_qic02 %then
  ct_$int;
%endif
%if ct_driver %then
  ct_$cinit;
%endif
%if ct_qic02 and win6_ct6_board %then
  ct6_$cinit;
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
%if ct_atbus_qic02 %then
%include 'ct/wait_ready.pas';              { ct_wait_ready }
%include 'ct/status_cmd.pas';              { ct_status_cmd }
%include 'ct/read_status.pas';             { ct_read_status }
%include 'ct/ct_wait.pas';                 { CT_WAIT }
%include 'ct/reset_drive.pas';             { RESET_DRIVE }
%include 'ct/do_ctl_cmd.pas';              { DO_CTL_CMD }
%if ct_iomap %then
%include 'ct/bus_address.pas';             { ct_bus_address }
%endif
%include 'ct/transfer.pas';                { ct_transfer }
%endif
%include 'ct/acquire.pas';                 { CT_$ACQUIRE }
%include 'ct/control.pas';                 { CT_$CONTROL }
%include 'ct/diag.pas';                    { CT_$DIAG }
%include 'ct/read.pas';                    { CT_$READ }
%include 'ct/release.pas';                 { CT_$RELEASE }
%include 'ct/wait.pas';                    { CT_$WAIT }
%include 'ct/write.pas';                   { CT_$WRITE }
%if ct_atbus_qic02 %then
%include 'ct/int.pas';                     { CT_$INT }
%endif

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
%if win6_ct6_board %then
%include 'ct/ct6_map_cmd.pas';             { ct6_map_cmd }
%include 'ct/ct6_decode_status.pas';       { ct6_decode_status }
%endif
%include 'ct/decode_status.pas';           { ct_decode_status }
%include 'ct/ct_wait.pas';                 { CT_WAIT }
%include 'ct/reset_drive.pas';             { RESET_DRIVE }
%include 'ct/do_ctl_cmd.pas';              { DO_CTL_CMD }
%include 'ct/transfer.pas';                { ct_transfer }
%include 'ct/acquire.pas';                 { CT_$ACQUIRE }
%if win6_ct6_board %then
%include 'ct/ct6_int.pas';                 { CT6_$INT }
%endif
%include 'ct/control.pas';                 { CT_$CONTROL }
%include 'ct/diag.pas';                    { CT_$DIAG }
%include 'ct/read.pas';                    { CT_$READ }
%include 'ct/release.pas';                 { CT_$RELEASE }
%include 'ct/wait.pas';                    { CT_$WAIT }
%include 'ct/write.pas';                   { CT_$WRITE }
%include 'ct/int.pas';                     { CT_$INT }

{ ---- OS_INIT_PROC ---- }
%include 'ct/cinit.pas';                   { CT_$CINIT }
%if win6_ct6_board %then
%include 'ct/ct6_cinit.pas';               { CT6_$CINIT }
%endif
%else

{ ---- .TEXT ---- }
%include 'ct/release.pas';                 { CT_$RELEASE }
%endif
