{ ring/ring_driver.ins.pas - RING_ (the token-ring driver): the controller's
  registers, the ring header, the unit records and the driver's argument
  records, the RING block's objects, and the headings of the RING_ map
  routines, for the Domain Pascal tree.

  A file of its own, not ring/ring.ins.pas: these declarations need
  ec/ec.ins.pas, ml/ml.ins.pas, time/time.ins.pas, uid, pkt/pkt.ins.pas,
  io/io.ins.pas, route/route.ins.pas, sock/sock.ins.pas,
  mac_os/mac_os.ins.pas and ring/ring.ins.pas before it, and
  ring/ring.ins.pas's users include it before some of those.

  The modules are ring/ring.pas (RING), ring/ring_wired.pas (RING_WIRED)
  and ring/ringlog_.pas (RINGLOG_); RING_INTERRUPT's heading stays in
  ring/ring.ins.pas, where SYSBUS finds it.  No customer insert file
  declares these.
}

const
  { The socket a channel the system opens carries. }
  ring_os_socket = 16#E1;

  { The members of a unit's state set (bits 0..2 of the byte at +0x31). }
  ring_unit_started = 0;
  ring_unit_running = 1;
  ring_unit_busy = 2;

  { The transmit status's members (member k of a word set is a bit k mod 8
    on byte 1 - k div 8), which RING_$SENDP sets: ok 15, wack 14, nack
    13, congested 11, delayed 10, retried 9, overrun 8, bus error 7, no
    return 6, biphase 5, not ready 4, ESB 2. }
  ring_sendp_res_ok = 15;
  ring_sendp_res_wack = 14;
  ring_sendp_res_nack = 13;
  ring_sendp_res_congested = 11;
  ring_sendp_res_delayed = 10;
  ring_sendp_res_retried = 9;
  ring_sendp_res_overrun = 8;
  ring_sendp_res_bus_err = 7;
  ring_sendp_res_no_return = 6;
  ring_sendp_res_biphase = 5;
  ring_sendp_res_not_ready = 4;
  ring_sendp_res_esb = 2;

%if ring8_controller %then
  { The controller types (the high byte of its ctlr_id register) the
    controller with buffers of its own comes in, by their memory: 16 KB
    or 128 KB. }
  ring8_ctlr_16k = 54;
  ring8_ctlr_128k = 55;

  { The counters ring_$set_timer and ring_$read_timer address: the first
    chip's three (the received header's and data's byte counts, the
    receive's word limit), the second's three (the transmit's header and
    end word counts, and one no caller names). }
  ring8_cnt_rx_hdr = 0;
  ring8_cnt_rx_data = 1;
  ring8_cnt_rx_limit = 2;
  ring8_cnt_tx_hdr = 3;
  ring8_cnt_tx_end = 4;
  ring8_cnt_b_2 = 5;

  { The number of receive buffers a unit's record has room for. }
  ring8_max_rx_bufs = 24;
%endif

type
  { A byte of the controller read or written as a number (the form of
    pkt/pkt.ins.pas's pkt_$byte_t). }
  ring_$byte_t = [byte] 0..255;

  { A control or status word of the controller, a set of 16.  The
    transmit status RING_$SENDP returns is a word of the same kind
    (above, ring_sendp_res_*). }
  ring_$csr_t = set of 0..15;

  { The controller's registers (at the DCTE's disk_dinit address in
    RING_DCTE): `[device]'.  The transmit mask's byte is the unit's
    mask's low byte; the node id's three bytes are at 0x12, 0x14 and
    0x16, the id at 8.

    A controller that moves its packets itself (`ring_controller_dma')
    has more registers after these: the physical addresses of the
    receive header and data buffers (0x20, 0x24) and of the transmit
    header and data (0x28, 0x2C), each buffer's word count with a second
    word, and three vector registers at 0x40, 0x48 and 0x50
    (`ring_vector_regs').  The words no instruction reaches are the
    unused_ fields. }
  ring_$regs_t = [device] record
    xmit_csr: ring_$csr_t;                { 0x00 }
    rcv_csr: ring_$csr_t;                 { 0x02 }
    tmask: ring_$byte_t;                  { 0x04 }
    unused_05: char;                      { 0x05 }
    mode: ring_$csr_t;                    { 0x06 }
    node_id: linteger;                    { 0x08 }
    unused_0c: array[16#0C..16#11] of char;  { 0x0C }
    id_12: ring_$byte_t;                  { 0x12 }
    unused_13: char;                      { 0x13 }
    id_14: ring_$byte_t;                  { 0x14 }
    unused_15: char;                      { 0x15 }
    id_16: ring_$byte_t;                  { 0x16 }
    unused_17: char;                      { 0x17 }
%if ring_controller_dma %then
    unused_18: array[16#18..16#1F] of char;  { 0x18 }
    rx_hdr_addr: integer32;               { 0x20 }
    rx_data_addr: integer32;              { 0x24 }
    tx_hdr_addr: integer32;               { 0x28 }
    tx_data_addr: integer32;              { 0x2C }
    rx_hdr_cnt: integer;                  { 0x30 }
    rx_hdr_resid: integer;                { 0x32 }
    rx_data_cnt: integer;                 { 0x34 }
    rx_data_resid: integer;               { 0x36 }
    tx_hdr_cnt: integer;                  { 0x38 }
    unused_3a: integer;                   { 0x3A }
    tx_data_cnt: integer;                 { 0x3C }
    tx_data_resid: integer;               { 0x3E }
    vector_40: integer;                   { 0x40 }
    unused_42: array[16#42..16#47] of char;  { 0x42 }
    vector_48: integer;                   { 0x48 }
    unused_4a: array[16#4A..16#4F] of char;  { 0x4A }
    vector_50: integer;                   { 0x50 }
%endif
  end;
  ring_$regs_ptr_t = ^ring_$regs_t;

%if ring8_controller %then
  { The registers of the controller with buffers of its own
    (`ring8_controller'): words in the two CSR windows the DCTE's I/O
    descriptors map, one after the other from the first's csr.va.
    `[device]': every access is the whole word.  The words no routine
    reaches are the unused_ fields.
    - tx_ack, rx_ack: written 1 to acknowledge a finished transmit and
      a received packet; ack_0006, reg_0402, reg_0406 and reg_0806 are
      other words written 1 (at start-up, and reg_0406 and reg_0806 after
      a receive error).
    - clear_error: written 1 to clear the errors the status word keeps.
    - ctlr_id: the controller's type in its high byte (ring8_ctlr_*),
      written 1 at start-up.
    - cmd_ptr, rx_ptr: the controller-memory word addresses of the
      command block and of the receive buffer, written with their bytes
      swapped.
    - status: bit 0 clear is a fault, bit 1 clear a received packet, bit
      2 clear a finished transmit; while bit 15 is clear, bits 8..10 are
      errors it keeps (bit 8 a biphase error); bit 14 is set when the
      ring has the packet.
    - command: written [8] to load the command block, [9] to transmit,
      [9, 10] to force a transmit, [] to stop; bit 4 the transmitter's
      idle, bit 5 the command block's acceptance, bit 7 not ready; bits
      8..15 a finished transmit's outcome.
    - rx_status: a received packet's status.
    - timer_a, timer_b: the counters of two counter-timer chips, each
      with its control word (ring8_cnt_*). }
  ring8_$csr_set_t = set of 0..15;
  ring8_$csr_t = [device] record
    unused_0000: integer;                       { 0x0000 }
    tx_ack: integer;                            { 0x0002 }
    rx_ack: integer;                            { 0x0004 }
    ack_0006: integer;                          { 0x0006 }
    unused_0008: array[4..511] of integer;      { 0x0008 }
    clear_error: integer;                       { 0x0400 }
    reg_0402: integer;                          { 0x0402 }
    unused_0404: integer;                       { 0x0404 }
    reg_0406: integer;                          { 0x0406 }
    unused_0408: array[0..510] of integer;      { 0x0408 }
    reg_0806: integer;                          { 0x0806 }
    unused_0808: array[0..1019] of integer;     { 0x0808 }
    ctlr_id: pinteger;                          { 0x1000 }
    cmd_ptr: pinteger;                          { 0x1002 }
    rx_ptr: pinteger;                           { 0x1004 }
    unused_1006: array[0..508] of integer;      { 0x1006 }
    status: ring8_$csr_set_t;                   { 0x1400 }
    command: ring8_$csr_set_t;                  { 0x1402 }
    rx_status: ring8_$csr_set_t;                { 0x1404 }
    unused_1406: array[0..508] of integer;      { 0x1406 }
    timer_a: array[0..2] of pinteger;           { 0x1800 }
    timer_a_ctl: pinteger;                      { 0x1806 }
    unused_1808: array[0..507] of integer;      { 0x1808 }
    timer_b: array[0..2] of pinteger;           { 0x1C00 }
    timer_b_ctl: pinteger;                      { 0x1C06 }
  end;
  ring8_$csr_ptr_t = ^ring8_$csr_t;

  { The DCTE's disk_dinit with this controller: the unit's I/O
    descriptor (the map's RING1_IO_DESC, RING2_IO_DESC), an
    io_$acquire_rec_t whose first longword holds the address of the
    second window's descriptor. }
  ring8_$io_desc_ptr_t = ^io_$acquire_rec_t;

  { A receive buffer of the controller's memory, 24 bytes, a unit's
    rx_bufs element: the header page it is copied into (its physical
    and virtual addresses, from NETBUF_$GET_HDR), its word address in
    the controller's memory, the received lengths (the header's 4 more
    than its counter's, the data's 1 more), the controller's receive
    and status words for it, and three flags: the header has been
    copied out, the buffer holds a packet the receive process has not
    taken, the controller has been given it. }
  ring8_$rx_buf_t = record
    hdr_pa: integer32;                    { 0x00 }
    hdr_va: integer32;                    { 0x04 }
    ctlr_addr: pinteger;                  { 0x08 }
    hdr_len: pinteger;                    { 0x0A }
    data_len: pinteger;                   { 0x0C }
    rx_status: ring8_$csr_set_t;          { 0x0E }
    status: ring8_$csr_set_t;             { 0x10 }
    copied: boolean;                      { 0x12 }
    full: boolean;                        { 0x13 }
    armed: boolean;                       { 0x14 }
    unused_15: char;                      { 0x15 }
    unused_16: integer;                   { 0x16 }
  end;
  ring8_$rx_buf_ptr_t = ^ring8_$rx_buf_t;

  { A unit's command block (RING_$CCB's element, 8 bytes): the node id,
    the mode (8 in the congestion mode) and the transmit mask.  The
    controller is given its own form of it (ring_$set_ccb). }
  ring8_$ccb_t = record
    node: linteger;                       { 0x00 }
    mode: integer;                        { 0x04 }
    tmask: pinteger;                      { 0x06 }
  end;

  { A controller type's parameters, 12 bytes (ring_$init_internal's
    table): the controller's memory and a buffer's size in words, the
    largest data a packet carries in words, and whether the memory is
    mapped into the I/O space (IO_$ALLOC).  The word at 8 and the last
    byte nothing reads. }
  ring8_$ctlr_param_t = record
    mem_words: integer32;                 { 0x00 }
    buf_words: pinteger;                  { 0x04 }
    max_data_words: integer;              { 0x06 }
    unused_08: integer;                   { 0x08 }
    map_mem: boolean;                     { 0x0A }
    unused_0b: char;                      { 0x0B }
  end;

  { An entry of the 12 that follow that table in ring_$init_internal's
    block, 12 bytes: nothing reads them. }
  ring8_$unused_entry_t = record
    l_00: integer32;                      { 0x00 }
    l_04: integer32;                      { 0x04 }
    w_08: integer;                        { 0x08 }
    w_0a: integer;                        { 0x0A }
  end;
%endif

%if nodeid_prom %then
  { The node id PROM (the map's NODE_ID, in the I/O definitions): the
    id's four bytes, most significant first, at +0, +9, +0x11 and
    +0x19.  `[device]'. }
  ring_$nodeid_prom_t = [device] array[0..31] of ring_$byte_t;
%endif

%if nodeid_prom_probe %then
  { The node id as the node id PROM and the first unit's controller
    registers hold it: four words, each with one of the id's bytes in
    its high half, most significant first.  `[device]': each word is
    read whole. }
  ring_$id_words_t = [device] array[0..3] of pinteger;
  ring_$id_words_ptr_t = ^ring_$id_words_t;
%endif

  { A node id read as a longword or as its two words: a variant record
    (ref 3.10.3). }
  ring_$node_t = record
    case integer of
      1: (node: linteger);
      2: (words: array[0..1] of integer);
  end;

  { The ring header, 0x1C bytes: the header of a packet a channel sends or
    receives.  Its first 0x18 bytes are the network header's
    (pkt/pkt.ins.pas pkt_$hdr_t); its longword at 0x18 is the packet
    type a channel opens, which the network header has as its hdr_size,
    route_count and src_sock.  The unnamed bytes are the unused_ fields. }
  ring_$hdr_t = record
    msg_type: ring_$node_t;               { 0x00 }
    flags: pkt_$hdr_flags_t;              { 0x04 }
    src_id: ring_$node_t;                 { 0x08 }
    unused_0c: pkt_$byte_t;               { 0x0C }
    chksum: pkt_$byte_t;                  { 0x0D }
    pkt_class: pkt_$byte_t;               { 0x0E }
    unused_0f: pkt_$byte_t;               { 0x0F }
    hdr_len: pinteger;                    { 0x10 }
    unused_12: integer;                   { 0x12 }
    data_len: pinteger;                   { 0x14 }
    unused_16: integer;                   { 0x16 }
    route_info: linteger;                 { 0x18 }
  end;
  ring_$hdr_ptr_t = ^ring_$hdr_t;

  { A header page as RING_$SVC_WRITE and RING_$SVC_READ use it: the ring
    header and the caller's header bytes after it, at 0x1C.  0x400 bytes
    (network/network.ins.pas network_$page_t's size). }
  ring_$hdr_page_t = record
    hdr: ring_$hdr_t;                     { 0x000 }
    body: array[0..995] of char;          { 0x01C }
  end;
  ring_$hdr_page_ptr_t = ^ring_$hdr_page_t;

  { A channel of a unit, 8 bytes: open, the opener's address space, the
    socket, the version the channel was opened with. }
  ring_$channel_t = record
    flags: boolean;                       { 0x00 }
    unused_01: char;                      { 0x01 }
    asid: integer;                        { 0x02 }
    socket_id: pinteger;                  { 0x04 }
    open_version: integer;                { 0x06 }
  end;

  { A packet-type range, 8 bytes, compared unsigned
    (mac_os/mac_os.ins.pas's mac_os_$pkt_type_range_t has the same
    layout). }
  ring_$pkt_range_t = record
    low: linteger;                        { 0x00 }
    high: linteger;                       { 0x04 }
  end;

  { A packet-type entry, 10 bytes: the range and the owning channel.  The
    table's elements are 12 bytes apart, so each slot holds an entry and
    a word nothing addresses (below). }
  ring_$pkt_type_t = record
    range: ring_$pkt_range_t;             { 0x00 }
    channel: integer;                     { 0x08 }
  end;
  ring_$pkt_slot_t = record
    entry: ring_$pkt_type_t;              { 0x00 }
    unused_0a: integer;                   { 0x0A }
  end;

  { A unit's packet-type table, from 1 (entry i at unit + 0xA8 + 12 * i). }
  ring_$pkt_table_t = array[1..32] of ring_$pkt_slot_t;

  { A unit's record, RING_$CTL's element: 0x244 bytes, or 0x4A4 with
    the controller with buffers of its own.  The words at +0x46, +0x4A,
    +0x5E, +0xB2 and +0x236 (that form: +0x24A, +0x24E) are where no
    field of the word rules lands: the unused_ fields (the TODO(pascal)
    below).  The state is a set of the byte at +0x31: a set of 0..7
    takes a word outside a packed record (ref 3.9.3), its members in the
    word's second byte, so the word at +0x30.

    From +0x236 the `ring8_controller' form has the controller's type;
    the lock RING_$SENDP holds while it copies a packet into the
    controller and the receive side takes while it copies one out; the
    largest data a packet carries in words; the receive page (the map's
    RING_RCV_PAGE, RING2_RCV_PAGE) that data pages are mapped at for the
    copy, and its page-map entry's address; the buffer the controller
    receives into (rx_index) and the one the receive process takes next
    (rx_next), both from 1; whether the receive has a new buffer to be
    started (rx_restart) and whether it has stopped for want of one
    (rx_stopped); the number of buffers; the word address of the
    transmit area and command block in the controller's memory, after
    the last buffer; and the buffers. }
  ring_$state_t = set of 0..7;
  ring_$unit_t = record
    route_port: route_$port_ptr_t;        { 0x000 }
    rx_wake_ec: ec_$eventcount_t;         { 0x004 }
    tx_ec: ec_$eventcount_t;              { 0x010 }
%if ring8_controller %then
    hw_regs: ring8_$csr_ptr_t;            { 0x01C }
%else
    hw_regs: ring_$regs_ptr_t;            { 0x01C }
%endif
    device_info: dcte_ptr_t;              { 0x020 }
    ready_ec: ec_$eventcount_t;           { 0x024 }
    state_flags: ring_$state_t;           { 0x030 }
    tmask: pinteger;                      { 0x032 }
    tx_exclusion: ml_$exclusion_t;        { 0x034 }
    unused_46: integer;                   { 0x046 }
    open_count: integer;                  { 0x048 }
    unused_4a: integer;                   { 0x04A }
    rx_exclusion: ml_$exclusion_t;        { 0x04C }
    unused_5e: integer;                   { 0x05E }
    initialized: boolean;                 { 0x060 }
    channels: array[1..10] of ring_$channel_t;  { 0x062 }
    unused_b2: integer;                   { 0x0B2 }
    pkt_types: ring_$pkt_table_t;         { 0x0B4 }
    pkt_type_cnt: pinteger;               { 0x234 }
%if ring8_controller %then
    ctlr_type: integer;                   { 0x236 }
    buf_lock: ml_$exclusion_t;            { 0x238 }
    unused_24a: integer;                  { 0x24A }
    max_data_words: integer;              { 0x24C }
    unused_24e: integer;                  { 0x24E }
    rcv_page: univ_ptr;                   { 0x250 }
    rcv_pmape: univ_ptr;                  { 0x254 }
    rx_index: pinteger;                   { 0x258 }
    rx_next: pinteger;                    { 0x25A }
    rx_restart: boolean;                  { 0x25C }
    rx_stopped: boolean;                  { 0x25D }
    rx_buf_cnt: pinteger;                 { 0x25E }
    cmd_addr: integer32;                  { 0x260 }
    rx_bufs: array[1..ring8_max_rx_bufs] of ring8_$rx_buf_t;
                                          { 0x264 }
%else
    unused_236: integer;                  { 0x236 }
    rx_hdr_pa: integer32;                 { 0x238 }
    rx_hdr: integer32;                    { 0x23C }
    rx_data_pa: integer32;                { 0x240 }
%endif
  end;
  ring_$unit_ptr_t = ^ring_$unit_t;

{ TODO(pascal) five words of the unit record no field of the word rules explains

  ring_$unit_t's unused_46, unused_4a, unused_5e, unused_b2 and
  unused_236 (with `ring8_controller', unused_24a and unused_24e) lie
  where no instruction reaches and where the word rules (ref 3.10.5.5)
  put the next field directly; the image puts every object of 4 bytes
  or more at a multiple of 4, and the packet-type table's 10-byte
  entries 12 bytes apart.  Longword alignment of records with longword
  fields would explain all of them, but the kernel is said to be
  compiled under the word rules (no image site of the natural rules is
  known), and the stats record's longwords at +0x2 and at +0x6
  (ring/ring.ins.pas) follow them.  The stand-ins hold the places. }

type
  { The driver record (net_io/net_io.ins.pas net_io_$driver_t's layout,
    0x50 bytes, its names).  Its sixteen entries hold RING routines'
    addresses (RING_$SENDP, RING_$GET_STATS twice, RING_$START,
    RING_$STOP, nil, RING_$PROC2_CLEANUP, RING_$IOCTL, RING_$SVC_OPEN,
    _CLOSE, _IOCTL, _WRITE, _READ, RING_$OPEN_OS, _CLOSE_OS, _SEND_OS).
    Every entry is univ_ptr here: net_io_$driver_t types the five
    entries NET_IO calls, and dpc checks a routine's heading against a
    routine pointer type exactly, so RING's record is a type of its own
    with the same layout. }
  ring_$driver_t = record
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

  { ring_$open_internal's request: the version, the count of ranges and
    the ranges from 1 at +4; answered in place: the EC2 handle and the
    channel.  A variant record. }
  ring_$open_args_t = record
    case integer of
      1: (version: integer;                       { 0x00 }
          count: pinteger;                        { 0x02 }
          types: array[1..16] of ring_$pkt_range_t);  { 0x04 }
      2: (ec2_handle: ec2_$ptr_t;                 { 0x00 }
          channel: integer);                      { 0x04 }
  end;

  { RING_$IOCTL's command, two words: the command and the mask. }
  ring_$ioctl_cmd_t = record
    cmd: integer;                         { 0x00 }
    tmask: pinteger;                      { 0x02 }
  end;

  { RING_$SVC_IOCTL's request: the command (a `case' from 1), the
    channel; for the type commands the version and the count, and the
    ranges from 1 at +8; for the statistics the buffer's address and its
    length.  The reply goes into the command word.  A variant record. }
  ring_$stats_ptr_t = ^ring_$stats_t;
  ring_$svc_ioctl_args_t = record
    cmd: integer;                         { 0x00 }
    channel: pinteger;                    { 0x02 }
    case integer of
      1: (version: integer;                       { 0x04 }
          count: integer;                         { 0x06 }
          ranges: array[1..16] of ring_$pkt_range_t);  { 0x08 }
      2: (buf: ring_$stats_ptr_t;                 { 0x04 }
          buf_len: pinteger);                     { 0x08 }
  end;

  { The header record RING_$SVC_WRITE takes and RING_$SVC_READ fills: the
    packet type, the channel, the header length, the broadcast boolean,
    the destination node. }
  ring_$svc_hdr_t = record
    pkt_type: linteger;                   { 0x00 }
    channel: pinteger;                    { 0x04 }
    hdr_len: pinteger;                    { 0x06 }
    broadcast: boolean;                   { 0x08 }
    unused_09: char;                      { 0x09 }
    unused_0a: integer;                   { 0x0A }
    node: linteger;                       { 0x0C }
  end;

  { An element of a caller's buffer vector, 8 bytes: the address and a
    word length. }
  ring_$iov_t = record
    va: integer32;                        { 0x00 }
    len: pinteger;                        { 0x04 }
    pad_6: integer;                       { 0x06 }
  end;
  ring_$iov_array_t = array[1..16] of ring_$iov_t;

var
%if ring8_controller %then
  { RING_$CCB (map symbol, +0x000 of RING's RING_DATA segment with
    `ring8_controller'): the two units' command blocks, from 0, defined
    by ring/ring.pas. }
  ring_$ccb: extern array[0..1] of ring8_$ccb_t;

%endif
  { RING_$CTL (map symbol, +0x000 of RING's RING_DATA segment, +0x010
    with `ring8_controller'), the two units from 0, defined by
    ring/ring.pas. }
  ring_$ctl: extern array[0..1] of ring_$unit_t;

  { RING_$SCRUB (+0x488, +0x958) and RING_$FROM_ERR (+0x490, +0x960), map
    symbols, a longword per unit from 0: with `ring8_controller'
    RING_$SENDP counts a unit's error statuses in the second and every
    third in a row in the first; else no instruction addresses them. }
  ring_$scrub: extern array[0..1] of integer32;
  ring_$from_err: extern array[0..1] of integer32;

  { RING_$FORCE_START (+0x568, +0xA3C, map symbol): a clock
    (RING_$SENDP). }
  ring_$force_start: extern time_$clock_t;

%if ring8_controller %then
  { RING_RCV_PAGE and RING2_RCV_PAGE (map symbols without `$', in the
    BUFFER_PAGES region): the pages the two units map a received
    packet's data pages at, one after the other, to copy them out of the
    controller.  Only their addresses are used. }
  ring_rcv_page: extern array[1..1024] of char;
  ring2_rcv_page: extern array[1..1024] of char;

%endif

%if nodeid_prom %then
  { NODE_ID (map symbol of the I/O definitions, without `$'): the node
    id PROM. }
  node_id: extern ring_$nodeid_prom_t;
%endif
%if nodeid_prom_probe %then
  { The node id PROM, in the I/O definitions' page of PIC1 at +0x200; no
    map symbol names it, and RING_$GET_ID alone reads it. }
  node_id_prom: extern ring_$id_words_t;
  { RING2 (map symbol of the I/O definitions, without `$'): the first
    unit's controller registers, whose first four words hold the node
    id. }
  ring2: extern ring_$id_words_t;
%endif

  { RING_PROC_START, RING_PROC_END, RING_DATA_START and RING_DATA_END
    (map markers of size 0): the bounds ring_$wire_driver wires.  Labels
    the build places, of which only the address is used (io/io.ins.pas
    dcte_start's form). }
  ring_proc_start: extern char;
  ring_proc_end: extern char;
  ring_data_start: extern char;
  ring_data_end: extern char;

{ Routine headings, in map order: the RING segments in OS_INIT_PROC and
  in RING_PROC.  The bodies repeat the full headings (ref 7.3.4, Method
  2).  The module-local routines' headings are in ring/ring.pas. }

{ RING_$GET_ID - the node's id from the ring controller's id bytes. }
function ring_$get_id(in cnum: integer): linteger; extern;

{ RING_$INIT - initialize a ring unit from its DCTE. }
function ring_$init(var dcte: dcte_t): integer32; extern;

%if ring8_controller %then
{ RING8_$INT - the ring controller's interrupt, for both units. }
function ring8_$int(dcte: univ_ptr): boolean; options(extern, val_param);
%else
{ RING_$INT - a ring unit's interrupt. }
function ring_$int(var dcte: dcte_t): boolean; extern;
%endif

{ RING_$SEND_NULL - an empty procedure. }
procedure ring_$send_null; extern;

{ RING_$SENDP - send one packet on a ring unit. }
procedure ring_$sendp(var socket: pinteger; hdr_pa: integer32;
                      hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                      in data_pages: univ pkt_$data_pages_t;
                      data_va: integer32; data_len: pinteger;
                      in flags: univ integer;
                      out xmit_status: ring_$csr_t;
                      out status_ret: status_$t);
  options(extern, val_param);

{ RING_$POLL_STICKY_BPHERR - read and clear the ring's sticky biphase
  error. }
function ring_$poll_sticky_bpherr(in dcte: dcte_ptr_t): boolean; extern;

{ HDR_CHKSUM - the ring header's checksum. }
function hdr_chksum(in hdr: univ pkt_$bytes_t; in len: integer): integer;
  extern;

{ RING_$RCV0, RING_$RCV1 - the receive processes of units 0 and 1. }
procedure ring_$rcv0; extern;
procedure ring_$rcv1; extern;

{ RING_$START - bring a ring unit on line. }
procedure ring_$start(in unit: pinteger; out status: status_$t); extern;

{ RING_$KICK_DRIVER - wake both units' receive processes. }
procedure ring_$kick_driver; extern;

{ RING_$SET_TMASK - set both units' transmit masks. }
procedure ring_$set_tmask(in mask: pinteger); extern;

{ RING_$GET_STATS - copy out a unit's statistics. }
procedure ring_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                          max_len: integer; out length_ret: integer;
                          out status_ret: status_$t);
  options(extern, val_param);

{ RING_$STOP - take a ring unit off line. }
procedure ring_$stop(in unit: pinteger; out status: status_$t); extern;

{ RING_$PROC2_CLEANUP - close every channel an address space holds. }
procedure ring_$proc2_cleanup(var socket: pinteger; asid: integer);
  options(extern, val_param);

{ RING_$IOCTL - a unit's control request: set the transmit mask. }
procedure ring_$ioctl(var unit: pinteger; var cmd: ring_$ioctl_cmd_t;
                      reserved: integer; var param4: univ integer32;
                      out status: status_$t);
  options(extern, val_param);

{ RING_$SVC_OPEN - open a channel for a user (the driver's svc_open).
  RING_$SVC_CLOSE - close a channel (the driver's svc_close). }
procedure ring_$svc_open(var unit: pinteger; var args: ring_$open_args_t;
                         unused3: integer; var unused4: univ integer32;
                         out status: status_$t);
  options(extern, val_param);
procedure ring_$svc_close(var unit: pinteger; var channel: pinteger;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(extern, val_param);

{ RING_$SVC_WRITE - send a packet on a channel (the driver's svc_write).
  RING_$SVC_READ - take a packet from a channel (the driver's svc_read).
  RING_$SVC_IOCTL - a channel's control request (the driver's svc_ioctl). }
procedure ring_$svc_write(var unit: pinteger; var hdr: ring_$svc_hdr_t;
                          unused4: integer; var unused5: univ integer32;
                          var iov: univ ring_$iov_array_t; iov_cnt: integer;
                          out result: integer; out status: status_$t);
  options(extern, val_param);
procedure ring_$svc_read(var unit: pinteger; var hdr: ring_$svc_hdr_t;
                         unused4: integer; var unused5: univ integer32;
                         var iov: univ ring_$iov_array_t; iov_cnt: integer;
                         out len_out: integer; out status: status_$t);
  options(extern, val_param);
procedure ring_$svc_ioctl(var unit: pinteger;
                          var args: ring_$svc_ioctl_args_t;
                          param4: integer; var param5: univ integer32;
                          out status: status_$t);
  options(extern, val_param);

{ RING_$OPEN_OS - open a channel for MAC_OS (the driver's open_os).
  RING_$CLOSE_OS - close a channel MAC_OS opened (the driver's close_os).
  RING_$SEND_OS - send a MAC_OS packet on a channel (the driver's
  send_os). }
procedure ring_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                        out status: status_$t);
  options(extern, val_param);
procedure ring_$close_os(line: pinteger; var callback_data: integer;
                         out status: status_$t);
  options(extern, val_param);
procedure ring_$send_os(line: integer; var callback_data: integer;
                        var pkt: mac_os_$send_pkt_t;
                        out bytes_sent: integer; out status: status_$t);
  options(extern, val_param);

%if ring8_controller %then
{ RING_ASM (a data segment of RING_DATA holding code, hand assembly):
  the copies between the host and the controller's memory, through the
  controller's registers.  The arguments off the stack: the registers by
  address, the word address in the controller's memory, the host
  address and the count of words. }

{ RING_$RB_FROM - copy words out of the controller's memory. }
procedure ring_$rb_from(var regs: ring8_$csr_t; ctlr_addr: pinteger;
                        host: univ_ptr; nwords: integer);
  options(extern, val_param);

{ RING_$RB_TO - copy words into the controller's memory. }
procedure ring_$rb_to(var regs: ring8_$csr_t; ctlr_addr: pinteger;
                      host: univ_ptr; nwords: integer);
  options(extern, val_param);
%endif
