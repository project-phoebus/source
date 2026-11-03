{ iic/iic.ins.pas - IIC_ (the internet interface controller), for the
  Domain Pascal tree.

  What the Pascal files use: the statuses, the driver's records and the
  headings.  No customer insert file declares these.  Include
  base/base.ins.pas before it; with the driver (`iic_driver',
  base/config.ins.pas) also the ec, ml, time, sock, pkt, net_io and
  mac_os insert files.

  Without the driver the entry points are stubs that report "device not
  in system".  With it the controller is a PBU unit (unit 6) with two
  lines, 0 and 1; each line has a record in the IIC_AQWRD_DATA2 section,
  four 1 KB pages of the IIC_$CONTROL_PAG section (its command block and
  its transmit and receive pages), a NET_IO port, and a guardian process
  that starts and stops the line and delivers what it receives.

  The headings are the bodies' (the default convention unless the
  options say otherwise).  The stubs read none of their arguments, so
  the names and types are the driver's.
}

const
  { The statuses, from stcode.db.10.2 ("OS / internet interface
    controller"). }
  status_$iic_dma_multibus_read_timeout = 16#002C0001;
                              { IIC: dma got multibus read timeout error }
  status_$iic_not_initialized = 16#002C0002;
                              { IIC: not initialized prior to operation }
  status_$iic_transmitter_underrun = 16#002C0003;
                              { IIC: transmitter underrun error }
  status_$iic_undocumented_interrupt = 16#002C0004;
                              { IIC: undocumented interrupt raised }
  status_$iic_reset_timed_out = 16#002C0005;
                              { IIC: hardware reset operation timed out }
  status_$iic_self_test_failure = 16#002C0006;
                              { IIC: self test failure reported by board
                                init }
  status_$iic_device_already_acquired = 16#002C0007;
                              { device already acquired }
  status_$iic_device_not_acquired = 16#002C0008;
                              { device not acquired }
  status_$iic_operation_aborted = 16#002C0009;
                              { operation aborted }
  status_$iic_device_not_in_system = 16#002C000A;
                              { device not in system }
  status_$iic_remote_device_not_acquired = 16#002C000B;
                              { remote device not acquired }
  status_$iic_no_expected_packet = 16#002C000C;
                              { could get expected packet from receive
                                socket }
  status_$iic_no_receive_socket = 16#002C000D;
                              { could not allocate receive socket for
                                device }
  status_$iic_no_completion_interrupt = 16#002C000E;
                              { never got expected command completion
                                interrupt }
  status_$iic_wrong_board_revision = 16#002C000F;
                              { wrong board revision level }
  status_$iic_invalid_ccb = 16#002C0010;
                              { invalid command control block }

%if iic_driver %then
  { The controller's PBU unit, and the mode PBU_$RELEASE_INT and the
    sharing word PBU_$ACQUIRE_INT are given. }
  iic_pbu_unit = 6;
  iic_pbu_sharing = 3;

  { The lines. }
  iic_$max_line = 1;

  { A line's state (the record's state word): free; acquired with the
    other end down; acquired with the other end up. }
  iic_line_free = 0;
  iic_line_remote_down = 1;
  iic_line_up = 2;

  { The commands written to the command block's first byte before the
    controller is started (iic_command): initialize, send, set up the
    receive pages, self test. }
  iic_cmd_init = 0;
  iic_cmd_send = 1;
  iic_cmd_receive = 2;
  iic_cmd_self_test = 3;

  { The control register's words: start the command, acknowledge an
    interrupt, reset; and 0. }
  iic_csr_go = 16#86;
  iic_csr_ack = 7;
  iic_csr_reset = 8;

  { The completion codes of a command (the block's second byte). }
  iic_done_undocumented = 0;
  iic_done_ok = 1;
  iic_done_not_initialized = 2;
  iic_done_underrun = 3;
  iic_done_dma_timeout = 7;
  iic_done_invalid_ccb = 8;

  { The interrupt kinds (the block's byte at 0x28): a command finished;
    an event, whose code is the byte at 0x29. }
  iic_int_command = 0;
  iic_int_event = 1;

  { The events: a packet was received; the others are counted. }
  iic_event_received = 1;

  { What the received packet's byte at 0x30 says, and the link message's
    code at 0x31: the other end down (0) or up (1). }
  iic_rx_link = 0;
  iic_rx_message = 1;
  iic_rx_packet = 2;
  iic_link_down = 0;
  iic_link_up = 1;

  { What the transmitted packet's link record's first byte says: a link
    message, a network packet (IIC_$SENDP), a user message (IIC_$SEND). }
  iic_kind_link = 0;
  iic_kind_packet = 1;
  iic_kind_message = 2;

  { The guardian's events, EC_$WAITN's answers (the list's order). }
  iic_ev_start = 1;
  iic_ev_stop = 2;
  iic_ev_down = 3;
  iic_ev_up = 4;
  iic_ev_received = 5;
%endif

type
  { A line's counters: IIC_$STATISTICS returns them as one record, the
    counts then the errors. }
  iic_$counts_t = record
    received: integer32;                  { 0x00 }
    undocumented: integer32;              { 0x04 }
    remote_not_acquired: integer32;       { 0x08 }
    dma_timeouts: integer32;              { 0x0C }
    not_initialized: integer32;           { 0x10 }
    underruns: integer32;                 { 0x14 }
    events: array[1..6] of integer32;     { 0x18 }
  end;
  iic_$errors_t = record
    invalid_ccbs: integer32;              { 0x00 }
    event_8: integer32;                   { 0x04 }
  end;
  iic_$stats_t = record
    counts: iic_$counts_t;                { 0x00 }
    errors: iic_$errors_t;                { 0x30 }
  end;

  { IIC_$SELF_TEST's answer: one word per test. }
  iic_$self_test_t = array[0..13] of integer;

  { The pages of the user message IIC_$SEND sends and IIC_$RECEIVE
    takes. }
  iic_$msg_t = array[1..1024] of char;

%if iic_driver %then
type
  { A byte of the controller's records read as a number. }
  iic_$byte_t = [byte] 0..255;

  { The control register's status byte: member 0, an interrupt is
    pending; 3, a reset is in progress; 5, the self test failed. }
  iic_$csr_bits_t = set of 0..7;

  { A line's control register in the PBU's IIC page, 4 bytes: the
    control word, written whole; its second byte the status; the low 24
    bits of the command block's I/O address in bytes 1..3 (three chars:
    a char array would be word aligned). }
  iic_$csr_t = packed record
    case integer of
      1: (control: integer);                    { 0x00 }
      2: (unused_00: char;                      { 0x00 }
          status: iic_$csr_bits_t);             { 0x01 }
      3: (unused_00b: char;                     { 0x00 }
          addr_hi: char;                        { 0x01 }
          addr_mid: char;                       { 0x02 }
          addr_lo: char);                       { 0x03 }
  end;
  iic_$csr_ptr_t = ^iic_$csr_t;

  { The link record a transmitted packet carries, 8 bytes: who sent it
    and, for a link message, the code. }
  iic_$link_t = record
    kind: iic_$byte_t;                    { 0x00 }
    code: iic_$byte_t;                    { 0x01 }
    unused_02: array[1..3] of integer;    { 0x02 }
  end;

  { A line's command block, the first 0x48 bytes of its first control
    page, shared with the controller. }
  iic_$cb_t = record
    command: iic_$byte_t;                 { 0x00 }
    completion: iic_$byte_t;              { 0x01 }
    unused_02: iic_$byte_t;               { 0x02 }
    unused_03: iic_$byte_t;               { 0x03 }
    tx_hdr_len: integer;                  { 0x04 }
    tx_data_len: pinteger;                { 0x06 }
    tx_link: iic_$link_t;                 { 0x08 }
    xmit_hdr_iova: integer32;             { 0x10 }
    xmit_data_iova: integer32;            { 0x14 }
    rcv_hdr_iova: integer32;              { 0x18 }
    rcv_data_iova: integer32;             { 0x1C }
    hdr_max: integer;                     { 0x20 }
    data_max: integer;                    { 0x22 }
    revision: array[1..4] of char;        { 0x24 }
    int_kind: iic_$byte_t;                { 0x28 }
    event: iic_$byte_t;                   { 0x29 }
    unused_2a: iic_$byte_t;               { 0x2A }
    unused_2b: iic_$byte_t;               { 0x2B }
    rx_hdr_len: pinteger;                 { 0x2C }
    rx_data_len: pinteger;                { 0x2E }
    rx_kind: iic_$byte_t;                 { 0x30 }
    rx_code: iic_$byte_t;                 { 0x31 }
    unused_32: array[1..3] of integer;    { 0x32 }
    self_test: array[0..13] of iic_$byte_t;  { 0x38 }
    unused_46: integer;                   { 0x46 }
  end;

  { The head of a frame's header in a network header buffer, as the
    driver reads and builds it (pkt/pkt.ins.pas pkt_$hdr_t's first
    fields; the longword at 0x18 is the frame type the packet-type
    ranges are compared with, unsigned). }
  iic_$frame_hdr_t = record
    dest_node: linteger;                  { 0x00 }
    flag_bits: pkt_$hdr_flags_t;          { 0x04 }
    src_node: linteger;                   { 0x08 }
    routing_type: pkt_$byte_t;            { 0x0C }
    zero_0d: pkt_$byte_t;                 { 0x0D }
    unused_0e: integer;                   { 0x0E }
    total_len: pinteger;                  { 0x10 }
    unused_12: integer;                   { 0x12 }
    data_len: pinteger;                   { 0x14 }
    unused_16: integer;                   { 0x16 }
    frame_type: linteger;                 { 0x18 }
  end;
  iic_$frame_hdr_ptr_t = ^iic_$frame_hdr_t;

  { A 1 KB control page: the command block, or its 18 longwords. }
  iic_$page_t = record
    case integer of
      1: (cb: iic_$cb_t);                         { 0x000 }
      2: (longs: array[1..18] of integer32);      { 0x000 }
      3: (bytes: array[1..1024] of char);         { 0x000 }
  end;
  iic_$page_ptr_t = ^iic_$page_t;

  iic_$long_ptr_t = ^integer32;
  iic_$pages_ptr_t = ^pkt_$data_pages_t;

  { A longword as its four bytes. }
  iic_$long_bytes_t = record
    case integer of
      1: (all: integer32);
      2: (b: array[1..4] of char);
  end;

  { An open channel of a line: open, the opener's address space. }
  iic_$slot_t = record
    open: boolean;                        { 0x00 }
    asid: integer;                        { 0x02 }
  end;

  { A packet-type entry of a line's table, 10 bytes (the range compared
    unsigned, and the channel), in a 12-byte slot whose last word
    nothing addresses. }
  iic_$range_t = record
    low: linteger;                        { 0x00 }
    high: linteger;                       { 0x04 }
  end;
  iic_$pkt_type_t = record
    range: iic_$range_t;                  { 0x00 }
    slot: integer;                        { 0x08 }
  end;
  iic_$pkt_slot_t = record
    entry: iic_$pkt_type_t;               { 0x00 }
    unused_0a: integer;                   { 0x0A }
  end;
  iic_$pkt_table_t = array[1..10] of iic_$pkt_slot_t;

  { A line's record, 0x1B4 bytes.  The eventcounts: int_ec, the one the
    PBU's interrupt routine advances (the PBU DCTE's ec_ptr, through
    int_ec_ptr, points at one of int_ec, rcv_ec, down_ec, up_ec); the
    guardian's requests start_ec and stop_ec, its answers ready_ec and
    done_ec, and abort_ec, which ends a command's wait.  rcv_data is the
    first of a received frame's data pages (its only one).  The words at
    +0x0F2, +0x102, +0x116 and +0x13A are where no instruction reaches:
    the image puts each object of 4 bytes or more at a multiple of 4
    (as ring/ring_driver.ins.pas's ring_$unit_t). }
  iic_$line_t = record
    int_ec: ec_$eventcount_t;             { 0x000 }
    rcv_ec: ec_$eventcount_t;             { 0x00C }
    down_ec: ec_$eventcount_t;            { 0x018 }
    up_ec: ec_$eventcount_t;              { 0x024 }
    stop_ec: ec_$eventcount_t;            { 0x030 }
    start_ec: ec_$eventcount_t;           { 0x03C }
    abort_ec: ec_$eventcount_t;           { 0x048 }
    ready_ec: ec_$eventcount_t;           { 0x054 }
    done_ec: ec_$eventcount_t;            { 0x060 }
    guardian_status: status_$t;           { 0x06C }
    csr: iic_$csr_ptr_t;                  { 0x070 }
    int_ec_ptr: ^ec_$eventcount_ptr_t;    { 0x074 }
    cb_ppn: integer32;                    { 0x078 }
    iova: integer32;                      { 0x07C }
    rx_hdr_iova: integer32;               { 0x080 }
    rx_data_iova: integer32;              { 0x084 }
    tx_hdr_iova: integer32;               { 0x088 }
    tx_data_iova: integer32;              { 0x08C }
    rx_hdr_pa: integer32;                 { 0x090 }
    rx_hdr_va: integer32;                 { 0x094 }
    rx_data_pa: integer32;                { 0x098 }
    errors: iic_$errors_t;                { 0x09C }
    counts: iic_$counts_t;                { 0x0A4 }
    tx_hdr_pa: integer32;                 { 0x0D4 }
    tx_data_pa: integer32;                { 0x0D8 }
    sock_wait: integer32;                 { 0x0DC }
    rcv_lock: ml_$exclusion_t;            { 0x0E0 }
    unused_0f2: integer;                  { 0x0F2 }
    sock: pinteger;                       { 0x0F4 }
    guardian_pid: pinteger;               { 0x0F6 }
    next_send: time_$clock_t;             { 0x0F8 }
    state: integer;                       { 0x0FE }
    owner: integer;                       { 0x100 }
    unused_102: integer;                  { 0x102 }
    send_lock: ml_$exclusion_t;           { 0x104 }
    unused_116: integer;                  { 0x116 }
    present: boolean;                     { 0x118 }
    pbu_allocated: boolean;               { 0x119 }
    pages_mapped: boolean;                { 0x11A }
    bufs_allocated: boolean;              { 0x11B }
    rcv_hdr: integer32;                   { 0x11C }
    rcv_data: integer32;                  { 0x120 }
    rcv_hdr_len: pinteger;                { 0x124 }
    rcv_data_len: pinteger;               { 0x126 }
    type_count: pinteger;                 { 0x128 }
    slots: array[1..4] of iic_$slot_t;    { 0x12A }
    unused_13a: integer;                  { 0x13A }
    types: iic_$pkt_table_t;              { 0x13C }
  end;
  iic_$line_ptr_t = ^iic_$line_t;

  { The driver's NET_IO record (net_io/net_io.ins.pas net_io_$driver_t's
    layout and names), every entry univ_ptr as ring_$driver_t's. }
  iic_$driver_t = record
    unknown0: pinteger;                   { 0x00 }
    max_data_len: pinteger;               { 0x02 }
    mtu: pinteger;                        { 0x04 }
    unknown6: char;                       { 0x06 }
    flags: char;                          { 0x07 }
    sendp: univ_ptr;                      { 0x08 }
    get_stats: univ_ptr;                  { 0x0C }
    get_stats2: univ_ptr;                 { 0x10 }
    start: univ_ptr;                      { 0x14 }
    stop: univ_ptr;                       { 0x18 }
    detach: univ_ptr;                     { 0x1C }
    proc2_cleanup: univ_ptr;              { 0x20 }
    ioctl: univ_ptr;                      { 0x24 }
    svc_open: univ_ptr;                   { 0x28 }
    svc_close: univ_ptr;                  { 0x2C }
    svc_ioctl: univ_ptr;                  { 0x30 }
    svc_write: univ_ptr;                  { 0x34 }
    svc_read: univ_ptr;                   { 0x38 }
    open_os: univ_ptr;                    { 0x3C }
    close_os: univ_ptr;                   { 0x40 }
    send_os: univ_ptr;                    { 0x44 }
    network_uid: uid_$t;                  { 0x48 }
  end;

  { IIC_$OPEN_OS's request to iic_open_internal: answered with the slot
    in its first word; the count of ranges and the ranges from 1 at +4. }
  iic_$open_args_t = record
    slot: integer;                        { 0x00 }
    count: pinteger;                      { 0x02 }
    types: array[1..6] of iic_$range_t;   { 0x04 }
  end;

  { The PBU's I/O map (pbu/pbu.ins.pas `iomap', a longword per 1 KB
    page of I/O addresses) as the driver writes it: the first word of an
    entry, the page number with the valid bit (16#8000). }
  iic_$iomap_entry_t = record
    page: pinteger;                       { 0x00 }
    unused_02: integer;                   { 0x02 }
  end;
  iic_$iomap_t = array[0..1023] of iic_$iomap_entry_t;
  iic_$iomap_ptr_t = ^iic_$iomap_t;

var
  { IIC_$NETWORK_UID (map symbol in UID_LIST's run of the network-type
    UIDs, uid/m68k/uid_list.s): IIC_$INIT copies it into the driver
    record. }
  iic_$network_uid: extern uid_$t;

  { PBU_IIC_PAGE (map symbol without `$', the PBU's I/O page of the
    controller): a control register per line. }
  pbu_iic_page: extern array[0..iic_$max_line] of iic_$csr_t;

  { The markers of the driver's wired range (map symbols): IIC_$PROC_START
    (the IIC_AQWRD_PROC section's first byte, the module-local
    iic_command), IIC_$PROC_END (the IIC_AQWRD_DATA2 section's start),
    IIC_$DATA_START and IIC_$DATA_END (the IIC_AQWRD_DATA section's
    start and end); only their addresses are used. }
  iic_$proc_start: extern char;
  iic_$proc_end: extern char;
  iic_$data_start: extern char;
  iic_$data_end: extern char;
%endif

{ ---- The module's global routines (iic/iic.pas), in map order. ---- }

{ IIC_$EXISTS - whether a line of the internet interface controller is
  present. }
function iic_$exists(in line: pinteger): boolean; extern;

{ IIC_$INIT - initialize the internet interface controller. }
procedure iic_$init; extern;

%if iic_driver %then
{ CALL_GUARDIAN - pass a request to a line's guardian process and wait
  for its answer. }
procedure call_guardian(in line: pinteger; var request: ec_$eventcount_t;
                        out status: status_$t); extern;
%endif

{ IIC_$ACQUIRE - acquire a line of the internet interface controller. }
procedure iic_$acquire(in line: pinteger; out status: status_$t); extern;

%if iic_driver %then
{ IIC_$NET_START - acquire a line for the network (the driver record's
  start). }
procedure iic_$net_start(in line: pinteger; out status: status_$t);
  extern;
%endif

{ IIC_$RELEASE - release a line of the internet interface controller. }
procedure iic_$release(in line: pinteger; out status: status_$t); extern;

%if iic_driver %then
{ IIC_$$RELEASE - stop a line and set it free (the driver record's
  stop). }
procedure iic_$$release(in line: pinteger; out status: status_$t); extern;
%endif

{ IIC_$SEND - send a message on a line of the internet interface
  controller. }
procedure iic_$send(in line: pinteger; in hdr: univ iic_$msg_t;
                    in hdr_len: pinteger; in data: univ iic_$msg_t;
                    in data_len: pinteger; out status: status_$t);
  extern;

{ IIC_$RECEIVE - receive a message from a line of the internet interface
  controller. }
procedure iic_$receive(in line: pinteger; out hdr: univ iic_$msg_t;
                       in out hdr_len: pinteger; out data: univ iic_$msg_t;
                       out data_len: pinteger; out status: status_$t);
  extern;

{ IIC_$RECEIVE_CHECK - whether a message waits on a line of the internet
  interface controller. }
function iic_$receive_check(in line: pinteger;
                            out status: status_$t): boolean; extern;

{ IIC_$STATISTICS - return a line's counters. }
procedure iic_$statistics(in line: pinteger; out stats: univ iic_$stats_t;
                          out status: status_$t); extern;

%if iic_driver %then
{ IIC_$INT_STATISTICS - return a line's counters for NET_IO (the driver
  record's get_stats and get_stats2). }
procedure iic_$int_statistics(in line: pinteger; stats_buf: univ_ptr;
                              max_len: integer; out length_ret: integer;
                              out status_ret: status_$t);
  options(extern, val_param);
%endif

{ IIC_$SELF_TEST - run a line's self test. }
procedure iic_$self_test(in line: pinteger; out results: iic_$self_test_t;
                         out status: status_$t); extern;

%if iic_driver %then
{ IIC_$PROC2_CLEANUP - release a line an ending address space owns (the
  driver record's proc2_cleanup). }
procedure iic_$proc2_cleanup(in line: pinteger; asid: integer);
  options(extern, val_param);

{ SEND_PACKET - give the controller a packet to send. }
procedure send_packet(in line: pinteger; in hdr_pa: integer32;
                      in hdr_len: integer; in data_pa: integer32;
                      in data_len: pinteger; in link: iic_$link_t;
                      out status: status_$t); extern;

{ INTERRUPTER - the line whose controller interrupts. }
function interrupter(out line: pinteger): boolean; extern;

{ IIC_$INT - the controller's interrupt routine (the PBU unit's
  handler). }
function iic_$int: integer; extern;

{ GUARDIAN_PROCESS - a line's guardian process. }
procedure guardian_process; extern;

{ IIC_$SENDP - send a network packet on a line (the driver record's
  sendp). }
procedure iic_$sendp(in line: pinteger; hdr_pa: integer32;
                     hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                     in data_pages: univ pkt_$data_pages_t;
                     data_va: integer32; data_len: pinteger;
                     in flags: univ integer;
                     out xmit_status: pinteger;
                     out status_ret: status_$t);
  options(extern, val_param);

{ IIC_$OPEN_OS - open a channel for MAC_OS (the driver's open_os). }
procedure iic_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                       out status: status_$t);
  options(extern, val_param);

{ IIC_$CLOSE_OS - close a channel MAC_OS opened (the driver's
  close_os). }
procedure iic_$close_os(line: integer; var callback_data: pinteger;
                        out status: status_$t);
  options(extern, val_param);

{ IIC_$SEND_OS - send a packet for MAC_OS (the driver's send_os). }
procedure iic_$send_os(line: integer; var callback_data: integer;
                       var pkt: mac_os_$send_pkt_t;
                       out bytes_sent: integer; out status: status_$t);
  options(extern, val_param);
%endif
