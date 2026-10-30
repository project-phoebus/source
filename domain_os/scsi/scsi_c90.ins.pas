{ scsi/scsi_c90.ins.pas - the NCR 53C90 driver's own constants, types,
  variables and interrupt routine headings, for the Domain Pascal tree.

  What only the SCSI_ module (scsi/scsi.pas) uses, with `scsi_driver'
  (base/config.ins.pas): the SCSI messages, the 53C90's commands, bus
  phases and registers, the driver's request, target and bus records,
  the map's SCSI_ variables and regions, and the two interrupt routines.
  The interface other modules use is scsi/scsi.ins.pas.  Include
  base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas, io/io.ins.pas and
  scsi/scsi.ins.pas before it. }

%if scsi_driver %then
const
  { SCSI messages (the SCSI standard's codes): message in, the bytes the
    driver sends (IDENTIFY with the disconnect privilege, bit 7 marks an
    IDENTIFY), and the synchronous data transfer request's extended code
    and length. }
  scsi_msg_command_complete = 0;
  scsi_msg_extended = 1;
  scsi_msg_save_data_pointer = 2;
  scsi_msg_restore_pointers = 3;
  scsi_msg_disconnect = 4;
  scsi_msg_initiator_error = 5;
  scsi_msg_abort = 6;
  scsi_msg_reject = 7;
  scsi_msg_nop = 8;
  scsi_msg_parity_error = 9;
  scsi_msg_linked_complete = 10;
  scsi_msg_linked_complete_flag = 11;
  scsi_msg_bus_device_reset = 12;
  scsi_msg_identify = 16#80;
  scsi_msg_identify_disc = 16#C0;
  scsi_xmsg_sdtr = 1;
  scsi_xmsg_sdtr_len = 3;

  { The 53C90's commands (its command register; 16#80 asks for DMA). }
  c90_cmd_flush_fifo = 16#01;
  c90_cmd_transfer_info = 16#10;
  c90_cmd_command_complete = 16#11;       { initiator command complete }
  c90_cmd_msg_accepted = 16#12;
  c90_cmd_set_atn = 16#1A;
  c90_cmd_select_atn = 16#42;
  c90_cmd_select_atn_stop = 16#43;
  c90_cmd_enable_select = 16#44;
  c90_cmd_dma_transfer_info = 16#90;
  c90_cmd_dma_transfer_pad = 16#98;

  { The bus phases (the 53C90's status register, bits 2..0). }
  c90_phase_data_out = 0;
  c90_phase_data_in = 1;
  c90_phase_command = 2;
  c90_phase_status = 3;
  c90_phase_msg_out = 6;
  c90_phase_msg_in = 7;

  { A target's state (scsi_target_t.state), what the next interrupt
    finishes: a data transfer out or in, a selection or the command
    bytes, the status phase, the message out, a message in byte, a
    disconnection, a message in that may continue, a reselection, the
    command's last message. }
  scsi_ts_data_out = 0;
  scsi_ts_data_in = 1;
  scsi_ts_select = 2;
  scsi_ts_status = 3;
  scsi_ts_msg_out = 6;
  scsi_ts_msg_in = 7;
  scsi_ts_disconnected = 8;
  scsi_ts_msg_in_more = 9;
  scsi_ts_reselected = 10;
  scsi_ts_msg_done = 11;

  { The synchronous transfer negotiation (scsi_target_t.sync_state):
    not yet, a request sent, agreed, refused (asynchronous). }
  scsi_sync_none = 0;
  scsi_sync_requested = 1;
  scsi_sync_agreed = 2;
  scsi_sync_async = 3;

  { A message the driver sends out of turn (scsi_target_t.msg_out_state):
    none, to be sent at the next selection, attention raised on the
    connected target, sent. }
  scsi_mo_none = 0;
  scsi_mo_queued = 1;
  scsi_mo_atn = 2;
  scsi_mo_sent = 3;

type
  { ---- The 53C90's registers (the controller's window, one register
    every 4 bytes; the DCTE's I/O descriptor gives its address).  A
    register that reads and writes different things is a variant: the
    read meaning first. ---- }

  { +0x10: the status (read), the destination id (write). }
  c90_status_t = packed record
    int: boolean;                         { bit 7: interrupt pending }
    gross_error: boolean;                 { bit 6 }
    parity_error: boolean;                { bit 5 }
    term_count: boolean;                  { bit 4 }
    valid_group: boolean;                 { bit 3 }
    phase: 0..7;                          { bits 2..0: the bus phase }
  end;
  c90_dest_t = packed record
    unused: 0..31;
    id: 0..7;                             { bits 2..0 }
  end;
  c90_reg10_t = record
    case integer of
      1: (status: [byte] c90_status_t);
      2: (dest: c90_dest_t);
  end;

  { +0x14: the interrupt (read), the select time-out (write). }
  c90_intr_t = packed record
    scsi_reset: boolean;                  { bit 7: bus reset detected }
    illegal_cmd: boolean;                 { bit 6 }
    disconnect: boolean;                  { bit 5 }
    bus_service: boolean;                 { bit 4 }
    func_complete: boolean;               { bit 3 }
    reselected: boolean;                  { bit 2 }
    selected_atn: boolean;                { bit 1 }
    selected: boolean;                    { bit 0 }
  end;
  c90_reg14_t = record
    case integer of
      1: (intr: [byte] c90_intr_t);
      2: (sel_timeout: [byte] 0..255);
  end;

  { +0x18: the sequence step (read), the synchronous period (write). }
  c90_period_t = packed record
    unused: 0..7;
    period: 0..31;                        { bits 4..0 }
  end;
  c90_reg18_t = record
    case integer of
      1: (seq_step: [byte] 0..255);
      2: (sync: c90_period_t);
  end;

  { +0x1C: the FIFO flags (read), the synchronous offset (write). }
  c90_fifo_flags_t = packed record
    unused: 0..7;
    count: 0..31;                         { bits 4..0: bytes in the FIFO }
  end;
  c90_offset_t = packed record
    unused: 0..15;
    offset: 0..15;                        { bits 3..0 }
  end;
  c90_reg1c_t = record
    case integer of
      1: (fifo_flags: c90_fifo_flags_t);
      2: (sync: c90_offset_t);
      3: (fifo_flags_byte: [byte] 0..255);  { the flags as a number }
  end;

  { +0x20: configuration 1. }
  c90_config1_t = packed record
    slow_cable: boolean;                  { bit 7 }
    no_reset_int: boolean;                { bit 6: bus reset not reported }
    parity_test: boolean;                 { bit 5 }
    parity_enable: boolean;               { bit 4 }
    chip_test: boolean;                   { bit 3 }
    bus_id: 0..7;                         { bits 2..0: the controller's id }
  end;

  { +0x24: the clock conversion factor (write). }
  c90_ccf_t = packed record
    unused: 0..31;
    ccf: 0..7;                            { bits 2..0 }
  end;

  { +0x2C: configuration 2, the bits SCSI_$INIT clears. }
  c90_config2_t = packed record
    unused: 0..7;
    bit_4: boolean;
    bit_3: boolean;
    bit_2: boolean;
    bit_1: boolean;
    bit_0: boolean;
  end;

  c90_regs_t = [device] record
    tc_lo: [byte] 0..255;                 { 0x00: transfer count, low }
    unused_01: [byte] 0..255;
    unused_02: integer;
    tc_hi: [byte] 0..255;                 { 0x04: transfer count, high }
    unused_05: [byte] 0..255;
    unused_06: integer;
    fifo: [byte] 0..255;                  { 0x08 }
    unused_09: [byte] 0..255;
    unused_0a: integer;
    cmd: [byte] 0..255;                   { 0x0C: the command }
    unused_0d: [byte] 0..255;
    unused_0e: integer;
    r10: c90_reg10_t;                     { 0x10 }
    unused_12: integer;
    r14: c90_reg14_t;                     { 0x14 }
    unused_16: integer;
    r18: c90_reg18_t;                     { 0x18 }
    unused_1a: integer;
    r1c: c90_reg1c_t;                     { 0x1C }
    unused_1e: integer;
    config1: c90_config1_t;               { 0x20 }
    unused_22: integer;
    ccf: c90_ccf_t;                       { 0x24 }
    unused_26: integer;
    test: [byte] 0..255;                  { 0x28 }
    unused_29: [byte] 0..255;
    unused_2a: integer;
    config2: c90_config2_t;               { 0x2C }
    unused_2e: integer;
    unused_30: array[1..6] of integer32;  { 0x30 }
    dma_port: [byte] 0..255;              { 0x48: the DMA data port }
  end;
  c90_regs_ptr_t = ^c90_regs_t;

  { An I/O descriptor of the DCTE (its +0x34, IO_'s SCSI9_IO_DESC): the
    next descriptor (the DMA interrupt's), the interrupt id and the
    controller's window, as SCSI_$INIT reads them. }
  scsi_io_desc_ptr_t = ^scsi_io_desc_t;
  scsi_io_desc_t = record
    next: scsi_io_desc_ptr_t;             { 0x00 }
    int_id: io_$int_id_t;                 { 0x04 }
    unused_08: integer32;                 { 0x08 }
    regs: c90_regs_ptr_t;                 { 0x0C }
  end;

  { ---- The driver's records. ---- }

  { A message's bytes, one per word (the bus's message in or out, a
    target's last message in). }
  scsi_msg_buf_t = array[0..4] of pinteger;

  { A transfer count as the driver handles it, 4 bytes: cleared, then
    set as a word or from the FIFO flags' count, then read by bytes
    (the controller's two count registers) or as a word. }
  scsi_count_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (hi: integer;                    { 0x00 }
          lo: pinteger);                  { 0x02 }
      3: (b0: [byte] 0..255;              { 0x00 }
          b1: [byte] 0..255;              { 0x01 }
          b2: [byte] 0..255;              { 0x02 }
          b3: [byte] 0..255);             { 0x03 }
      4: (bits: packed record
            unused: 0..16#7FFFFFF;
            fifo_count: 0..31;            { 0x03, bits 4..0 }
          end);
  end;

  { A transfer's pages (a request's list, SCSI_$DO_COMMAND's). }
  scsi_page_list_t = array[1..scsi_max_pages] of integer32;

  { A request, 178 bytes: eleven per bus in the bus's area of the
    SCSI_CDB_PAGE region, on the bus's free list when idle, else on a
    target's pending or done list. }
  scsi_req_ptr_t = ^scsi_req_t;
  scsi_req_t = record
    next: scsi_req_ptr_t;                 { 0x00 }
    cdb_len: integer32;                   { 0x04: 6 or 10 }
    cdb: scsi_$cdb_t;                     { 0x08 }
    buf_va: integer32;                    { 0x14: 0 for physical pages }
    mapped: boolean;                      { 0x18: through SCSI_PAGE }
    ppn_list: boolean;                    { 0x19: pages are page numbers }
    length: pinteger;                     { 0x1A: bytes to go }
    offset: pinteger;                     { 0x1C: in the first page }
    npages: pinteger;                     { 0x1E }
    pages: scsi_page_list_t;              { 0x20 }
    result: scsi_$result_t;               { 0xA4 }
    dir: integer;                         { 0xB0: scsi_$dir_... }
  end;

  { A bus's request area (SCSI_CDB_PAGE, 2048 bytes per bus). }
  scsi_req_area_t = record
    req: array[1..11] of scsi_req_t;      { 0x000 }
    unused_7a6: array[1..90] of char;     { 0x7A6 }
  end;

  { A target, 72 bytes. }
  scsi_target_ptr_t = ^scsi_target_t;
  scsi_target_t = record
    pend_head: scsi_req_ptr_t;            { 0x00: requests not done }
    pend_tail: scsi_req_ptr_t;            { 0x04 }
    done_head: scsi_req_ptr_t;            { 0x08: done, not yet waited }
    done_tail: scsi_req_ptr_t;            { 0x0C }
    sys_cmd_proc: scsi_$sys_cmd_proc_t;   { 0x10 }
    sync_period: integer;                 { 0x14: the 53C90's period }
    sync_offset: integer;                 { 0x16 }
    next_id: integer32;                   { 0x18: the last request's id }
    ec: ec_$eventcount_t;                 { 0x1C: advanced per request done }
    last_msg: scsi_msg_buf_t;             { 0x28: the last message in }
    last_msg_len: integer;                { 0x32 }
    sync_state: integer;                  { 0x34: scsi_sync_... }
    msg_out_state: integer;               { 0x36: scsi_mo_... }
    msg_out_code: pinteger;               { 0x38: its message }
    owner: integer;                       { 0x3A: the owning process }
    owner_asid: integer;                  { 0x3C }
    gen: integer;                         { 0x3E: the handles' generation }
    allocated: boolean;                   { 0x40 }
    active: boolean;                      { 0x41: on the bus }
    sys_device: boolean;                  { 0x42 }
    unused_43: char;                      { 0x43 }
    state: integer;                       { 0x44: scsi_ts_... }
    unused_46: integer;                   { 0x46 }
  end;

  { A bus, 800 bytes (SCSI_$CB). }
  scsi_cb_ptr_t = ^scsi_cb_t;
  scsi_cb_t = record
    regs: c90_regs_ptr_t;                 { 0x000 }
    int_id: io_$int_id_t;                 { 0x004: the controller's }
    dma_int_id: io_$int_id_t;             { 0x008: the DMA port's }
    dma_buf: integer32;                   { 0x00C: the transfer's buffer }
    dma_count: integer32;                 { 0x010: bytes to go }
    dma_done: integer32;                  { 0x014: bytes done }
    dma_dir: integer;                     { 0x018 }
    dma_active: boolean;                  { 0x01A }
    unused_1b: char;                      { 0x01B }
    open_count: integer32;                { 0x01C: targets set up }
    free_count: integer32;                { 0x020: free requests }
    free_head: scsi_req_ptr_t;            { 0x024 }
    free_tail: scsi_req_ptr_t;            { 0x028 }
    target: array[0..7] of scsi_target_t; { 0x02C }
    pmape: array[1..scsi_max_pages] of univ_ptr;
                                        { 0x26C: SCSI_PAGE's map entries }
    free_ec: ec_$eventcount_t;            { 0x2F0: a request was freed }
    max_offset: linteger;                 { 0x2FC: the largest sync offset }
    max_period: linteger;                 { 0x300: in ns }
    min_period: linteger;                 { 0x304: in ns }
    msg: scsi_msg_buf_t;                  { 0x308: a message, in or out }
    msg_count: pinteger;                  { 0x312 }
    msg_index: pinteger;                  { 0x314 }
    clock_ns: pinteger;                   { 0x316: the 53C90's clock period }
    sel_timeout: integer;                 { 0x318: the register's value }
    cur_target: integer;                  { 0x31A: the connected target }
    send_atn: boolean;                    { 0x31C: a message to send }
    disc_pending: boolean;                { 0x31D: a disconnect will end it }
    connected: boolean;                   { 0x31E: a target is on the bus }
    never_selected: boolean;              { 0x31F: no target answered yet }
  end;

  { A page's owners (SCSI_$PPN_OWNERS): the devices (bus * 8 + target)
    that have it wired. }
  scsi_owners_t = set of 0..7;

var
  { SCSI_$CB (map symbol, in SCSI_WIRED_DATA): the buses. }
  scsi_$cb: extern array[0..0] of scsi_cb_t;

  { SCSI_$SPURIOUS_INTS (map symbol, in SCSI_WIRED_DATA): nothing in the
    SAU9 image addresses it. }
  scsi_$spurious_ints: extern integer32;

  { SCSI_CNTS (map symbol, in SCSI_WIRED_DATA): SCSI_$C90_DMA counts its
    transfers that moved nothing in a row; 16#FACE when a bus's last
    free request is taken. }
  scsi_cnts: extern pinteger;

  { SCSI_$PPN_OWNERS (map symbol, in the PBU_TABLES region after
    PBU_$PPN_OWNERS, 16#10000 bytes): per physical page from the first
    one (16#10000: memory starts at 64 MB), its owners. }
  scsi_$ppn_owners: extern packed array[16#10000..16#1FFFF] of
                      scsi_owners_t;

  { SCSI_PAGE and SCSI_CDB_PAGE (map symbols, in the BUFFER_PAGES
    region): the 33 pages a transfer's buffer is mapped at, and the
    request areas. }
  scsi_page: extern array[1..scsi_max_pages, 1..1024] of char;
  scsi_cdb_page: extern array[0..0] of scsi_req_area_t;

  { The markers of the module's wired range (map symbols):
    SCSI_$PROC_START (the module's first byte in SCSI_WIRED_PROC) and
    SCSI_$DATA_END (the first byte after SCSI_WIRED_DATA's block); only
    their addresses are used (MST_$WIRE_AREA). }
  scsi_$proc_start: extern char;
  scsi_$data_end: extern char;

{ SCSI_$C90_INT - handle the 53C90's interrupt. }
function scsi_$c90_int(cb: scsi_cb_ptr_t): boolean;
  options(extern, val_param);

{ SCSI_$C90_DMA - handle the DMA port's interrupt. }
function scsi_$c90_dma(cb: scsi_cb_ptr_t): boolean;
  options(extern, val_param);
%endif
