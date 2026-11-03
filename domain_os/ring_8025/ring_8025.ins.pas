{ ring_8025/ring_8025.ins.pas - the IEEE 802.5 token-ring driver's
  declarations: the statuses, the adapter's registers and blocks, the
  unit and driver records, the module's sections and the headings of the
  RING_8025 map routines, for the Domain Pascal tree.

  The driver of the AT-bus token-ring adapter the SAU9 (DN2500) has
  (`ring_8025_driver', base/config.ins.pas): a TMS380-family ring
  controller, reached through its system interface (the SIF registers,
  little-endian words) and the command and status blocks in the host's
  memory.  The SIF register and bit names follow TI's; the others are
  descriptive.

  Apollo's customer insert files of SR10.2 declare nothing of RING_8025.
  Include base/base.ins.pas, ec/ec.ins.pas, ml/ml.ins.pas, io/io.ins.pas,
  uid/uid.ins.pas, pkt/pkt.ins.pas and mac_os/mac_os.ins.pas before it,
  and not mmu/mmu.ins.pas (the MMU headings are here).
}

const
  { The driver's statuses, subsystem 16#37 (stcode.db.10.2's "OS / Ring
    802.5"; its texts in the comments).  The names follow the texts. }
  status_$r8025_internal_driver_error = 16#00370001;
                                        { internal driver error }
  status_$r8025_not_implemented = 16#00370002;
                                        { feature is not implemented }
  status_$r8025_driver_version_mismatch = 16#00370003;
                                        { driver version mismatch }
  status_$r8025_device_offline = 16#00370004;       { device is off-line }
  status_$r8025_device_already_online = 16#00370005;
                                        { device is already on-line }
  status_$r8025_adapter_hardware_error = 16#00370006;
                                        { adapter hardware error }
  status_$r8025_transmit_failed = 16#00370007;
                                        { transmit operation failed }
  status_$r8025_invalid_unit_num = 16#00370008;     { invalid unit number }
  status_$r8025_illegal_frame_length = 16#00370009; { illegal frame length }
  status_$r8025_invalid_stats_block = 16#0037000A;
                                        { invalid statistics block }
  status_$r8025_frame_type_in_use = 16#0037000B;
                                        { frame type is already in use }
  status_$r8025_no_channels = 16#0037000C;
                                        { no channels are available }
  status_$r8025_no_frame_to_receive = 16#0037000D;
                                        { no frame available for receive }
  status_$r8025_invalid_frame_type = 16#0037000E;   { invalid frame type }
  status_$r8025_channel_not_open = 16#0037000F;     { channel is not open }
  status_$r8025_frame_type_not_in_use = 16#00370010;
                                        { frame type is not already in use }
  status_$r8025_illegal_dest_address = 16#00370011;
                                        { illegal destination address }
  status_$r8025_rcv_buffer_too_small = 16#00370012;
                                        { size of receive buffer less than
                                          received frame }

  { The adapter's memory address the system interface is pointed at to
    reach the initialization parameters (TI's). }
  r8025_init_params_addr = 16#0A00;

  { The SIF commands as the host writes the word (the controller reads
    it byte-swapped: TI's values in the comments): interrupt the
    adapter, execute and system interrupt, to act on the system command
    block or the parameters; the same with the command block request;
    interrupt with receive continue. }
  r8025_sifcmd_execute = 16#8090;           { TI 16#9080 }
  r8025_sifcmd_execute_scb_req = 16#8098;   { TI 16#9880 }
  r8025_sifcmd_rcv_continue = 16#8084;      { TI 16#8480 }
  r8025_sifcmd_ssb_clear = 16#00A0;         { TI 16#A000 }

  { The SIF command that only interrupts the adapter, which a unit's
    receive process gives as it stops. }
  r8025_sifcmd_interrupt = 16#0080;         { TI 16#8000 }

  { The SIF command that hands the adapter a valid transmit list:
    interrupt the adapter, transmit valid and system interrupt. }
  r8025_sifcmd_xmit_valid = 16#8081;        { TI 16#8180 }

  { The system command block's commands (TI's). }
  r8025_cmd_open = 3;
  r8025_cmd_transmit = 4;
  r8025_cmd_transmit_halt = 5;
  r8025_cmd_receive = 6;
  r8025_cmd_close = 7;
  r8025_cmd_set_group_address = 8;
  r8025_cmd_set_funct_address = 9;
  r8025_cmd_read_error_log = 10;

  { The transmit and receive lists in a unit's control area. }
  r8025_xmit_lists = 3;
  r8025_rcv_lists = 2;

  { The size of a frame buffer in the control area (the driver record's
    MTU), and the data descriptors of a list. }
  r8025_frame_size = 4504;
  r8025_list_data = 3;

  { A list's CSTAT byte's members (ring_8025_$cstat_t, TI's bits 15..8
    of the list's CSTAT word): the list is valid for the adapter; the
    frame is complete; the list starts and ends the frame; interrupt on
    the frame; member 2 is the transmit error on a transmit list, the
    interframe wait on a receive list. }
  r8025_cstat_valid = 7;
  r8025_cstat_complete = 6;
  r8025_cstat_start_frame = 5;
  r8025_cstat_end_frame = 4;
  r8025_cstat_frame_int = 3;
  r8025_cstat_xmit_error = 2;
  r8025_cstat_rcv_ifw = 2;

  { A transmitted frame's frame status byte as the adapter returns it
    in the list (the A and C bits twice, IEEE 802.5): the address was
    recognized and the frame copied; recognized, not copied; neither. }
  r8025_fs_copied = 16#CC;
  r8025_fs_not_copied = 16#88;
  r8025_fs_none = 0;

  { The frame status's A bits: the address was recognized. }
  r8025_fs_recognized = 16#88;

  { The high half of the station addresses the driver opens with and
    sends to: the low half is a node's ID. }
  r8025_addr_high = 16#500078;

  { The access control and frame control bytes of the frames the
    driver sends (priority 3; an LLC frame). }
  r8025_ac = 16#60;
  r8025_fc_llc = 16#40;

  { An XID's information field's format identifier (IEEE 802.2: the
    basic format). }
  r8025_xid_format = 16#81;

  { The XIDs the driver sends to find a station: to the null SAP from
    SAP 16#12, the XID command (IEEE 802.2, the poll bit clear); the
    routing field's control word of the broadcast one (a single-route
    broadcast, the field 2 bytes, the largest frame code 7), which a
    group destination is sent with too; the ticks an XID is answered in,
    and the tries. }
  r8025_null_sap = 0;
  r8025_xid_ssap = 16#12;
  r8025_llc_xid = 16#AF;
  r8025_rc_single_bcast = 16#C270;
  r8025_xid_wait = 4;
  r8025_xid_tries = 3;

  { An LLC response's source SAP bit (IEEE 802.2), and the routing
    field's control word of the answer to a single-route broadcast (an
    all-routes broadcast, the field 2 bytes, the largest frame code 2). }
  r8025_llc_response = 1;
  r8025_rc_all_routes = 16#8220;

  { An LLC control byte's TEST command (IEEE 802.2, the poll bit clear),
    which a frame to the null SAP may carry beside the XID. }
  r8025_llc_test = 16#E3;

  { A received frame's type (ring_8025_$ftype_t) of a Domain packet: the
    SNAP SAP 16#AA and the type 16#8019. }
  r8025_type_domain = 16#AA8019;

  { The LLC and SNAP headers of the Domain packets the driver sends:
    the SNAP SAP both ways, an unnumbered information frame (IEEE 802.2),
    the organization code (the stations' address high half) and the
    type. }
  r8025_snap_sap = 16#AA;
  r8025_llc_ui = 3;
  r8025_snap_org = 16#500078;
  r8025_snap_domain = 16#8019;

  { The largest frame a unit takes at first: the routing field's
    largest-frame code 2 (2052 bytes) and a MAC header. }
  r8025_max_frame = 2066;

  { The socket of a channel the system opened (RING_8025_$OPEN_OS): its
    frames go to MAC_OS_$DEMUX, not to a socket. }
  r8025_os_socket = 16#E1;

  { The most of a received frame copied to a header page; the rest goes
    to data pages. }
  r8025_hdr_max = 952;

  { A MAC header without a routing field and an LLC header (14 and 3
    bytes): the shortest frame a channel sends. }
  r8025_mac_llc_len = 17;

  { The unit's flag set's members (ring_8025_$unit_t's flags): the unit
    is configured (RING_8025_$INIT); it is started; it is started for the
    network (RING_8025_$START): it takes Domain packets; a command passed
    in the system command block whose completion has not yet been seen;
    its receive process runs; the adapter did not open onto the ring at
    the start, or left it; the adapter is on the ring, its receiver and
    transmitter started.  The interrupt routine sets the rest for the
    receive process (from the ring status, TI's bits): the adapter's
    error counters overflowed (counter overflow); the adapter was removed
    from the ring (remove received); it removed itself (auto-removal
    error); the adapter check interrupt. }
  r8025_unit_configured = 0;
  r8025_unit_online = 1;
  r8025_unit_domain = 2;
  r8025_unit_scb_busy = 3;
  r8025_unit_rcv_proc = 4;
  r8025_unit_open_failed = 5;
  r8025_unit_on_ring = 6;
  r8025_unit_counter_ovf = 7;
  r8025_unit_removed = 8;
  r8025_unit_auto_removal = 9;
  r8025_unit_adapter_check = 10;

  { The SIF interrupt's type (ring_8025_$sifint_t's code, TI's interrupt
    codes halved): the adapter check, the ring status, the system command
    block clear, a command's status, the receive status, the transmit
    status. }
  r8025_int_adapter_check = 0;
  r8025_int_ring_status = 2;
  r8025_int_scb_clear = 3;
  r8025_int_cmd_status = 4;
  r8025_int_rcv_status = 5;
  r8025_int_xmit_status = 6;

  { The ring status word's bits the interrupt routine tests (TI's): lobe
    wire fault, auto-removal error, remove received, counter overflow. }
  r8025_ring_lobe_fault = 16#0800;
  r8025_ring_auto_removal = 16#0400;
  r8025_ring_removed = 16#0100;
  r8025_ring_counter_ovf = 16#0080;

  { A MAC header without a routing field (IEEE 802.5: the access and
    frame control bytes and the two addresses). }
  r8025_mac_hdr_len = 14;

  { A user channel's control requests (RING_8025_$SVC_IOCTL's case
    labels; descriptive names): the driver's version; the adapter's
    information (0); the station address; the functional and group
    addresses; a new functional or group address; adding or dropping the
    channel's frame-type ranges; the statistics; the largest frame the
    unit takes, and a new one; whether the unit uses source routing, and
    a new setting. }
  r8025_ioctl_get_version = 0;
  r8025_ioctl_adapter_info = 1;
  r8025_ioctl_get_address = 2;
  r8025_ioctl_get_funct = 3;
  r8025_ioctl_get_group = 4;
  r8025_ioctl_set_funct = 5;
  r8025_ioctl_set_group = 6;
  r8025_ioctl_add_types = 7;
  r8025_ioctl_del_types = 8;
  r8025_ioctl_get_stats = 9;
  r8025_ioctl_get_max_frame = 10;
  r8025_ioctl_set_max_frame = 11;
  r8025_ioctl_get_routing = 12;
  r8025_ioctl_set_routing = 13;

  { The units: 0 and 1. }
  r8025_max_unit = 1;

  { The pages the driver keeps wired (the code and the data sections,
    and the two units' records), and each unit's pages of the auxiliary
    area: the control area's six contiguous pages and the route cache's
    eight. }
  r8025_wire_max = 64;
  r8025_ctl_pages = 6;
  r8025_route_pages = 8;

  { The route cache: 64 buckets (by a station's low six address bits)
    of three routes; a learned route is kept 1200 TIME_$CLOCKH units. }
  r8025_route_buckets = 63;
  r8025_route_ways = 2;
  r8025_route_life = 1200;

  { A unit's channels: 1..10; the version of an open's arguments, 2 at
    most. }
  r8025_max_chan = 10;
  r8025_open_version = 2;

  { The frames to the null SAP a unit queues for its answer: 8. }
  r8025_nullsap_max = 7;
  r8025_nullsap_slots = 8;

type
  { A byte of the adapter, read or written as a number. }
  ring_8025_$byte_t = [byte] 0..255;

  { A word of the controller's system interface, unsigned. }
  ring_8025_$word_t = 0..65535;

  { A station, group or functional address, six bytes (IEEE 802.5), in
    two packed 24-bit halves, as bytes or as three words (MAC_OS's link
    address); a source address's first bit
    is the routing information indicator (a routing field follows), a
    destination's the group address indicator. }
  ring_8025_$addr_t = packed record
    case integer of
      1: (high: 0..16#FFFFFF;             { 0x00 }
          low: 0..16#FFFFFF);             { 0x03 }
      2: (bytes: packed array[1..6] of char);
      3: (rii: boolean);                  { bit 47 }
      4: (group: boolean);                { bit 47 }
      5: (words: array[0..2] of integer);
  end;

  { A routing field's control word (IEEE 802.5): a broadcast route, a
    single-route (else all-routes) broadcast, the field's length in
    bytes, the direction, the largest frame's code. }
  ring_8025_$rc_t = packed record
    bcast: boolean;                       { bit 15 }
    single: boolean;                      { bit 14 }
    unused_13: boolean;                   { bit 13 }
    len: 0..31;                           { bits 12..8 }
    dir: boolean;                         { bit 7 }
    lf: 0..7;                             { bits 6..4 }
    unused_0: 0..15;                      { bits 3..0 }
  end;

  { A routing field, 18 bytes at most: the control word and up to eight
    route designators, or its bytes. }
  ring_8025_$rif_t = record
    case integer of
      1: (rc: ring_8025_$rc_t;            { 0x00 }
          segs: array[1..8] of integer);  { 0x02 }
      2: (rc_word: ring_8025_$word_t);    { 0x00 }
      3: (bytes: array[1..18] of char);   { 0x00 }
  end;

  { A frame's MAC header in a header page (IEEE 802.5): the access and
    frame control bytes, the destination and source addresses, then the
    routing field when the source's rii is set, and the LLC header after
    it. }
  ring_8025_$mac_hdr_t = record
    ac: ring_8025_$byte_t;                { 0x00 }
    fc: ring_8025_$byte_t;                { 0x01 }
    dest: ring_8025_$addr_t;              { 0x02 }
    src: ring_8025_$addr_t;               { 0x08 }
    rif: ring_8025_$rif_t;                { 0x0E }
  end;
  ring_8025_$mac_hdr_ptr_t = ^ring_8025_$mac_hdr_t;

  { An LLC header (IEEE 802.2): the destination and source SAPs and the
    control byte; then an XID's information field (the format, the LLC
    classes, the receive window), or a SNAP header (its organization
    code, then the type) and the packet after it, a Domain packet's
    header for the type 16#8019.  A packed record: the organization
    code is a 24-bit field at 3. }
  ring_8025_$llc_t = packed record
    dsap: ring_8025_$byte_t;              { 0x00 }
    ssap: ring_8025_$byte_t;              { 0x01 }
    ctl: ring_8025_$byte_t;               { 0x02 }
    case integer of
      1: (xid_format: ring_8025_$byte_t;  { 0x03 }
          xid_class: ring_8025_$byte_t;   { 0x04 }
          xid_window: ring_8025_$byte_t); { 0x05 }
      2: (snap_org: 0..16#FFFFFF;         { 0x03 }
          snap_type: ring_8025_$word_t;   { 0x06 }
          pkt: pkt_$hdr_t);               { 0x08 }
  end;
  ring_8025_$llc_ptr_t = ^ring_8025_$llc_t;

  { The SIF status register, read where the command is written (TI's
    SIFSTS, its low byte first as the host reads the word): the system
    interrupt, the controller's initialize, test and error states, the
    interrupt code, then the register's other byte. }
  ring_8025_$sifsts_t = packed record
    system_irq: boolean;                  { bit 15 }
    initialize: boolean;                  { bit 14 }
    test: boolean;                        { bit 13 }
    error: boolean;                       { bit 12 }
    int_code: 0..15;                      { bits 11..8 }
    other: 0..255;                        { bits 7..0 }
  end;

  { The SIF status register read as the interrupt's type (the interrupt
    routine's view): TI's interrupt code without its low bit, the
    r8025_int_ constants. }
  ring_8025_$sifint_t = packed record
    unused_15: 0..15;                     { bits 15..12 }
    code: 0..7;                           { bits 11..9 }
    unused_8: boolean;                    { bit 8 }
    other: 0..255;                        { bits 7..0 }
  end;

  { The adapter's registers (an I/O descriptor's CSR pages): the host's
    data transfers (a data word, and a byte that gives a transfer's
    direction, length and address a byte at a time), the control and
    status bytes, and from 0x400 the controller's system interface,
    little-endian words (ring_8025_swap16). }
  ring_8025_$regs_t = [device] record
    pio_data: ring_8025_$word_t;          { 0x000 }
    pio_hdr: ring_8025_$byte_t;           { 0x002 }
    control_3: ring_8025_$byte_t;         { 0x003 }
    status_4: ring_8025_$byte_t;          { 0x004: bit 0, a transfer asked
                                            for; bit 1, the system
                                            interface's interrupt }
    status_5: ring_8025_$byte_t;          { 0x005 }
    reset: ring_8025_$byte_t;             { 0x006: bit 0, the reset latch;
                                            bit 1, a transfer to the host;
                                            bit 7, a transfer under way }
    control_7: ring_8025_$byte_t;         { 0x007 }
    unused_008: array[0..1015] of char;   { 0x008 }
    sifdat: ring_8025_$word_t;            { 0x400: SIF data }
    sifdat_inc: ring_8025_$word_t;        { 0x402: SIF data, auto-increment }
    sifadr: ring_8025_$word_t;            { 0x404: SIF address }
    case integer of                       { 0x406 }
      1: (sifcmd: ring_8025_$word_t);     { written: the command }
      2: (sifsts: ring_8025_$sifsts_t);   { read: the status }
      3: (sifint: ring_8025_$sifint_t);   { read: the interrupt's type }
  end;
  ring_8025_$regs_ptr_t = ^ring_8025_$regs_t;

  { A unit's I/O descriptor (the map's RING_8025_1_IO_DESC and
    RING_8025_2_IO_DESC in IO_'s block), what IO_$MAP_CSR is given. }
  ring_8025_$io_desc_ptr_t = ^io_$acquire_rec_t;

  { The controller's initialization parameters (TI's), eleven words
    written through the system interface: the options, the interrupt
    vectors (not set by the driver), the DMA burst sizes, the DMA abort
    thresholds, and the system command and status blocks' physical
    addresses. }
  ring_8025_$init_params_t = record
    case integer of
      1: (options: ring_8025_$word_t;     { 0x00 }
          vectors: array[1..6] of char;   { 0x02 }
          burst_sizes: integer32;         { 0x08: receive, transmit }
          abort_dma: char;                { 0x0C }
          abort_parity: char;             { 0x0D }
          scb_pa: integer32;              { 0x0E }
          ssb_pa: integer32);             { 0x12 }
      2: (words: array[1..11] of ring_8025_$word_t);
  end;

  { The system status block (TI's SSB, in the auxiliary area, and the
    unit's copies of it): the command or the interrupt's subject, and
    three status words; the second word's top bit, an open's success
    (TI's), read as a boolean and as a packed one. }
  ring_8025_$ssb_t = record
    cmd: integer;                         { 0x00 }
    case integer of
      1: (parm: array[1..3] of integer);  { 0x02 }
      2: (opened: boolean);               { 0x02 }
      3: (open_bits: packed record        { 0x02 }
            opened: boolean;              { bit 15 }
            unused: 0..32767;             { bits 14..0 }
          end);
  end;
  ring_8025_$ssb_ptr_t = ^ring_8025_$ssb_t;

  { The system command block (TI's SCB, in the auxiliary area): the
    command and its parameter, an address or four bytes. }
  ring_8025_$scb_t = record
    cmd: integer;                         { 0x00 }
    case integer of                       { 0x02 }
      1: (parm: integer32);
      2: (parm_bytes: array[1..4] of char);
  end;
  ring_8025_$scb_ptr_t = ^ring_8025_$scb_t;

  { A list's data descriptor (TI's): a mark bit and the byte count, then
    the data's physical address. }
  ring_8025_$data_count_t = packed record
    mark: boolean;                        { bit 15 }
    count: 0..32767;                      { bits 14..0 }
  end;
  ring_8025_$data_desc_t = record
    cnt: ring_8025_$data_count_t;         { 0x00 }
    pa: integer32;                        { 0x02 }
  end;

  { A transmit or receive list, 0x24 bytes: TI's forward pointer (the
    next list's physical address), the CSTAT word (its flags byte, then
    the frame status the adapter returns), the frame size and three data descriptors; then the host's own: the
    next list's and the buffer's virtual addresses. }
  ring_8025_$cstat_t = [byte] set of 0..7;
  ring_8025_$list_ptr_t = ^ring_8025_$list_t;
  ring_8025_$list_t = record
    forward: integer32;                   { 0x00 }
    cstat: ring_8025_$cstat_t;            { 0x04 }
    fstat: ring_8025_$byte_t;             { 0x05: a transmitted frame's
                                            frame status }
    frame_size: integer;                  { 0x06 }
    data: array[1..r8025_list_data] of ring_8025_$data_desc_t;  { 0x08 }
    next: ring_8025_$list_ptr_t;          { 0x1A }
    buf: univ_ptr;                        { 0x1E }
    unused_22: integer;                   { 0x22 }
  end;

  { A piece of a frame to transmit, 8 bytes: its physical address and
    its length; a transmit takes an array of them, the first three for
    the first list's data descriptors, the rest for the next list's. }
  ring_8025_$xmit_piece_t = record
    pa: integer32;                        { 0x00 }
    cnt: packed record                    { 0x04 }
      len: 0..32767;                      { bits 15..1 }
    end;
    unused_6: integer;                    { 0x06 }
  end;
  ring_8025_$xmit_pieces_t = array[1..6] of ring_8025_$xmit_piece_t;

  { The open parameters (TI's), 0x20 bytes: the options, the station
    address, the group and functional addresses, the lists' sizes, the
    buffer size, the adapter's buffer memory, the transmit buffers'
    minimum and maximum, and the product ID's physical address. }
  ring_8025_$open_parms_t = record
    options: integer;                     { 0x00 }
    node: ring_8025_$addr_t;              { 0x02 }
    group: integer32;                     { 0x08 }
    funct: integer32;                     { 0x0C }
    rcv_list_size: integer;               { 0x10 }
    xmit_list_size: integer;              { 0x12 }
    buf_size: integer;                    { 0x14 }
    ram_start: integer;                   { 0x16 }
    ram_end: integer;                     { 0x18 }
    xmit_buf_min: ring_8025_$byte_t;      { 0x1A }
    xmit_buf_max: ring_8025_$byte_t;      { 0x1B }
    product_id_pa: integer32;             { 0x1C }
  end;

  { The adapter's error counters, 14 bytes, as the read error log
    command returns them (TI's order): the line, internal, burst and
    A/C errors, the abort delimiters (read with the reserved byte after
    them as one word), the lost frames, the receive congestions, the
    frame copied, frequency and token errors, a reserved byte and the
    DMA bus and parity errors.  The driver adds each read into the
    unit's statistics. }
  ring_8025_$error_log_t = record
    line_errors: ring_8025_$byte_t;       { 0x00 }
    internal_errors: ring_8025_$byte_t;   { 0x01 }
    burst_errors: ring_8025_$byte_t;      { 0x02 }
    ac_errors: ring_8025_$byte_t;         { 0x03 }
    abort_delimiters: ring_8025_$word_t;  { 0x04 }
    lost_frames: ring_8025_$byte_t;       { 0x06 }
    rcv_congestion: ring_8025_$byte_t;    { 0x07 }
    frame_copied_errors: ring_8025_$byte_t;  { 0x08 }
    frequency_errors: ring_8025_$byte_t;  { 0x09 }
    token_errors: ring_8025_$byte_t;      { 0x0A }
    reserved_0b: ring_8025_$byte_t;       { 0x0B }
    dma_bus_errors: ring_8025_$byte_t;    { 0x0C }
    dma_parity_errors: ring_8025_$byte_t; { 0x0D }
  end;

  { A unit's control area in the auxiliary area (0x1800 bytes, six
    pages, backed by contiguous physical pages): the transmit and
    receive lists, the system status block, the open parameters, the
    system command block, the headers of the Domain packets sent, the
    adapter's error counters, the product ID and the receive lists'
    frame buffer; the rest is not decoded yet. }
  ring_8025_$ctl_area_t = record
    xmit: array[1..r8025_xmit_lists] of ring_8025_$list_t;  { 0x000 }
    rcv: array[1..r8025_rcv_lists] of ring_8025_$list_t;    { 0x06C }
    ssb: ring_8025_$ssb_t;                { 0x0B4 }
    open_parms: ring_8025_$open_parms_t;  { 0x0BC }
    scb: ring_8025_$scb_t;                { 0x0DC }
    xmit_hdr: ring_8025_$mac_hdr_t;       { 0x0E2: a Domain packet's MAC
                                            header, the LLC header after
                                            its routing field }
    unused_102: array[0..19] of char;     { 0x102 }
    error_log: ring_8025_$error_log_t;    { 0x116 }
    product_id: array[0..17] of char;     { 0x124 }
    unused_136: array[0..713] of char;    { 0x136 }
    frame: array[0..r8025_frame_size - 1] of char;  { 0x400: the receive
                                            lists' frame buffer }
    unused_1598: array[0..615] of char;   { 0x1598 }
  end;

  { A route to a station, 0x28 bytes: the station's address, the
    routing field to it (its direction already reversed; a zero length
    for a station on this ring), and the TIME_$CLOCKH value at which it
    expires. }
  ring_8025_$route_t = record
    station: ring_8025_$addr_t;           { 0x00 }
    rif: ring_8025_$rif_t;                { 0x06 }
    unused_18: array[0..11] of char;      { 0x18 }
    expiry: time_$clockh_t;               { 0x24 }
  end;

  { A unit's route cache in the auxiliary area (0x1E00 bytes). }
  ring_8025_$route_cache_t = array[0..r8025_route_buckets,
                                   0..r8025_route_ways] of ring_8025_$route_t;

  { The auxiliary area (the map's RING8025_$AUX_DA, 0x8000 bytes): the
    two units' pairs of window pages (first mapped to the unit
    record's page), a page mapped at the start, and the two units'
    control areas and route caches.  The driver wires the control area's
    six pages and the route cache's eight from the area's start.  With
    `ring_8025_dma_channel' there is no map page (0x7C00 bytes, the
    route caches from 0x4000). }
  ring_8025_$page_t = array[0..1023] of char;
  ring_8025_$aux_t = record
    windows: array[0..r8025_max_unit, 1..2] of ring_8025_$page_t;  { 0x0000 }
    ctl: array[0..r8025_max_unit] of ring_8025_$ctl_area_t;   { 0x1000 }
%if not ring_8025_dma_channel %then
    map_page: ring_8025_$page_t;                 { 0x4000 }
%endif
    routes: array[0..r8025_max_unit] of ring_8025_$route_cache_t;  { 0x4400 }
  end;

  { A frame queued for RING_8025_$NULLSAP_HELPER, 0x1C bytes: its data
    pages, its header page's virtual and physical addresses, the header's
    length and the data's. }
  ring_8025_$nullsap_entry_t = record
    data_pages: pkt_$data_pages_t;        { 0x00 }
    hdr_va: integer32;                    { 0x10 }
    hdr_pa: integer32;                    { 0x14 }
    hdr_len: pinteger;                    { 0x18 }
    data_len: pinteger;                   { 0x1A }
  end;

  { A unit's number, by address: RING_8025_$NULLSAP_HELPER's datum. }
  ring_8025_$unit_num_ptr_t = ^pinteger;

  { A channel of a unit, 10 bytes: it is open; its frames lose their
    routing field before they are delivered; the address space that
    opened it; its socket (r8025_os_socket for one the system opened);
    the version of its open's request; its LLC classes. }
  ring_8025_$chan_t = record
    open: boolean;                        { 0x00 }
    strip_rif: boolean;                   { 0x01 }
    asid: integer;                        { 0x02 }
    socket: pinteger;                     { 0x04 }
    version: integer;                     { 0x06 }
    llc_class: integer;                   { 0x08 }
  end;

  { A unit's flags (members: the r8025_unit_ constants). }
  ring_8025_$unit_flags_t = set of 0..15;

  { A received frame's type, a longword: zero, the destination SAP and
    the word at the SNAP header's type, the 24 bits a channel's range
    holds. }
  ring_8025_$ftype_t = record
    case integer of
      1: (all: linteger);                 { 0x00 }
      2: (zero: ring_8025_$byte_t;        { 0x00 }
          sap: ring_8025_$byte_t;         { 0x01 }
          snap: ring_8025_$word_t);       { 0x02 }
  end;

  { A range of frame types a channel receives, 12 bytes: the lowest and
    the highest type (the SAP and the SNAP type, 24 bits), and the
    channel. }
  ring_8025_$range_t = record
    low: linteger;                        { 0x00 }
    high: linteger;                       { 0x04 }
    chan: pinteger;                       { 0x08 }
    unused_0a: integer;                   { 0x0A }
  end;
  ring_8025_$range_list_t = array[1..32] of ring_8025_$range_t;

{ TODO(pascal) a range's size: 12 bytes apart in the table, 10 copied

  Every routine that indexes the table steps 12 bytes a range, and the
  unit record's 0x408 (range_count) follows 32 of them from 0x288; but
  RING_8025_$SVC_CLOSE's (and _$SVC_IOCTL's, _$PROC2_CLEANUP's)
  `u^.ranges[j] := u^.ranges[u^.range_count]' moves only 10 bytes (two
  longwords and a word), the record's fields without the word at 0x0A.  A 10-byte record in an array padded to 12
  would give both; dpc pads no array element, so the record keeps
  unused_0a and the copy moves 12 bytes. }

  { An element of a caller's buffer vector, 6 bytes: the buffer's
    address and length. }
  ring_8025_$iov_t = record
    va: integer32;                        { 0x00 }
    len: pinteger;                        { 0x04 }
  end;
  ring_8025_$iov_array_t = array[1..16] of ring_8025_$iov_t;

  { A range of frame types an open asks for, 8 bytes: the lowest and the
    highest type (only their low 24 bits are kept), or the two as frame
    types (RING_8025_$OPEN_OS sets their SAP bytes). }
  ring_8025_$type_range_t = record
    case integer of
      1: (low: linteger;                  { 0x00 }
          high: linteger);                { 0x04 }
      2: (low_type: ring_8025_$ftype_t;   { 0x00 }
          high_type: ring_8025_$ftype_t); { 0x04 }
  end;

  { The arguments of a channel's open, 0x88 bytes: the version of the
    record (2 at most), the ranges' count and the ranges, the LLC classes
    the channel takes and whether its frames lose their routing field
    (non-zero).  The results are the channel and its socket's EC2
    eventcount. }
  ring_8025_$open_args_t = record
    case integer of
      1: (version: integer;               { 0x00 }
          count: pinteger;                { 0x02 }
          ranges: array[1..16] of ring_8025_$type_range_t;  { 0x04 }
          llc_class: integer;             { 0x84 }
          strip_rif: integer);            { 0x86 }
      2: (channel: integer;               { 0x00 }
          ec2_handle: ec2_$ptr_t);        { 0x02 }
  end;

  { A unit's statistics, 0x66 bytes (RING_8025_$GET_STATS's block): the
    frames received; the frames transmitted; those whose address a
    station recognized but did not copy (sent again); those no station
    recognized; the adapter's commands that did not complete; the
    received frames a user channel's socket refused; the interrupts of
    another type; the transmits with an error or another frame status
    (sent again); the adapter checks (the adapter set up again); the
    tries to put the adapter back on the ring; the removals from the
    ring, by another station and by the adapter itself; the sums of the
    adapter's error counters (ring_8025_$error_log_t).  The unused_
    fields hold the places of the rest.  The 25 counters are also an
    array, which RING_8025_$INIT clears. }
  ring_8025_$stats_t = record
    unused_00: integer;                   { 0x00 }
    case integer of
      1: (rcv_frames: integer32;          { 0x02 }
          xmit_ok: integer32;             { 0x06 }
          xmit_not_copied: integer32;     { 0x0A }
          xmit_unrecognized: integer32;   { 0x0E }
          cmd_failures: integer32;        { 0x12 }
          rcv_refused: integer32;         { 0x16 }
          other_ints: integer32;          { 0x1A }
          xmit_errors: integer32;         { 0x1E }
          adapter_checks: integer32;      { 0x22 }
          reopen_tries: integer32;        { 0x26 }
          removes: integer32;             { 0x2A }
          auto_removals: integer32;       { 0x2E }
          line_errors: integer32;         { 0x32 }
          internal_errors: integer32;     { 0x36 }
          burst_errors: integer32;        { 0x3A }
          ac_errors: integer32;           { 0x3E }
          abort_delimiters: integer32;    { 0x42 }
          lost_frames: integer32;         { 0x46 }
          rcv_congestion: integer32;      { 0x4A }
          frame_copied_errors: integer32; { 0x4E }
          frequency_errors: integer32;    { 0x52 }
          token_errors: integer32;        { 0x56 }
          reserved_0b: integer32;         { 0x5A }
          dma_bus_errors: integer32;      { 0x5E }
          dma_parity_errors: integer32);  { 0x62 }
      2: (counts: array[1..25] of integer32);  { 0x02 }
  end;
  ring_8025_$stats_ptr_t = ^ring_8025_$stats_t;

  { The arguments of a user channel's control request
    (RING_8025_$SVC_IOCTL): the channel and the request (r8025_ioctl_*),
    then the request's own: a value (a largest frame, a routing setting);
    a new functional or group address; the version of the arguments, a
    count of frame-type ranges and the ranges; where the statistics go
    and the room there.  The answer word, or an address, is returned from
    the start. }
  ring_8025_$ioctl_args_t = record
    case integer of
      1: (channel: pinteger;              { 0x00 }
          req: integer;                   { 0x02 }
          value: integer);                { 0x04 }
      2: (hdr_2: integer32;               { 0x00 }
          new_addr: ring_8025_$addr_t);   { 0x04 }
      3: (hdr_3: integer32;               { 0x00 }
          version: integer;               { 0x04 }
          count: pinteger;                { 0x06 }
          ranges: array[1..16] of ring_8025_$type_range_t);  { 0x08 }
      4: (hdr_4: integer32;               { 0x00 }
          unused_04: integer;             { 0x04 }
          stats: ring_8025_$stats_ptr_t;  { 0x06 }
          max_len: pinteger);             { 0x0A }
      5: (result: integer);               { 0x00 }
      6: (station: ring_8025_$addr_t);    { 0x00 }
  end;

  { A unit's record (0x434 bytes; the map's RING8025_UCB section,
    0x868 bytes, holds the two units).  The fields are those the
    translated routines reach; the unused_ fields hold the places of
    the rest. }
  ring_8025_$unit_t = record
    flags: ring_8025_$unit_flags_t;       { 0x000 }
    wired: boolean;                       { 0x002: the record is wired }
    routes_wired: boolean;                { 0x003: the route cache is }
    ctl_wired: boolean;                   { 0x004: the control area is }
    routing: boolean;                     { 0x005: the unit uses source
                                            routing }
    max_frame: integer;                   { 0x006: the largest frame the
                                            ring takes }
    llc_class: integer;                   { 0x008: the LLC classes, an
                                            XID's class byte }
    unused_00a: integer;                  { 0x00A }
    nullsap_q: array[0..r8025_nullsap_max] of ring_8025_$nullsap_entry_t;
                                          { 0x00C: the null SAP's frames }
    nullsap_count: integer;               { 0x0EC: the frames queued }
    nullsap_out: pinteger;                { 0x0EE: the next to answer }
    nullsap_in: integer;                  { 0x0F0: the next free entry }
    unused_0f2: integer;                  { 0x0F2 }
    nullsap_lock: ml_$exclusion_t;        { 0x0F4: the queue's }
    unused_106: integer;                  { 0x106 }
    lock: ml_$exclusion_t;                { 0x108: held around the
                                            starts and the opens }
    unused_11a: integer;                  { 0x11A }
    route_lock: ml_$exclusion_t;          { 0x11C: the route cache's }
    unused_12e: integer;                  { 0x12E }
    users: integer;                       { 0x130: the starts and channel
                                            opens not yet undone }
    cnum: integer;                        { 0x132: the DCTE's unit }
    io_unit: io_$unit_num_t;              { 0x134 }
    port: integer;                        { 0x136: the MAC_OS port }
    xmit_lock: ml_$exclusion_t;           { 0x138: held around the open
                                            and each transmit }
    unused_14a: integer;                  { 0x14A }
    regs: ring_8025_$regs_ptr_t;          { 0x14C }
    dcte: dcte_ptr_t;                     { 0x150 }
    rcv_wake_ec: ec_$eventcount_t;        { 0x154: wakes the receive
                                            process }
    rcv_exit_ec: ec_$eventcount_t;        { 0x160: the receive process's
                                            exit }
    win1_va: univ_ptr;                    { 0x16C: the unit's windows, }
    win1_pmape: univ_ptr;                 { 0x170   their page table }
    win2_va: univ_ptr;                    { 0x174   entries' addresses }
    win2_pmape: univ_ptr;                 { 0x178 }
    scb_ec: ec_$eventcount_t;             { 0x17C: advanced as commands
                                            complete }
    scb_wait_val: integer32;              { 0x188 }
    route_ec: ec_$eventcount_t;           { 0x18C: advanced as routes are
                                            learned }
    route_wait_val: integer32;            { 0x198 }
    group_addr: ring_8025_$addr_t;        { 0x19C: the group address }
    funct_addr: ring_8025_$addr_t;        { 0x1A2: the functional
                                            address }
    stats: ring_8025_$stats_t;            { 0x1A8 }
    unused_20e: integer;                  { 0x20E }
    chan_lock: ml_$exclusion_t;           { 0x210: the channels' and the
                                            ranges' }
    unused_222: integer;                  { 0x222 }
    channels: array[1..r8025_max_chan] of ring_8025_$chan_t;
                                          { 0x224: the open channels }
    ranges: ring_8025_$range_list_t;      { 0x288: the channels' types }
    range_count: pinteger;                { 0x408 }
    dma_channel: integer;                 { 0x40A: the unit's DMA
                                            channel, 6 for unit 0, 5 for
                                            unit 1 (used with
                                            `ring_8025_dma_channel') }
    rcv_ssb: ring_8025_$ssb_t;            { 0x40C: the status block of the
                                            last receive status }
    cmd_ssb: ring_8025_$ssb_t;            { 0x414: of the last command }
    ring_ssb: ring_8025_$ssb_t;           { 0x41C: of the last ring
                                            status }
    rcv_list: ring_8025_$list_ptr_t;      { 0x424: the first receive list }
    xmit_list: ring_8025_$list_ptr_t;     { 0x428: the first transmit list }
    ssb: ring_8025_$ssb_ptr_t;            { 0x42C: the status block }
    scb: ring_8025_$scb_ptr_t;            { 0x430 }
  end;
  ring_8025_$unit_ptr_t = ^ring_8025_$unit_t;

{ ring_8025_$unit_t's unused_ fields (the word after each exclusion
  lock, and 0x00A and 0x0F2) and the auxiliary area's are places no
  routine of the module addresses. }

  { The driver record (net_io/net_io.ins.pas net_io_$driver_t's
    layout, 0x50 bytes, its names).  Every entry is univ_ptr, as
    ethernet/ethernet_3c505.ins.pas's ethernet_$driver_t. }
  ring_8025_$driver_t = record
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
  { The marks around the driver's code (RING8025_PROC_ST,
    RING8025_PROC_EN) and data (RING8025_DATA_ST, RING8025_DATA_EN),
    sections of their own: the driver wires from one to the other. }
  ring8025_proc_st: extern char;
  ring8025_proc_en: extern char;
  ring8025_data_st: extern char;
  ring8025_data_en: extern char;

  { RING_8025_$NETWORK_UID (map symbol in UID_LIST's run of the
    network-type UIDs, with NIL_$NETWORK_UID, uid/uid.ins.pas). }
  ring_8025_$network_uid: extern uid_$t;

{ The MMU headings the driver calls (see the TODO(pascal) in
  ethernet/ethernet_3c505.ins.pas): the SAU9's MMU_$REMOVE takes a word
  after its longword (0 at the receive process's call), where
  mmu/mmu.ins.pas declares the SAU2's one-argument form, so this module
  does not include that file and declares the six it calls here, the
  others as mmu/mmu.ins.pas has them. }

{ MMU_$REMOVE (hand-written): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);

{ MMU_$INSTALL (hand-written): the page number and the virtual address,
  longwords, then the ASID and the protection, all by value. }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

{ MMU_$VTOP (hand-written): the virtual address by value; the page
  number in D0. }
function mmu_$vtop(va: integer32; out status: status_$t): integer32;
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

{ The RING_8025 map routines, in map order. }

{ RING_8025_$NULLSAP_HELPER - answer the frames sent to the null SAP.
  A DXM callback (dxm/dxm.ins.pas dxm_$callback_t): the address of its
  datum's address, the unit's number. }
procedure ring_8025_$nullsap_helper(in unit_ptr: ring_8025_$unit_num_ptr_t);
  extern;

{ RING_8025_$INIT - initialize a token-ring controller.  The DCTE's
  initialization routine (dcte_t, io/io.ins.pas), as ETHERNET_$INIT. }
function ring_8025_$init(var dcte: dcte_t): integer32; extern;

{ RING_8025_$START and RING_8025_$STOP - start and stop a unit.  The
  driver record's start and stop entries: the unit and the status by
  address. }
procedure ring_8025_$start(in unit: pinteger; out status: status_$t); extern;
procedure ring_8025_$stop(in unit: pinteger; out status: status_$t); extern;

{ RING_8025_$LOAD - the driver record's detach entry, the shape of NET's
  control entries (net/net.ins.pas net_$ctl_proc_t). }
procedure ring_8025_$load(var unit: pinteger; var unused2: univ integer32;
                          unused3: integer; var unused4: univ integer32;
                          out status: status_$t);
  options(extern, val_param);

{ RING_8025_$SEND - send a Domain packet.  The driver record's sendp
  entry (net_io/net_io.ins.pas net_io_$sendp_t's shape). }
procedure ring_8025_$send(var socket: pinteger; hdr_pa: integer32;
                          hdr: pkt_$hdr_ptr_t; hdr_len: integer;
                          in data_pages: univ pkt_$data_pages_t;
                          data_va: integer32; data_len: pinteger;
                          in flags: univ integer;
                          out xmit_status: pinteger;
                          out status_ret: status_$t);
  options(extern, val_param);

{ RING_8025_$GET_STATS and RING_8025_$GET_STATS2 - return a unit's
  statistics.  The driver record's get_stats and get_stats2 entries. }
procedure ring_8025_$get_stats(var socket: univ pinteger; stats_buf: univ_ptr;
                               max_len: integer; out length_ret: integer;
                               out status_ret: status_$t);
  options(extern, val_param);
procedure ring_8025_$get_stats2(var socket: univ pinteger;
                                stats_buf: univ_ptr; max_len: integer;
                                out length_ret: integer;
                                out status_ret: status_$t);
  options(extern, val_param);

{ RING_8025_$IOCTL - a unit's control request.  The driver record's
  ioctl entry, the shape of NET's control entries. }
procedure ring_8025_$ioctl(var unit: pinteger; var unused2: univ integer32;
                           unused3: integer; var unused4: univ integer32;
                           out status: status_$t);
  options(extern, val_param);

{ RING_8025_$SVC_OPEN and RING_8025_$SVC_CLOSE - open and close a user
  channel.  The driver record's svc_open and svc_close entries. }
procedure ring_8025_$svc_open(var unit: pinteger;
                              var args: ring_8025_$open_args_t;
                              unused3: integer; var unused4: univ integer32;
                              out status: status_$t);
  options(extern, val_param);
procedure ring_8025_$svc_close(var unit: pinteger; var channel: pinteger;
                               unused3: integer; var unused4: univ integer32;
                               out status: status_$t);
  options(extern, val_param);

{ RING_8025_$SVC_READ and RING_8025_$SVC_WRITE - receive and send a
  frame on a user channel.  The driver record's svc_read and svc_write
  entries, the shape of NET's transfer entries (net/net.ins.pas
  net_$xfer_proc_t). }
procedure ring_8025_$svc_read(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              var iov: univ ring_8025_$iov_array_t;
                              iov_cnt: integer; out len_out: pinteger;
                              out status: status_$t);
  options(extern, val_param);
procedure ring_8025_$svc_write(var unit: pinteger; var channel: pinteger;
                               unused3: integer; var unused4: univ integer32;
                               var iov: univ ring_8025_$iov_array_t;
                               iov_cnt: integer;
                               var unused7: univ integer32;
                               out status: status_$t);
  options(extern, val_param);

{ RING_8025_$SVC_IOCTL - a user channel's control request.  The driver
  record's svc_ioctl entry, the shape of NET's control entries: the
  unit, the arguments (the channel and the request first), two unused
  slots, the status. }
procedure ring_8025_$svc_ioctl(var unit: pinteger;
                               var args: ring_8025_$ioctl_args_t;
                               unused3: integer; var unused4: univ integer32;
                               out status: status_$t);
  options(extern, val_param);

{ RING_8025_$PROC2_CLEANUP - close every channel an address space
  holds.  The driver record's proc2_cleanup entry. }
procedure ring_8025_$proc2_cleanup(var unit: pinteger; asid: integer);
  options(extern, val_param);

{ RING_8025_$OPEN_OS, RING_8025_$CLOSE_OS and RING_8025_$SEND_OS - open,
  close and send on a system channel for MAC_OS.  The driver record's
  open_os, close_os and send_os entries (mac_os/mac_os.ins.pas). }
procedure ring_8025_$open_os(line: pinteger;
                             var params: mac_os_$open_params_t;
                             out status: status_$t);
  options(extern, val_param);
procedure ring_8025_$close_os(line: pinteger; var callback_data: integer;
                              out status: status_$t);
  options(extern, val_param);
procedure ring_8025_$send_os(line: integer; var callback_data: pinteger;
                             var pkt: mac_os_$send_pkt_t;
                             out bytes_sent: integer; out status: status_$t);
  options(extern, val_param);

{ RING_8025_$INT - a unit's interrupt routine, which IO_$ACQUIRE
  registers with the unit's DCTE: the DCTE's address by value; true in
  D0 (`st D0b'). }
function ring_8025_$int(dcte: integer32): boolean;
  options(extern, val_param);

{ RING_8025_$RCV0 and RING_8025_$RCV1 - the two units' receive
  processes: process entry points, no arguments (ring_8025_start_unit's
  PROC1_$CREATE_P calls). }
procedure ring_8025_$rcv0; extern;
procedure ring_8025_$rcv1; extern;
