{ net_io/net_io.ins.pas - NET_IO_ (the network drivers' interface), for
  the Domain Pascal tree.

  What the Pascal files use.  No customer insert file declares these.
  Include base/base.ins.pas, ec/ec.ins.pas (NET_IO_$PUT_IN_SOCK_INT's
  eventcount) and pkt/pkt.ins.pas before it.  The modules are
  net_io/net_io.pas (NET_IO) and net_io/net_io_unwired.pas
  (NET_IO_UNWIRED).
}

const
  { The texts are stcode.db.10.2's ("max number of ports already open",
    "no more buffer queues for user networks", "max number of USER ports
    already open").  NET_IO_$CREATE_PORT stores them. }
  status_$net_io_max_ports_open = 16#002B0005;
  status_$net_io_no_user_buffer_queues = 16#002B000B;
  status_$net_io_max_user_ports_open = 16#002B000F;

  { The boot unit NET_IO_$BOOT_DEVICE never wrote: the NET_IO_UNWIRED
    block's initial value at +0x10, which NET_IO_$CREATE_PORT compares
    with. }
  net_io_$no_boot_unit = 999;

type
  { NET_IO_$SEND's report, two words. }
  { xmit_status is unsigned: NET_IO_$SEND sets its bits 15 and 3 in
    place (16#8008, above integer's range), and passes it to the
    driver's pinteger `out' formal (net_io_$sendp_t below);
    PKT_$SEND_INTERNET's compare with 16#2000 for equality is the same
    either way; NETLOG passes the record whole. }
  net_io_$send_info_t = record
    port_net: integer;                    { 0x00 }
    xmit_status: pinteger;                { 0x02 }
  end;

  { The data page addresses NET_IO_$SEND takes, the four that
    PKT_$COPY_TO_PA filled in; NETLOG passes one longword.  The same type
    as pkt_$data_pages_t, which NET_IO_$SEND passes it on as, to
    NET_IO_$COPY_PACKET's `in' formal by address (a formal of another
    array type would not take it). }
  net_io_$data_pages_t = pkt_$data_pages_t;

{ NET_IO_$SEND - send a packet on a network port. }
procedure net_io_$send(port: integer; var hdr_ptr: pkt_$hdr_ptr_t;
                       hdr_pa: integer32; hdr_len: integer;
                       data_va: integer32;
                       in data_pages: univ net_io_$data_pages_t;
                       data_len: integer; flags: integer;
                       out send_info: net_io_$send_info_t;
                       out status_ret: status_$t);
  options(extern, val_param);

type
  { The shapes of the driver record's entries that NET_IO calls, from
    the calls:
    - sendp (NET_IO_$SEND): the port's socket, the flags (NET_IO_$SEND's
      value slot), the transmit status and the status by address, the
      header and the pages by address (the header's address a pointer's
      value, the pages NET_IO_$SEND's own by-address slot), the words
      and longwords by value: `val_param'.  ROUTE_$SEND_USER_PORT's
      frame agrees (route/route.ins.pas).  The header is a pointer by
      value: ROUTE_$SEND_USER_PORT passes the address of its own slot to
      NET_IO_$COPY_PACKET's `var hdr_src: pkt_$hdr_ptr_t', and stores
      the slot's value as the queued packet's header address: a value
      parameter of the pointer type, whose slot is the variable.
      NET_IO_$SEND passes hdr_ptr (net_io/send.pas).  The data length
      is pinteger: ROUTE_$SEND_USER_PORT compares it unsigned.
      flags is `in flags: univ integer', as RING_$SENDP's and
      ROUTE_$SEND_USER_PORT's headings: NETWORK_$REQUEST_SERVER passes
      RING_$SENDP a constant 0 from a cell in its code, which a `var'
      cannot take; `univ' keeps it by address under `val_param' (ref
      5.2, Table 5-1); no entry writes it (ring/ring_driver.ins.pas,
      route/route.ins.pas).
    - get_stats, get_stats2 (NET_IO_$DEVICE_STAT): the index by address
      (the caller's value slot, an integer, where ROUTE_$READ_USER_STATS
      reads it zero-extended: `univ'), the buffer's address as a value
      (the caller's own value slot passed on), the maximum a word by
      value, the length and status slots passed on: `val_param'.
    - start (NET_IO_$INIT): both by address.
    - proc2_cleanup (NET_IO_$FREE_ASID): the socket by address, the
      address space a word by value: `val_param'; NET_IO_$CLEANUP_NIL
      and _USER have this heading (below).
    The names are those of the routines whose addresses the image's
    driver records hold (ROUTE_$SEND_USER_PORT, ROUTE_$READ_USER_STATS,
    NET_IO_$CLEANUP_NIL). }
  net_io_$sendp_t = ^procedure(var socket: pinteger; hdr_pa: integer32;
                               hdr: pkt_$hdr_ptr_t;
                               hdr_len: integer;
                               in data_pages: univ pkt_$data_pages_t;
                               data_va: integer32; data_len: pinteger;
                               in flags: univ integer;
                               out xmit_status: pinteger;
                               out status_ret: status_$t);
                    options(val_param);
  net_io_$stats_proc_t = ^procedure(var socket: univ pinteger;
                                    stats_buf: univ_ptr;
                                    max_len: integer;
                                    out length_ret: integer;
                                    out status_ret: status_$t);
                         options(val_param);
  net_io_$start_proc_t = ^procedure(var socket: pinteger;
                                    out status_ret: status_$t);
  net_io_$cleanup_proc_t = ^procedure(var socket: pinteger; asid: integer);
                           options(val_param);

  { A network driver's record, 0x50 bytes: words, then sixteen entry
    points stored alike (each user converts its slot to the shape it
    calls), then the network type's UID.  NET's dispatchers take the
    offsets of the svc_ entries from NET_IO_$NIL_DRIVER's fields
    (svc_open 0x28; net/net.ins.pas).  The five entries NET_IO calls
    have the routine pointer types above, the others are univ_ptr; the
    record's layout is the same either way (every entry 4 bytes), and
    NET's dispatchers take only addresses of the svc_ entries.  The two
    records in NET_IO's block are initialized with routine addresses
    (net_io/net_io.pas). }
  net_io_$driver_t = record
    unknown0: pinteger;                   { 0x00 }
    max_data_len: pinteger;               { 0x02 }
    mtu: pinteger;                        { 0x04 }
    unknown6: char;                       { 0x06 }
    flags: char;                          { 0x07 }
    sendp: net_io_$sendp_t;               { 0x08 }
    get_stats: net_io_$stats_proc_t;      { 0x0C }
    get_stats2: net_io_$stats_proc_t;     { 0x10 }
    start: net_io_$start_proc_t;          { 0x14 }
    stop: univ_ptr;                       { 0x18 }
    detach: univ_ptr;                     { 0x1C }
    proc2_cleanup: net_io_$cleanup_proc_t;  { 0x20 }
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
  { NET_IO_$NIL_DRIVER (map symbol, +0x04 of NET_IO's block): the nil
    network's driver record; NET's dispatchers address its fields
    (above). }
  net_io_$nil_driver: extern net_io_$driver_t;

  { NET_IO_$ALL_F_ADDR (map symbol, +0 of NET_IO's block, 16#000FFFFF):
    the node mask of an all-ones address.  NET_IO's module-local worker
    and NET_IO_$SEND mask with it and compare with it as a longword:
    integer32. }
  net_io_$all_f_addr: extern integer32;

  { NET_IO_$USER_DRIVER (map symbol, +0x54 of NET_IO's block): the user
    routing ports' driver record, whose address ROUTE_$SERVICE passes
    NET_IO_$CREATE_PORT.  NET_IO_$BOOT_DEVICE stores its UID. }
  net_io_$user_driver: extern net_io_$driver_t;

type
  net_io_$driver_ptr_t = ^net_io_$driver_t;

{ Routine headings, in map order: NET_IO (WIRED_PROC) and
  NET_IO_UNWIRED (OS_INIT_PROC, .TEXT, PROC2_DELETE_PRO).  The bodies
  repeat the full headings (ref 7.3.4, Method 2).  NET_IO_$SEND's is
  above.  The cells passed by address are named after what they hold
  (hdr_va, data_pa, hdr_src), and NET_IO_$CREATE_PORT's port type is
  ptype (the port record's field of the plain name meets it inside the
  routine's `with'). }

{ NET_IO_$PUT_IN_SOCK - deliver a received packet to a socket of this
  node, at process level. }
procedure net_io_$put_in_sock(net_type: integer; socket: pinteger;
                              var hdr_va: integer32;
                              in data_pa: univ pkt_$data_pages_t;
                              hdr_len: pinteger; data_len: pinteger);
  options(extern, val_param);

{ NET_IO_$PUT_IN_SOCK_INT - deliver a received packet to a socket of this
  node, at interrupt level.  A boolean function, the worker's result:
  its one caller, the SAU9 Ethernet driver, tests the result, and
  passes a single page address as the data pages (`univ'). }
function net_io_$put_in_sock_int(net_type: integer; socket: pinteger;
                                 var hdr_va: integer32;
                                 in data_pa: univ pkt_$data_pages_t;
                                 hdr_len: pinteger; data_len: pinteger;
                                 out ec_ret: ec_$eventcount_ptr_t): boolean;
  options(extern, val_param);

{ NET_IO_$COPY_PACKET - copy a packet into fresh network buffers. }
procedure net_io_$copy_packet(var hdr_src: pkt_$hdr_ptr_t;
                              hdr_len: pinteger;
                              src_data_va: integer32;
                              in src_pages: pkt_$data_pages_t;
                              data_len: pinteger;
                              out hdr_va_out: integer32;
                              out data_pages_out: pkt_$data_pages_t;
                              out status_ret: status_$t);
  options(extern, val_param);

{ NET_IO_$BOOT_DEVICE - record the network boot device. }
function net_io_$boot_device(boot_device: integer; boot_unit: integer):
  boolean;
  options(extern, val_param);

{ NET_IO_$INIT - bring up the primary network port. }
procedure net_io_$init; extern;

{ NET_IO_$DEVICE_STAT - a network port's statistics, from its driver. }
procedure net_io_$device_stat(network: integer; index: integer;
                              max_len: integer; out id_ret: uid_$t;
                              stat_buf: univ_ptr;
                              out stat_len_ret: integer;
                              out status_ret: status_$t);
  options(extern, val_param);

{ NET_IO_$DEVICE_STAT2 - a network port's second statistics, from its
  driver. }
procedure net_io_$device_stat2(network: integer; index: integer;
                               max_len: integer; out id_ret: uid_$t;
                               stat_buf: univ_ptr;
                               out stat_len_ret: integer;
                               out status_ret: status_$t);
  options(extern, val_param);

{ NET_IO_$CREATE_PORT - create a network port for a driver. }
function net_io_$create_port(ptype: integer; unit: integer;
                             driver: univ_ptr; queue_size: pinteger;
                             out status_ret: status_$t): integer;
  options(extern, val_param);

{ NET_IO_$FREE_ASID - tell every open port's driver that an address space
  is going away. }
procedure net_io_$free_asid(asid: integer); options(extern, val_param);

{ NET_IO_$CLEANUP_NIL - close a local port its address space created.
  NET_IO_$CLEANUP_USER - close a user port its address space created. }
procedure net_io_$cleanup_nil(var socket: pinteger; asid: integer);
  options(extern, val_param);
procedure net_io_$cleanup_user(var socket: pinteger; asid: integer);
  options(extern, val_param);
