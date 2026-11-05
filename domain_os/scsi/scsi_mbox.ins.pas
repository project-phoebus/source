{ scsi/scsi_mbox.ins.pas - the mailbox host adapter's SCSI_ driver
  (`scsi_mailbox_ctlr', base/config.ins.pas), for the Domain Pascal tree.

  The host adapter sits on the AT bus with three ports (command and
  status, interrupt status and acknowledge, control).  SCSI_$CINIT
  maps a 1 KB mailbox area and 2 KB of 32-byte command blocks into the
  bus through the I/O map and gives the initialization command with the
  area's bus address.  A command goes in a free slot's block, its bus
  address in the slot's outgoing mailbox, and the start command with
  the slot's number to the command port; the adapter interrupts with the
  number of the incoming mailbox that holds the block's address and its
  completion code (SCSI_$INT).  A device's transfer buffer is mapped
  into an I/O map region of its own (IO_$ALLOC).  The names are
  descriptive, as the map gives none but the variables' and regions'.
  Include scsi/scsi.ins.pas before it.
}

const
  { The command port's commands: the initialization (its nine parameter
    bytes follow), a request for an interrupt when an outgoing mailbox is
    free, a device reset (a second byte names the target, its bit 3 a
    bus reset), and the start of a slot's command block (the two high
    bits 2, the slot's number in the low six). }
  scsi_mb_cmd_initialize = 1;
  scsi_mb_cmd_free_int = 4;
  scsi_mb_cmd_reset_device = 5;
  scsi_mb_cmd_start = 2;

  { The initialization's parameter bytes: the adapter's own target
    (scsi_host_id), its two bus times, a zero, the mailbox area's 3-byte
    bus address, and the counts of outgoing and incoming mailboxes. }
  scsi_mb_bus_on = 16#70;
  scsi_mb_bus_off = 10;
  scsi_mb_mailboxes = 64;

  { The status port's bits: the command port ready, a command
    rejected, the adapter initialized; any of the high four bits after a
    reset is a failure. }
  scsi_mb_stat_ready = 16#40;
  scsi_mb_stat_rejected = 16#20;
  scsi_mb_stat_initialized = 16#10;
  scsi_mb_stat_failed = 16#F0;

  { The control port's values: off; the adapter's and the bus's reset;
    the bus's reset alone; the DMA on; the interrupt and the DMA on.  The
    interrupt status port's acknowledge. }
  scsi_mb_ctl_off = 0;
  scsi_mb_ctl_reset = 3;
  scsi_mb_ctl_bus_reset = 2;
  scsi_mb_ctl_dma = 4;
  scsi_mb_ctl_run = 12;
  scsi_mb_int_ack = 1;

  { An incoming mailbox's completion code: a command block ended (1, 2
    and 4), an outgoing mailbox freed, an unsolicited report of a
    device's (a reset's end). }
  scsi_mb_done = 1;
  scsi_mb_done_error = 2;
  scsi_mb_freed = 3;
  scsi_mb_done_aborted = 4;
  scsi_mb_unsolicited = 7;

  { The incoming mailboxes' first index in the mailbox area, and the
    slots: 64 a bus, of which the command routines take 0..60.  The
    byte an outgoing mailbox holds while its slot is being set up. }
  scsi_mb_in_base = 25;
  scsi_mb_last_slot = 63;
  scsi_mb_last_free_slot = 60;
  scsi_mb_slot_taken = 16#FF;

  { The devices: eight records (SCSI_$TINFO_LIST), a device's number its
    record's index, the bus number times 256 plus the target (the
    handle's low word): bus 0 only. }
  scsi_max_dev = 7;

  { A device record's flags (members of a set of 0..15): a command
    ended that the waiter has not taken (done), the record in use, the
    device a system device, its I/O map region allocated (wired), a
    command with data outstanding (busy).  A slot's: in use. }
  scsi_tf_done = 15;
  scsi_tf_in_use = 14;
  scsi_tf_sys = 13;
  scsi_tf_wired = 12;
  scsi_tf_busy = 11;
  scsi_slot_in_use = 15;

  { An owner of a device that any process may use. }
  scsi_any_owner = 1;

type
  { The adapter's ports (the DCTE's request's CSR page). }
  scsi_mb_regs_t = [device] record
    cmd: [byte] 0..255;                   { 0x00: command; status }
    int: [byte] 0..255;                   { 0x01: interrupt status;
                                            acknowledge }
    ctl: [byte] 0..255;                   { 0x02: control }
  end;
  scsi_mb_regs_ptr_t = ^scsi_mb_regs_t;

  { A mailbox, 4 bytes: the completion code (0 free) and a command
    block's 3-byte bus address. }
  scsi_mbox_t = packed record
    status: 0..255;                       { 0x00 }
    scb: 0..16#FFFFFF;                    { 0x01 }
  end;

  { The mailbox area (SCSI_MAILBOXES), 1 KB: the outgoing mailboxes
    from 0, the incoming ones from scsi_mb_in_base. }
  scsi_mbox_area_t = array[0..255] of scsi_mbox_t;

  { A command block, 32 bytes the adapter reads and writes: its
    operation (0), the target and the logical unit, the command, the
    SCSI status byte and the adapter's error code it returns, the data's
    length and 3-byte bus address, a link address, and the direction
    (dir_in for a transfer from the device). }
  scsi_scb_t = packed record
    op: 0..255;                           { 0x00 }
    target: 0..7;                         { 0x01, bits 7..5 }
    unused_1: 0..3;                       { 0x01, bits 4..3 }
    lun: 0..7;                            { 0x01, bits 2..0 }
    cdb: scsi_$cdb_t;                     { 0x02 }
    status: 0..255;                       { 0x0E }
    vue: 0..255;                          { 0x0F }
    len: 0..16#FFFFFF;                    { 0x10 }
    data: 0..16#FFFFFF;                   { 0x13 }
    link: 0..16#FFFFFF;                   { 0x16 }
    dir_in: boolean;                      { 0x19, bit 7 }
    unused_19: 0..127;                    { 0x19, bits 6..0 }
    unused_1a: array[0..5] of char;       { 0x1A }
  end;
  scsi_scb_ptr_t = ^scsi_scb_t;

  { An unsolicited report's 3 bytes (an incoming mailbox's address
    field): the adapter's error code, the target and the logical unit. }
  scsi_mb_unsol_t = packed record
    case integer of
      1: (all: 0..16#FFFFFF);             { 0x00 }
      2: (code: 0..255;                   { 0x00 }
          target: 0..7;                   { 0x01, bits 7..5 }
          unused_1: 0..3;                 { 0x01, bits 4..3 }
          lun: 0..7;                      { 0x01, bits 2..0 }
          unused_2: 0..255);              { 0x02 }
  end;

  { A slot of a bus, 16 bytes: its command block's bus address, the
    command's id, the device, its own number, its flags. }
  scsi_slot_t = record
    scb_pa: integer32;                    { 0x00 }
    id: integer32;                        { 0x04 }
    dev: integer;                         { 0x08 }
    index: integer;                       { 0x0A }
    flags: set of 0..15;                  { 0x0C }
    unused_0e: integer;                   { 0x0E }
  end;

  { A bus's record (SCSI_$CB), 1072 bytes: the adapter's ports and its
    CSR page's physical address; the command blocks' and the mailbox
    area's bus addresses (the I/O map region SCSI_$CINIT takes); its
    devices set up; its interrupts; the eventcount a freed outgoing
    mailbox advances; the mailboxes the adapter took (64, then 192 once
    initialized); the last interrupt's kind and mailbox; the IO_ unit;
    the I/O map's bus; the slots. }
  scsi_mb_cb_t = record
    regs: scsi_mb_regs_ptr_t;             { 0x000 }
    csr_pa: linteger;                     { 0x004 }
    scb_base: integer32;                  { 0x008 }
    map_base: integer32;                  { 0x00C }
    open_count: integer32;                { 0x010 }
    int_count: integer32;                 { 0x014 }
    ec: ec_$eventcount_t;                 { 0x018 }
    mbox_count: integer;                  { 0x024 }
    int_kind: integer;                    { 0x026 }
    int_mbox: integer;                    { 0x028 }
    unit: io_$unit_num_t;                 { 0x02A }
    map_bus: integer;                     { 0x02C }
    unused_02e: integer;                  { 0x02E }
    slots: array[0..scsi_mb_last_slot] of scsi_slot_t;  { 0x030 }
  end;
  scsi_mb_cb_ptr_t = ^scsi_mb_cb_t;

  { A device's record (SCSI_$TINFO_LIST), 72 bytes: the eventcounts of
    its commands' ends and of its resets' ends; the last command id
    given; the id a waiter waits for; the last ended command's id, SCSI
    status code (scsi_$st_...) and status; its ends; the system device's
    command routine; its number, bus, target and logical unit; its
    owner and the owner's address space; its flags (scsi_tf_...); its
    I/O map region. }
  scsi_tinfo_t = record
    done_ec: ec_$eventcount_t;            { 0x00 }
    reset_ec: ec_$eventcount_t;           { 0x0C }
    next_id: integer32;                   { 0x18 }
    wait_id: integer32;                   { 0x1C }
    last_id: integer32;                   { 0x20 }
    scsi_status: integer32;               { 0x24 }
    status: status_$t;                    { 0x28 }
    done_count: integer32;                { 0x2C }
    sys_proc: scsi_$sys_cmd_proc_t;       { 0x30 }
    dev: [byte] 0..255;                   { 0x34 }
    bus: [byte] 0..255;                   { 0x35 }
    target: [byte] 0..255;                { 0x36 }
    lun: [byte] 0..255;                   { 0x37 }
    owner: pinteger;                      { 0x38 }
    asid: integer;                        { 0x3A }
    flags: set of 0..15;                  { 0x3C }
    unused_3e: integer;                   { 0x3E }
    iova: integer32;                      { 0x40 }
    iova_end: integer32;                  { 0x44 }
  end;
  scsi_tinfo_ptr_t = ^scsi_tinfo_t;

  { A page's owners (SCSI_$PPN_OWNERS): the devices that have it
    wired. }
  scsi_owners_t = set of 0..7;

var
  { SCSI_$TINFO_LIST and SCSI_$CB (map symbols, in SCSI_WIRED_DATA, at
    +0x000 and +0x240 of the block): the devices and the bus. }
  scsi_$tinfo_list: extern array[0..scsi_max_dev] of scsi_tinfo_t;
  scsi_$cb: extern array[0..0] of scsi_mb_cb_t;

  { SCSI_$SPURIOUS_INTS and SCSI_CNTS (map symbols): the completions no
    slot claimed, and a count nothing addresses. }
  scsi_$spurious_ints: extern integer32;
  scsi_cnts: extern pinteger;

  { SCSI_$PPN_OWNERS (map symbol, in the PBU_TABLES region after
    PBU_$PPN_OWNERS, 16#8000 bytes): per physical page from the first
    one (16#8000: memory starts at 32 MB), its owners. }
  scsi_$ppn_owners: extern packed array[16#8000..16#FFFF] of scsi_owners_t;

  { SCSI_MAILBOXES and SCSI_SCBS (map symbols, in the BUFFER_PAGES
    region): the mailbox area and the command blocks, a slot each. }
  scsi_mailboxes: extern scsi_mbox_area_t;
  scsi_scbs: extern array[0..scsi_mb_last_slot] of scsi_scb_t;

  { SCSI_$PROC_START (the first byte of SCSI_WIRED_PROC's code) and
    SCSI_$DATA_END (the first byte after SCSI_WIRED_DATA's block); only
    their addresses are used (MST_$WIRE_AREA). }
  scsi_$proc_start: extern char;
  scsi_$data_end: extern char;

{ SCSI_$CINIT - initialize the SCSI controller: the DCTE's init routine,
  the DCTE by address. }
function scsi_$cinit(var dcte: dcte_t): integer32; extern;

{ SCSI_$INT - handle the host adapter's interrupt. }
function scsi_$int(cb: scsi_mb_cb_ptr_t): boolean;
  options(extern, val_param);
