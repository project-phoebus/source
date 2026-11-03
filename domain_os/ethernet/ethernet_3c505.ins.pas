{ ethernet/ethernet_3c505.ins.pas - the Ethernet driver's own
  declarations: the statuses, the adapter's registers and command
  blocks, the unit record, the driver record, the module's sections and
  the headings of the ETHERNET map routines, for the Domain Pascal tree.

  The driver of the 3Com 3C505 (EtherLink Plus) on the AT bus, as the
  SAU9 (DN2500) has it (`ethernet_driver', base/config.ins.pas).  The
  register and bit names follow 3Com's for the 3C505 (the host control
  register HCR, the adapter status register ASR); the others are
  descriptive.  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas,
  io/io.ins.pas, uid/uid.ins.pas, di/di.ins.pas, mac_os/mac_os.ins.pas
  and xns/xns_idp.ins.pas (xns_$host_t) before it.
}

const
  { The driver's statuses, subsystem 16#2F (stcode.db.10.2's "OS / IEEE
    802.3"; its texts in the comments).  The names follow the texts. }
  status_$eth_internal_driver_error = 16#002F0001;  { internal driver error }
  status_$eth_not_implemented = 16#002F0002;        { feature is not implemented }
  status_$eth_driver_version_mismatch = 16#002F0003;
                                        { driver version mismatch }
  status_$eth_device_offline = 16#002F0004;         { device is off-line }
  status_$eth_device_already_online = 16#002F0005;  { device is already on-line }
  status_$eth_adapter_hardware_error = 16#002F0006; { adapter hardware error }
  status_$eth_transmit_failed = 16#002F0007;        { transmit operation failed }
  status_$eth_invalid_unit_num = 16#002F0008;       { invalid unit number }
  status_$eth_illegal_pkt_length = 16#002F0009;     { illegal packet length }
  status_$eth_invalid_stats_block = 16#002F000A;    { invalid statistics block }
  status_$eth_pkt_type_in_use = 16#002F000B;        { packet type is already in use }
  status_$eth_no_channels = 16#002F000C;            { no channels are available }
  status_$eth_no_packet_to_receive = 16#002F000D;   { no packet available for receive }
  status_$eth_invalid_pkt_type = 16#002F000E;       { invalid packet type }
  status_$eth_channel_not_open = 16#002F000F;       { channel is not open }
  status_$eth_not_multicast = 16#002F0010;          { address is not a multicast }
  status_$eth_multicast_list_full = 16#002F0011;    { multicast list is full }
  status_$eth_is_multicast = 16#002F0012;           { address is a multicast }
  status_$eth_pkt_type_not_in_use = 16#002F0013;    { packet type is not already in use }
  status_$eth_illegal_dest_address = 16#002F0014;   { illegal destination address }

  { The turns of the driver's polling loops at most: the adapter's
    reset and a downloaded program's start (ethernet_reset,
    ethernet_execute), a reply byte (ethernet_get_pcb), a command byte
    and the adapter's answer to a command block (ethernet_send_pcb).
    Fewer with `ethernet_short_polls'. }
%if ethernet_short_polls %then
  eth_reset_polls = 3000000;
  eth_reply_byte_polls = 35000;
  eth_cmd_byte_polls = 20000;
  eth_cmd_answer_polls = 125000;
%else
  eth_reset_polls = 4200000;
  eth_reply_byte_polls = 50000;
  eth_cmd_byte_polls = 30000;
  eth_cmd_answer_polls = 200000;
%endif

  { The host control register's bits (the HCR, a byte the host writes
    and reads back): attention and flush reset the adapter; HSF1 and
    HSF2 are the host's status flags, both set marking the last byte of
    a command block, HSF1 alone acknowledging the adapter's block and
    HSF2 alone refusing it; DIR the direction of a data transfer; TCEN
    enables the terminal count's interrupt (the interrupt routine sets
    it while it works, with CMDE clear); CMDE enables the command
    register's interrupt. }
  eth_hcr_attn = 16#80;
  eth_hcr_flsh = 16#40;
  eth_hcr_dir = 16#10;
  eth_hcr_tcen = 16#08;
  eth_hcr_cmde = 16#04;
  eth_hcr_hsf2 = 16#02;
  eth_hcr_hsf1 = 16#01;

  { The adapter status register's members (the ASR, a byte set): ASF1
    and ASF2, the adapter's status flags (both set: the last byte of
    its command block; ASF1 alone: it took the host's block; ASF2
    alone: it refused it); ASF3, the third (the downloaded program's
    transmit signal); DIR, the HCR's DIR read back; ACRF, a byte in
    the adapter's command register for the host; HCRE, the host's
    command register is empty; HRDY, the data register is ready. }
  eth_asr_asf1 = 0;
  eth_asr_asf2 = 1;
  eth_asr_asf3 = 2;
  eth_asr_dir = 4;
  eth_asr_acrf = 5;
  eth_asr_hcre = 6;
  eth_asr_hrdy = 7;

  { The units: two adapters, ETHERNET1 and ETHERNET2. }
  eth_max_unit = 1;

  { The longest command block, in bytes. }
  eth_pcb_max = 64;

  { The socket of a channel the system opened (as the ring's). }
  eth_os_socket = 16#E1;

  { The version of a channel's open arguments the driver takes at most. }
  eth_open_version = 2;

  { The Ethernet types of Domain packets and of ARP packets. }
  eth_type_domain = 16#8019;
  eth_type_arp = 16#0806;

  { The IDP packet type of the Domain packets the driver sends. }
  eth_idp_type_domain = 16#BE;

  { The address halves the driver makes: Apollo's multicast addresses
    are 09-00-1E-00-00-00 and 09-00-1E-00-00-01 (the second the one ARP
    requests go to), and a node whose Ethernet address is not known yet
    is taken to be 08-00-1E (Apollo's block) and its node ID's low 24
    bits. }
  eth_apollo_mcast_high = 16#09001E;
  eth_apollo_high = 16#08001E;

  { The group bit of an address's first byte (ethernet_$addr_t's
    first): set in a multicast address. }
  eth_addr_group = 0;

  { ARP (RFC 826): the Ethernet hardware type and the operations. }
  arp_hrd_ethernet = 1;
  arp_op_request = 1;
  arp_op_reply = 2;

  { An ARP cache entry lives 2400 TIME_$CLOCKH ticks (about ten minutes)
    from its last confirmation; while it is not valid at most 20
    requests go out for it in that time. }
  eth_arp_lifetime = 2400;
  eth_arp_max_tries = 20;

type
  { A byte of the adapter, read or written as a number. }
  ethernet_$byte_t = [byte] 0..255;

  { The adapter status register's byte as a set (above, eth_asr_*). }
  ethernet_$asr_t = set of 0..7;

  { The adapter's registers on the AT bus, each port a byte or word 2
    bytes from the last: the command register (both directions), the
    status register, the data register (16 bits; only the hand-written
    ETHERNET_$$PIO_READ and _WRITE move it) and the host control
    register.  `[device]': every reference is a bus cycle. }
  ethernet_$regs_t = [device] packed record
    command: ethernet_$byte_t;            { 0x00 }
    unused_01: char;                      { 0x01 }
    status: ethernet_$asr_t;              { 0x02 }
    unused_03: char;                      { 0x03 }
    data: integer;                        { 0x04 }
    control: ethernet_$byte_t;            { 0x06 }
  end;
  ethernet_$regs_ptr_t = ^ethernet_$regs_t;

  { An Ethernet address, six bytes in two packed 24-bit halves, or its
    first byte as a set (eth_addr_group, the group bit: a multicast
    address). }
  ethernet_$addr_t = packed record
    case integer of
      1: (high: 0..16#FFFFFF;             { 0x00 }
          low: 0..16#FFFFFF);             { 0x03 }
      2: (first: set of 0..7);            { 0x00 }
  end;

  { A command block (the 3C505's PCB), 64 bytes at most: its command
    byte, the number of bytes after the length byte, and those bytes;
    the views of the data the commands use.  The adapter's words and
    longwords are low byte first. }
  ethernet_$pcb_t = record
    case integer of
      1: (bytes: array[1..eth_pcb_max] of ethernet_$byte_t);
      2: (cmd: ethernet_$byte_t;          { 0x00 }
          len: ethernet_$byte_t;          { 0x01 }
          words: array[1..31] of integer);      { 0x02 }
      3: (hdr_3: integer;                 { 0x00 }
          longs: array[1..15] of integer32);    { 0x02 }
      4: (hdr_4: integer;                 { 0x00 }
          addrs: array[1..10] of ethernet_$addr_t);  { 0x02 }
  end;
  ethernet_$pcb_ptr_t = ^ethernet_$pcb_t;

  { A unit's flags, the word at +0x000 of its record: ETHERNET_$INIT
    sets member 0 (the unit is configured); eth_unit_online while it
    is started; eth_unit_domain while it takes Domain packets (they
    go to NET_IO, else they are dropped); eth_unit_rcv_ready while a
    received packet waits in the adapter (the downloaded program's
    notice) for the deferred work or the receive process to read it;
    eth_unit_rcv_proc while its receive process runs;
    eth_unit_cfg_3 while the
    82586 is configured with receive mode 3 (ethernet_configure);
    eth_unit_rcv_pending while a receive command is out;
    eth_unit_cmd_pending while a command block is out and its reply not
    taken; eth_unit_program once the downloaded program runs. }
  ethernet_$unit_flags_t = set of 0..15;

  { A unit's I/O descriptor (the map's ETHERNET1_IO_DESC and
    ETHERNET2_IO_DESC in IO_'s block), what IO_$MAP_CSR is given: the
    DCTE's longword at 0x34 points to it. }
  ethernet_$io_desc_ptr_t = ^io_$acquire_rec_t;

  { A channel of a unit, 10 bytes: open, the address space that opened
    it, the socket its packets go to (eth_os_socket: a channel the
    system opened, served through MAC_OS_$DEMUX), the entries of the
    unit's multicast list it uses (member i: entry i), and the version
    of the open's arguments. }
  ethernet_$channel_t = record
    open: boolean;                        { 0x00 }
    unused_01: char;                      { 0x01 }
    asid: integer;                        { 0x02 }
    socket: pinteger;                     { 0x04 }
    mcast_set: set of 0..15;              { 0x06 }
    version: integer;                     { 0x08 }
  end;

  { An Ethernet header's source address and type, 8 bytes. }
  ethernet_$src_t = record
    addr: ethernet_$addr_t;               { 0x00 }
    ptype: pinteger;                      { 0x06 }
  end;

  { An Ethernet header, 14 bytes. }
  ethernet_$eth_hdr_t = record
    dst: ethernet_$addr_t;                { 0x00 }
    src: ethernet_$src_t;                 { 0x06 }
  end;

  { An ARP packet on the Ethernet (RFC 826), 42 bytes: the Ethernet
    header, then the hardware and protocol types and lengths, the
    operation, and the sender's and target's hardware and protocol
    addresses.  The protocol is Domain's (eth_type_domain), its
    addresses node IDs. }
  ethernet_$arp_pkt_t = record
    dst: ethernet_$addr_t;                { 0x00 }
    src: ethernet_$addr_t;                { 0x06 }
    etype: pinteger;                      { 0x0C }
    hrd: integer;                         { 0x0E }
    pro: pinteger;                        { 0x10 }
    hln: ethernet_$byte_t;                { 0x12 }
    pln: ethernet_$byte_t;                { 0x13 }
    op: integer;                          { 0x14 }
    sha: ethernet_$addr_t;                { 0x16 }
    spa: linteger;                        { 0x1C }
    tha: ethernet_$addr_t;                { 0x20 }
    tpa: linteger;                        { 0x26 }
  end;

  { The IDP header that follows the Ethernet header of a Domain packet
    the driver sends, 30 bytes (xns/xns.ins.pas xns_$idp_header_t's
    layout), its hosts Ethernet addresses. }
  ethernet_$idp_t = record
    checksum: pinteger;                   { 0x00 }
    length: integer;                      { 0x02 }
    transport_ctl: ethernet_$byte_t;      { 0x04 }
    packet_type: ethernet_$byte_t;        { 0x05 }
    dest_net: integer32;                  { 0x06 }
    dest_host: ethernet_$addr_t;          { 0x0A }
    dest_sock: pinteger;                  { 0x10 }
    src_net: integer32;                   { 0x12 }
    src_host: ethernet_$addr_t;           { 0x16 }
    src_sock: pinteger;                   { 0x1C }
  end;

  { The Domain header ETHERNET_$SEND is given: the packet header, which
    for an internet packet holds the IDP header at 0x28. }
  ethernet_$xmit_hdr_t = record
    case integer of
      1: (pkt: pkt_$hdr_t);               { 0x00 }
      2: (unused_00: array[0..39] of char;  { 0x00 }
          idp: ethernet_$idp_t);          { 0x28 }
  end;
  ethernet_$xmit_hdr_ptr_t = ^ethernet_$xmit_hdr_t;

  { The first word of a received header page: a tag in its top 11 bits. }
  ethernet_$rcv_tag_t = packed record
    tag: 0..2047;
    unused: 0..31;
  end;

  { A received packet's header page, 0x400 bytes: the tag word and the
    Ethernet header after it, or a Domain packet's header from the
    start (its header and data lengths at 0x10 and 0x14). }
  ethernet_$rcv_hdr_t = record
    case integer of
      1: (bytes: array[0..1023] of char);
      2: (tag: ethernet_$rcv_tag_t;       { 0x00 }
          eth: ethernet_$eth_hdr_t);      { 0x02 }
      3: (unused_00: array[0..15] of char;  { 0x00 }
          hdr_len: pinteger;              { 0x10 }
          unused_12: integer;             { 0x12 }
          data_len: pinteger);            { 0x14 }
      4: (unused_4: integer;              { 0x00 }
          arp: ethernet_$arp_pkt_t);      { 0x02 }
      5: (pkt: pkt_$hdr_t);               { 0x00 }
      6: (words: array[0..511] of integer);  { 0x00 }
  end;
  ethernet_$rcv_hdr_ptr_t = ^ethernet_$rcv_hdr_t;

  { A piece of a packet to transmit, 6 bytes: its address and length. }
  ethernet_$xmit_piece_t = record
    va: univ_ptr;                         { 0x00 }
    len: integer;                         { 0x04 }
  end;
  ethernet_$xmit_list_t = array[1..16] of ethernet_$xmit_piece_t;
  ethernet_$xmit_list_ptr_t = ^ethernet_$xmit_list_t;

  { An element of a caller's buffer vector, 6 bytes: its address and
    length. }
  ethernet_$iov_t = record
    va: integer32;                        { 0x00 }
    len: pinteger;                        { 0x04 }
  end;
  ethernet_$iov_array_t = array[1..16] of ethernet_$iov_t;

  { An entry of a unit's ARP cache, 16 bytes: the node, its Ethernet
    address, the requests sent for it while it is not valid, and when
    the entry expires (TIME_$CLOCKH ticks). }
  ethernet_$arp_entry_t = record
    node: linteger;                       { 0x00 }
    hw: ethernet_$addr_t;                 { 0x04 }
    state: packed record                  { 0x0A }
      tries: 0..255;
      valid: boolean;
      unused: 0..127;
    end;
    expire: time_$clockh_t;               { 0x0C }
  end;
  ethernet_$arp_entry_ptr_t = ^ethernet_$arp_entry_t;

  { The ARP cache: 64 rows of 4 entries, a node in the row of its low six
    bits. }
  ethernet_$arp_table_t = array[0..63, 0..3] of ethernet_$arp_entry_t;
  ethernet_$arp_table_ptr_t = ^ethernet_$arp_table_t;

  { A range of packet types, 4 bytes: the lowest and the highest type. }
  ethernet_$type_range_t = record
    low: pinteger;                        { 0x00 }
    high: pinteger;                       { 0x02 }
  end;

  { A range of packet types a channel receives, 6 bytes: the lowest and
    highest type, or the two as one range (stored whole at an open), and
    the channel. }
  ethernet_$range_t = record
    case integer of
      1: (low: pinteger;                  { 0x00 }
          high: pinteger;                 { 0x02 }
          chan: integer);                 { 0x04 }
      2: (range: ethernet_$type_range_t); { 0x00 }
  end;
  ethernet_$range_list_t = array[1..32] of ethernet_$range_t;
  ethernet_$range_list_ptr_t = ^ethernet_$range_list_t;

  { The arguments of a channel's open, 4 bytes and the ranges: the
    version of the record and the ranges' count and ranges; the results
    are the channel and its socket's EC2 eventcount. }
  ethernet_$open_args_t = record
    case integer of
      1: (version: integer;               { 0x00 }
          count: integer;                 { 0x02 }
          ranges: array[1..20] of ethernet_$type_range_t);  { 0x04 }
      2: (channel: integer;               { 0x00 }
          ec2_handle: ec2_$ptr_t);        { 0x02 }
  end;

  { An entry of a unit's multicast list, 8 bytes: its users (0: the
    entry is free) and the address. }
  ethernet_$mcast_t = record
    count: integer;                       { 0x00 }
    addr: ethernet_$addr_t;               { 0x02 }
  end;
  ethernet_$mcast_list_t = array[1..15] of ethernet_$mcast_t;
  ethernet_$mcast_list_ptr_t = ^ethernet_$mcast_list_t;

  { A unit's statistics, 42 bytes, as ETHERNET_$GET_STATS returns them:
    a version (1), then ten counts. }
  ethernet_$stats_t = record
    version: integer;                     { 0x00 }
    counts: array[1..10] of integer32;    { 0x02 }
  end;
  ethernet_$stats_ptr_t = ^ethernet_$stats_t;

  { The arguments of a user channel's control request
    (ETHERNET_$SVC_IOCTL): the channel and the request (eth_ioctl_*
    below), then the request's own: a count of multicast addresses and
    the addresses; a station address (as XNS's host address too); the
    version of the arguments, a count of packet-type ranges and the
    ranges; where the statistics go and the room there.  The answer
    word, or the station address, is returned from the start. }
  ethernet_$ioctl_args_t = record
    case integer of
      1: (channel: pinteger;              { 0x00 }
          req: pinteger;                  { 0x02 }
          n_addrs: integer;               { 0x04 }
          addrs: array[1..15] of ethernet_$addr_t);  { 0x06 }
      2: (hdr_2: integer32;               { 0x00 }
          addr: ethernet_$addr_t);        { 0x04 }
      3: (hdr_3: integer32;               { 0x00 }
          host: xns_$host_t);             { 0x04 }
      4: (hdr_4: integer32;               { 0x00 }
          version: integer;               { 0x04 }
          count: integer;                 { 0x06 }
          ranges: array[1..20] of ethernet_$type_range_t);  { 0x08 }
      5: (hdr_5: integer32;               { 0x00 }
          unused_04: integer;             { 0x04 }
          stats: ethernet_$stats_ptr_t;   { 0x06 }
          max_len: pinteger);             { 0x0A }
      6: (result: integer);               { 0x00 }
      7: (station: ethernet_$addr_t);     { 0x00 }
  end;

  { A unit's record, 0x12B8 bytes, ETHER_UCB's element (the map's
    ETHER_UCB section, 0x2570 bytes, holds the two units).  The fields
    are those the translated routines reach; the unused_ fields hold the
    places of the rest (the TODO(pascal) below). }
  ethernet_$unit_t = record
    flags: ethernet_$unit_flags_t;        { 0x000 }
    station: ethernet_$addr_t;            { 0x002 }
    users: integer;                       { 0x008: starts not yet stopped }
    cnum: integer;                        { 0x00A: the DCTE's unit }
    io_unit: io_$unit_num_t;              { 0x00C }
    unused_0e: integer;                   { 0x00E }
    lock: ml_$exclusion_t;                { 0x010 }
    unused_22: integer;                   { 0x022 }
    cmd_lock: ml_$exclusion_t;            { 0x024: one command at a time }
    unused_36: integer;                   { 0x036 }
    rcv_wake_ec: ec_$eventcount_t;        { 0x038: wakes the receive process }
    rcv_exit_ec: ec_$eventcount_t;        { 0x044: advanced as it stops }
    regs: ethernet_$regs_ptr_t;           { 0x050 }
    dcte: dcte_ptr_t;                     { 0x054 }
    rcv_state: integer;                   { 0x058: eth_rcv_* }
    unused_5a: integer;                   { 0x05A }
    hdr_va: integer32;                    { 0x05C: the receive header page }
    rcv_hdr_len: pinteger;                { 0x060: the received packet's }
    rcv_data_len: pinteger;               { 0x062   header and data lengths }
    dat_va: integer32;                    { 0x064: the receive data page }
    spare_dat: integer32;                 { 0x068: a data page kept back }
    rcv_src: ethernet_$src_t;             { 0x06C: its source and type }
    reply_ec: ec_$eventcount_t;           { 0x074: advanced on a reply }
    reply_val: integer32;                 { 0x080: the value awaited }
    arp_lock: ml_$exclusion_t;            { 0x084: the ARP cache's }
    unused_96: integer;                   { 0x096 }
    arp: ethernet_$arp_table_t;           { 0x098 }
    excl_1098: ml_$exclusion_t;           { 0x1098 }
    unused_10aa: integer;                 { 0x10AA }
    channels: array[1..10] of ethernet_$channel_t;  { 0x10AC }
    ranges: ethernet_$range_list_t;       { 0x1110: the channels' types }
    range_count: pinteger;                { 0x11D0 }
    mcast: ethernet_$mcast_list_t;        { 0x11D2 }
    mcast_count: pinteger;                { 0x124A: entries in use }
    wired: boolean;                       { 0x124C: its pages are wired }
    unused_124d: char;                    { 0x124D }
    unused_124e: integer;                 { 0x124E }
    di_elem: di_$q_elem_t;                { 0x1250: the deferred work's }
    idle_defers: integer;                 { 0x1260: deferred calls with
                                            nothing to do }
    unused_1262: integer;                 { 0x1262 }
    buf_va: integer32;                    { 0x1264: the unit's two pages of }
    buf_pmape: univ_ptr;                  { 0x1268   ETHERNET_$BUFFER and }
    buf2_va: integer32;                   { 0x126C   their page table }
    buf2_pmape: univ_ptr;                 { 0x1270   entries }
    rcv_tag: integer;                     { 0x1274: the next packet's tag }
    rcv_len: integer;                     { 0x1276   and length }
    reply_cmd: integer;                   { 0x1278: the reply awaited }
    unused_127a: integer;                 { 0x127A }
    reply_pcb: ethernet_$pcb_ptr_t;       { 0x127C: where it goes }
    ec_1280: ec_$eventcount_t;            { 0x1280 }
    stats: ethernet_$stats_t;             { 0x128C }
    unused_12b6: integer;                 { 0x12B6 }
  end;
  ethernet_$unit_ptr_t = ^ethernet_$unit_t;

{ TODO(pascal) the unit record's undecoded places

  ethernet_$unit_t's unused_ fields, the channel's unused_02 and the
  fields named unknown_ or by offset are where the routines translated
  so far do not reach or do not show the meaning.  They are filled in
  as the rest of the driver is translated. }

const
  { The unit flags' member (above). }
  eth_unit_configured = 0;
  eth_unit_online = 1;
  eth_unit_domain = 2;
  eth_unit_cfg_3 = 3;
  eth_unit_rcv_ready = 4;
  eth_unit_rcv_proc = 5;
  eth_unit_rcv_pending = 6;
  eth_unit_cmd_pending = 7;
  eth_unit_program = 8;

  { A unit's receive state (rcv_state): idle; a packet to read (the
    command lock was held at interrupt level); a packet in the pages, to
    learn from and hand on; to hand on at process level; new pages to
    take at process level. }
  eth_rcv_idle = 0;
  eth_rcv_read = 1;
  eth_rcv_got = 2;
  eth_rcv_demux = 3;
  eth_rcv_bufs = 4;

  { The adapter's commands (the PCB's first byte), 3Com's for the 3C505;
    a reply's code is its command's with 16#30 added. }
  eth_cmd_configure_memory = 16#01;
  eth_cmd_configure_82586 = 16#02;
  eth_cmd_receive_packet = 16#08;
  eth_cmd_transmit_packet = 16#09;
  eth_cmd_network_statistics = 16#0A;
  eth_cmd_load_multicast = 16#0B;
  eth_cmd_download_program = 16#0D;
  eth_cmd_execute_program = 16#0E;
  { A command of the program the driver downloads (its meaning is not
    known): ethernet_execute gives it once the program runs. }
  eth_cmd_x17 = 16#17;
  { The downloaded program's transmit command. }
  eth_cmd_x18 = 16#18;
  { The downloaded program's notice that a received packet waits in the
    adapter: its code is this with eth_cmd_reply added; the host then
    gives eth_cmd_x17 and reads the packet. }
  eth_cmd_x16 = 16#16;
  eth_cmd_set_station_address = 16#10;
  eth_cmd_adapter_info = 16#11;
  eth_cmd_reply = 16#30;

  { A user channel's control requests (ETHERNET_$SVC_IOCTL's case
    labels; descriptive names): the driver's version, the adapter's
    information word, the station address, adding and dropping
    multicast addresses, setting the station address, adding and
    dropping packet-type ranges, the statistics. }
  eth_ioctl_get_version = 0;
  eth_ioctl_adapter_info = 1;
  eth_ioctl_get_address = 2;
  eth_ioctl_add_mcast = 3;
  eth_ioctl_del_mcast = 4;
  eth_ioctl_set_address = 5;
  eth_ioctl_add_types = 6;
  eth_ioctl_del_types = 7;
  eth_ioctl_get_stats = 8;

  { The log entry ETHERNET_$LOAD and ETHERNET_$IOCTL make when the
    adapter's program fails to load: LOG_$ADD's entry type, the entry's
    code, and the step that failed. }
  eth_log_type = 13;
  eth_log_load = 6;
  eth_load_download = 1;
  eth_load_execute = 2;

type
  { That log entry, 18 bytes: the code, the unit, the network's UID, the
    status and the step. }
  ethernet_$load_log_t = record
    code: integer;                        { 0x00 }
    unit: integer;                        { 0x02 }
    network: uid_$t;                      { 0x04 }
    status: status_$t;                    { 0x0C }
    step: integer;                        { 0x10 }
  end;

  { The driver record (net_io/net_io.ins.pas net_io_$driver_t's
    layout, 0x50 bytes, its names).  Every entry is univ_ptr: dpc checks
    a routine's heading against a routine pointer type exactly, so the
    record is a type of its own with the same layout (as
    ring/ring_driver.ins.pas's ring_$driver_t). }
  ethernet_$driver_t = record
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

var
  { The marks around the driver's code (ETHER_PROC_START,
    ETHER_PROC_END) and data (ETHER_DATA_START, ETHER_DATA_END),
    sections of their own: the driver wires from one to the other. }
  ether_proc_start: extern char;
  ether_proc_end: extern char;
  ether_data_start: extern char;
  ether_data_end: extern char;

  { ETHERNET_$NETWORK_UID (map symbol in UID_LIST's run of the
    network-type UIDs, with NIL_$NETWORK_UID, uid/uid.ins.pas):
    ETHERNET_$INIT copies it into the driver record's UID. }
  ethernet_$network_uid: extern uid_$t;

{ TODO(pascal) MMU's SAU9 headings belong in mmu/mmu.ins.pas

  The SAU9's MMU_$REMOVE takes a word after its longword, 0 at the
  driver's two calls (as at 12 of the SAU9's 15 calls, and on the SAU4
  and SAU6..SAU8; the SAU9's routine reads only the longword), where
  mmu/mmu.ins.pas declares the SAU2's one-argument form, which its
  thirty-odd callers use under every configuration.  As win_scsi does
  (the same TODO in win_scsi/win_scsi.ins.pas), this module declares the
  MMU headings it calls here, as mmu/mmu.ins.pas has them but
  MMU_$REMOVE, and does not include that file, until MMU's other form
  has a part of its own there. }

{ MMU_$REMOVE (hand-written): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: integer32; flags: integer);
  options(extern, val_param);

{ MMU_$INSTALL (hand-written): the page number and the virtual address,
  longwords, then the ASID and the protection, all by value. }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

{ MMU_$MCR_CHANGE (hand-written): the bit number of the memory control
  register to change, a word by value. }
procedure mmu_$mcr_change(bit: integer); options(extern, val_param);

{ MMU_$GET_PMAPE_ADDR and MMU_$SET_PMAPE (the SAU9's MMU code, hand
  assembly): the page table entry of a virtual address, and a page
  installed there; everything by value. }
function mmu_$get_pmape_addr(va: univ_ptr): univ_ptr;
  options(extern, val_param);
procedure mmu_$set_pmape(va: univ_ptr; pmape: univ_ptr; ppn: integer32);
  options(extern, val_param);

{ The ETHERNET map routines, in map order (ETHERNET_$INIT's heading is
  in ethernet/ethernet.ins.pas). }

{ ETHERNET_$START - start a unit.  The driver record's start entry
  (net_io/net_io.ins.pas net_io_$start_proc_t): the unit and the status
  by address. }
procedure ethernet_$start(in unit: pinteger; out status: status_$t); extern;

{ ETHERNET_$STOP - stop a unit.  The driver record's stop entry, as
  ETHERNET_$START. }
procedure ethernet_$stop(in unit: pinteger; out status: status_$t); extern;

{ ETHERNET_$LOAD - load the adapter's program.  The driver record's
  detach entry, which NETWORK_$LOAD calls with the shape of NET's
  control entries (net/net.ins.pas net_$ctl_proc_t): the unit, a
  longword constant 0, a word 0 by value, a longword local and the
  status; only the unit and the status are used. }
procedure ethernet_$load(var unit: pinteger; var unused2: univ integer32;
                         unused3: integer; var unused4: univ integer32;
                         out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SEND - send a Domain packet.  The driver record's sendp
  entry (net_io/net_io.ins.pas net_io_$sendp_t's shape): the header a
  pointer of the driver's own view, xmit_status a word. }
procedure ethernet_$send(var socket: pinteger; hdr_pa: integer32;
                         hdr: ethernet_$xmit_hdr_ptr_t; hdr_len: integer;
                         in data_pages: univ pkt_$data_pages_t;
                         data_va: integer32; data_len: pinteger;
                         in flags: univ integer;
                         out xmit_status: pinteger;
                         out status_ret: status_$t);
  options(extern, val_param);

{ ETHERNET_$GET_STATS and ETHERNET_$GET_STATS2 - return a unit's
  statistics.  The driver record's get_stats and get_stats2 entries
  (net_io/net_io.ins.pas net_io_$stats_proc_t, as RING_$GET_STATS). }
procedure ethernet_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                              max_len: integer; out length_ret: integer;
                              out status_ret: status_$t);
  options(extern, val_param);
procedure ethernet_$get_stats2(var socket: univ pinteger; stats_buf: univ_ptr;
                               max_len: integer; out length_ret: integer;
                               out status_ret: status_$t);
  options(extern, val_param);

{ ETHERNET_$IOCTL - a unit's control request.  The driver record's
  ioctl entry, the shape of NET's control entries (as RING_$IOCTL). }
procedure ethernet_$ioctl(var unit: pinteger; var unused2: univ integer32;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SVC_OPEN and ETHERNET_$SVC_CLOSE - open and close a user
  channel.  The driver record's svc_open and svc_close entries, the
  shape of NET's control entries (as RING_$SVC_OPEN and _CLOSE). }
procedure ethernet_$svc_open(var unit: pinteger;
                             var args: ethernet_$open_args_t;
                             unused3: integer; var unused4: univ integer32;
                             out status: status_$t);
  options(extern, val_param);
procedure ethernet_$svc_close(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SVC_READ - receive a packet on a user channel.  The driver
  record's svc_read entry, the shape of NET's transfer entries
  (net/net.ins.pas net_$xfer_proc_t, as RING_$SVC_READ): the channel by
  address, the caller's buffer vector and its length. }
procedure ethernet_$svc_read(var unit: pinteger; var channel: pinteger;
                             unused3: integer; var unused4: univ integer32;
                             var iov: univ ethernet_$iov_array_t;
                             iov_cnt: integer; out len_out: integer;
                             out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SVC_WRITE - send a packet on a user channel.  The driver
  record's svc_write entry, the shape of NET's transfer entries (as
  ETHERNET_$SVC_READ); the seventh argument is not used. }
procedure ethernet_$svc_write(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              var iov: univ ethernet_$iov_array_t;
                              iov_cnt: integer; var unused7: univ integer32;
                              out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SVC_IOCTL - a user channel's control request.  The driver
  record's svc_ioctl entry, the shape of NET's control entries (as
  ETHERNET_$SVC_OPEN): the request's record by address. }
procedure ethernet_$svc_ioctl(var unit: pinteger;
                              var args: ethernet_$ioctl_args_t;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$PROC2_CLEANUP - close every channel an address space holds.
  The driver record's proc2_cleanup entry (as RING_$PROC2_CLEANUP): the
  unit by address, the address space a word by value. }
procedure ethernet_$proc2_cleanup(var unit: pinteger; asid: integer);
  options(extern, val_param);

{ ETHERNET_$OPEN_OS - open a system channel for MAC_OS.  The driver
  record's open_os entry (mac_os/mac_os.ins.pas, as RING_$OPEN_OS): the
  line a word by value, MAC_OS's open record and the status by
  address. }
procedure ethernet_$open_os(line: pinteger; var params: mac_os_$open_params_t;
                            out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$CLOSE_OS - close a system channel MAC_OS opened.  The
  driver record's close_os entry (mac_os/mac_os.ins.pas
  mac_os_$drv_close_t's shape, as RING_$CLOSE_OS). }
procedure ethernet_$close_os(line: pinteger; var callback_data: integer;
                             out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$SEND_OS - send a MAC_OS packet on a system channel.  The
  driver record's send_os entry (mac_os/mac_os.ins.pas
  mac_os_$drv_send_t's shape, as RING_$SEND_OS). }
procedure ethernet_$send_os(line: integer; var callback_data: pinteger;
                            var pkt: mac_os_$send_pkt_t;
                            out bytes_sent: integer; out status: status_$t);
  options(extern, val_param);

{ ETHERNET_$INT_DEFERRED - a unit's receive work at the end of its
  interrupt.  The routine ETHERNET_$INTERRUPT queues with DI_$ENQ, called
  with the unit pushed by value; the result, a pointer in A0, is the
  eventcount to advance, or nil. }
function ethernet_$int_deferred(u: ethernet_$unit_ptr_t):
  ec_$eventcount_ptr_t;
  options(extern, val_param);

{ ETHERNET_$INTERRUPT - a unit's interrupt routine.  The handler
  IO_$ACQUIRE registers (ethernet_start_unit), called with its argument,
  the unit's DCTE address, by value (a longword, converted where it is
  dereferenced); the result is true. }
function ethernet_$interrupt(dcte: integer32): boolean;
  options(extern, val_param);

{ ETHERNET_$RCV0 and ETHERNET_$RCV1 - the two units' receive processes:
  process entry points, no arguments. }
procedure ethernet_$rcv0; extern;
procedure ethernet_$rcv1; extern;

{ ETHERNET_$$PIO_READ and ETHERNET_$$PIO_WRITE (ETHERNET_ASM, hand
  assembly, ethernet/m68k/ethernet_asm.s: no frame, the arguments off
  SP) - move len bytes, a word at a time, from the adapter's data
  register into buf, or from buf to it.  The registers, the buffer and
  the byte count (a word) by value, the status by address
  (`val_param'); the result is true, or false with
  status_$eth_adapter_hardware_error when the adapter was not ready.
  Its callers test the status, not the result. }
function ethernet_$$pio_read(regs: ethernet_$regs_ptr_t; buf: univ_ptr;
                             len: integer; out status: status_$t): boolean;
  options(extern, val_param);
function ethernet_$$pio_write(regs: ethernet_$regs_ptr_t; buf: univ_ptr;
                              len: integer; out status: status_$t): boolean;
  options(extern, val_param);
