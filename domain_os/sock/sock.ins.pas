{ sock/sock.ins.pas - SOCK_ (network sockets), for the Domain Pascal
  tree.

  The socket descriptor, the packet record, the descriptor pointer
  table and the routines' headings.  No customer insert file declares
  these.  Include base/base.ins.pas, ec/ec.ins.pas and pkt/pkt.ins.pas
  before it.
}

const
  { The members of the packet record's flags (bits 0, 1, 2 of the word):
    a word set, member k bit k. }
  sock_pkt_flag_local      = 0;
  sock_pkt_flag_xns        = 1;
  sock_pkt_flag_demux_bool = 2;

  { The sockets, 1..0xE0 (the two tables of SOCK's block). }
  sock_max_number = 224;

  { The set members of the descriptor's flag word (sock_$flags_t
    below). }
  sock_flag_allocated = 13;
  sock_flag_user_mode = 14;
  sock_flag_open = 15;

  { The first socket number on the free list (SOCK_$OPEN, SOCK_$CLOSE,
    SOCK_$INIT test it). }
  sock_first_dynamic = 32;

type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), the form of
    suma/suma.ins.pas's suma_$byte_t. }
  sock_$byte_t = [byte] 0..255;

  { The packet record's flags, a word set (above). }
  sock_$pkt_flags_t = set of 0..15;

  { The descriptor's flag word (bits 15, 14, 13 open, user mode,
    allocated; bits 12..0 the socket's number), read and written as
    fields and as a word set (member k bit k), so a variant of a packed
    record (ref 3.10.3, 3.10.7). }
  sock_$flag_set_t = set of 0..15;
  sock_$flags_t = packed record
    case integer of
      1: (open: boolean;                  { bit 15 }
          user_mode: boolean;             { bit 14 }
          allocated: boolean;             { bit 13 }
          number: 0..8191);               { bits 12..0 }
      2: (members: sock_$flag_set_t);
  end;

  { The socket descriptor, 0x1C bytes. }
  sock_$sock_t = record
    ec: ec_$eventcount_t;                 { 0x00 }
    queue_head: integer32;                { 0x0C }
    queue_tail: integer32;                { 0x10 }
    max_queue: sock_$byte_t;              { 0x14 }
    queue_count: sock_$byte_t;            { 0x15 }
    flags: sock_$flags_t;                 { 0x16 }
    max_data_len: pinteger;               { 0x18 }
    hdr_pages: sock_$byte_t;              { 0x1A }
    data_pages: sock_$byte_t;             { 0x1B }
  end;
  sock_$sock_ptr_t = ^sock_$sock_t;

  { The bytes of a packet's header buffer: SOCK_$PUT_INT stores the queue
    count at +0x0F. }
  sock_$hdr_bytes_t = array[0..15] of sock_$byte_t;
  sock_$hdr_bytes_ptr_t = ^sock_$hdr_bytes_t;

  { SOCK_LIST's record, 0x20 bytes: the free list's head at 0x0C, the
    offset of a descriptor's queue_head, through which the list is
    threaded. }
  sock_$list_t = record
    unused_00: array[0..11] of char;      { 0x00 }
    free_head: integer32;                 { 0x0C }
    unused_10: array[16#10..16#1F] of char;  { 0x10 }
  end;

  { The packet record SOCK_$GET fills and SOCK_$PUT queues, 0x40 bytes.
    hdr is the header buffer's address, an integer32 converted to a
    pointer where it is dereferenced.  hops is indexed from 0. }
  sock_$pkt_info_t = record
    hdr: integer32;                       { 0x00 }
    src_addr: integer32;                  { 0x04 }
    src_port: integer;                    { 0x08 }
    hole_0a: integer;                     { 0x0A }
    dst_addr: integer32;                  { 0x0C }
    flags: sock_$pkt_flags_t;             { 0x10 }
    n_hops: integer;                      { 0x12 }
    hops: array[0..10] of integer;        { 0x14 }
    data_len: pinteger;                   { 0x2A }
    hdr_len: pinteger;                    { 0x2C }
    hole_2e: integer;                     { 0x2E }
    data_pages: pkt_$data_pages_t;       { 0x30 }
  end;

var
  { SOCK_$SOCKET_PTR (map symbol, +0x18A4 of SOCK's block): the
    descriptor pointers of sockets 1..224. }
  sock_$socket_ptr: extern array[1..sock_max_number] of sock_$sock_ptr_t;

  { SOCK_LIST and SOCK_$SOCKET (map symbols, +0x00 and +0x20 of SOCK's
    block; SOCK_LIST without `$', a global all the same): the free
    list's record and the descriptors of sockets 1..224 (0x1C bytes
    each).  sock/sock.pas defines them. }
  sock_list: extern sock_$list_t;
  sock_$socket: extern array[1..sock_max_number] of sock_$sock_t;

{ SOCK_$OPEN - open a socket of a given number. }
function sock_$open(sock_num: pinteger; max_queue: integer;
                    hdr_pages: integer; data_pages: integer;
                    max_data_len: integer): boolean;
  options(extern, val_param);

{ SOCK_$ALLOCATE - allocate a socket from the free list. }
function sock_$allocate(out sock_num: pinteger; max_queue: integer;
                        hdr_pages: integer; data_pages: integer;
                        max_data_len: integer): boolean;
  options(extern, val_param);

{ SOCK_$ALLOCATE_USER - allocate a socket for a user process. }
function sock_$allocate_user(out sock_num: pinteger; max_queue: integer;
                             hdr_pages: integer; data_pages: integer;
                             max_data_len: integer): boolean;
  options(extern, val_param);

{ SOCK_$CLOSE - close a socket. }
procedure sock_$close(sock_num: pinteger); options(extern, val_param);

{ SOCK_$GET - take the next packet off a socket's queue. }
function sock_$get(sock_num: pinteger; out info: sock_$pkt_info_t): boolean;
  options(extern, val_param);

{ SOCK_$PUT - queue a packet on a socket and wake its waiters. }
function sock_$put(sock_num: pinteger; in info: sock_$pkt_info_t;
                   flags: boolean; ec_param1: integer;
                   ec_param2: integer): boolean;
  options(extern, val_param);

{ SOCK_$PUT_INT - check a socket number and queue a packet. }
function sock_$put_int(sock_num: pinteger; in info: sock_$pkt_info_t;
                       flags: boolean; ec_param1: integer;
                       ec_param2: integer;
                       out ec_ret: ec_$eventcount_ptr_t): boolean;
  options(extern, val_param);

{ SOCK_$PUT_INT_INT - append a packet to a socket's queue. }
function sock_$put_int_int(sock: sock_$sock_ptr_t; in info: sock_$pkt_info_t;
                           flags: boolean; ec_param1: integer;
                           ec_param2: integer): integer;
  options(extern, val_param);

{ SOCK_$INIT - set up the socket descriptors. }
procedure sock_$init; extern;
