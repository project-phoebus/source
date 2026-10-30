{ asknode/asknode.ins.pas - ASKNODE_ (the node-information requester), for
  the Domain Pascal tree.

  What the Pascal files use.  Include base/base.ins.pas before it.
}

const
  { ---- The request codes ----

    One constant per request type that ASKNODE_$INTERNET_INFO and
    ASKNODE_$SERVER dispatch on (the image keeps no names for them).

    The replies are, in general, the request + 1: INTERNET_INFO stores
    `result.response_type := req_type + 1' after its local case and for
    the remote 16#1F, and tests the remote reply against it; SERVER
    stores the same.  Reply constants are declared only for the codes
    the code stores by value (SERVER's who and time arms, below); its
    otherwise arm's 0 is no reply code and stays a number. }
  asknode_$req_who = 0;
  asknode_$req_boot_time = 2;
  asknode_$req_node_uid = 4;
  asknode_$req_stats = 6;
  asknode_$req_timezone = 8;
  asknode_$req_volume_info = 16#A;
  asknode_$req_paging_info = 16#C;
  asknode_$req_record_failure = 16#E;
  asknode_$req_disk_stats = 16#10;
  asknode_$req_proc_list = 16#12;
  asknode_$req_proc_info = 16#14;
  asknode_$req_signal = 16#16;
  asknode_$req_root_uid = 16#18;
  asknode_$req_build_time = 16#1A;
  asknode_$req_uids = 16#1C;
  asknode_$req_network_diag = 16#1F;
  asknode_$req_proc_info2 = 16#21;
  asknode_$req_proc_upids = 16#23;
  asknode_$req_log_control = 16#25;
  asknode_$req_system_info = 16#27;
  asknode_$req_net_stats = 16#29;
  asknode_$req_proc_pid = 16#2B;
  asknode_$req_who_remote = 16#2D;
  asknode_$req_failure_rec = 16#2F;
  asknode_$req_log_read = 16#31;
  asknode_$req_proc1_list = 16#33;
  asknode_$req_signal2 = 16#35;
  asknode_$req_route_port = 16#37;
  asknode_$req_port_list = 16#39;
  asknode_$req_port_info = 16#3B;
  asknode_$req_device_stat = 16#3D;
  asknode_$req_route_stats = 16#3F;
  asknode_$req_net_route = 16#41;
  asknode_$req_queue_depth = 16#43;
  asknode_$req_time_sync = 16#45;
  asknode_$req_boot_device = 16#47;
  asknode_$req_loadav = 16#49;
  asknode_$req_proc_ws_info = 16#4B;
  asknode_$req_rev_info = 16#4D;
  asknode_$req_zombie_list = 16#4F;
  asknode_$req_disk_info = 16#51;
  asknode_$req_display_list = 16#55;
  asknode_$req_proc_list2 = 16#57;
  asknode_$req_zombie_list2 = 16#59;
  asknode_$req_device_stat2 = 16#5B;

  { The replies SERVER stores by value, each its request + 1 (after the
    request names).  The who reply (request 16#2D answered as a who
    request when it is for this node); the remote who's; the time's,
    which SERVER also writes into the context as the request type to
    pass on. }
  asknode_$reply_who = 1;
  asknode_$reply_who_remote = 16#2E;
  asknode_$reply_time_sync = 16#46;

  { The who-routines' other constants:
    - the most nodes a who-listing returns, the clamp of WHO_NOTOPO and
      WHO_REMOTE;
    - the socket WHO_REMOTE listens on, passed to SOCK_$OPEN,
      APP_$RECEIVE and SOCK_$CLOSE and as the request's source socket;
      its descriptor is SOCK_$SOCKET_PTR's element 5;
    - the context's done marker 16#DEAF (a word, written -16#2151),
      which PROPAGATE_WHO tests and stores (NETWORK_$REQUEST_SERVER
      writes and tests the same, network/request_server.pas). }
  asknode_$max_who_count = 2000;
  asknode_$who_socket = 5;
  asknode_$done_marker = -16#2151;

type
  { The reply buffer ASKNODE_$INTERNET_INFO fills, 0x200 bytes as its
    callers declare it: network_$fetch_diskless_info passes a 0x200-byte
    frame buffer and the length 16#200.  The formal is `univ', so the
    callers' own record types pass.  The routine's own view of the
    buffer is asknode/asknode_info.ins.pas asknode_$info_reply_t, of
    this size. }
  asknode_$reply_t = array[1..512] of char;

  { The context record ASKNODE_$SERVER hands back to its caller for a
    request to be propagated, 0x22 bytes.  ASKNODE_$SERVER stores the
    request's version, its five longwords from +0x04, the request id and
    the socket, the request type, and for request 16#45 the clock
    (TIME_$CLOCK, then its high word cleared and the low longword
    replaced: base/base.ins.pas time_$clock_t, both views).
    NETWORK_$REQUEST_SERVER sets the version to 16#DEAF (-16#2151)
    before the call and tests it after, clears the clock, and hands it
    to TIME_$ADVANCE as the time.  ASKNODE_$PROPAGATE_WHO tests the
    version and the type, and passes param1, param2, the request id and
    the socket by value.

    The five longwords from +0x04 are one record, asknode_$server_args_t
    (below), because ASKNODE_$SERVER copies them whole from its request
    record (asknode/server.pas): a record assignment, one named type on
    both sides.  The request record reads the same fields at the same
    offsets from its own +0x04 (node_id, param1, param2, forwarded
    tested and cleared, count copied, decremented and compared signed,
    param3).  Probe: asknode/README.md. }
  asknode_$server_args_t = record
    node_id: linteger;                    { 0x00 (ctx 0x04) }
    param1: integer32;                    { 0x04 (ctx 0x08) }
    param2: integer32;                    { 0x08 (ctx 0x0C) }
    forwarded: boolean;                   { 0x0C (ctx 0x10) }
    unused_0d: char;                      { 0x0D (ctx 0x11) }
    count: integer;                       { 0x0E (ctx 0x12) }
    param3: integer32;                    { 0x10 (ctx 0x14) }
  end;                                    { 0x14 bytes }

  asknode_$server_ctx_t = record
    version: integer;                     { 0x00 }
    request_type: integer;                { 0x02 }
    args: asknode_$server_args_t;         { 0x04..0x17 }
    request_id: pinteger;                 { 0x18 }
    socket: pinteger;                     { 0x1A }
    clock: time_$clock_t;                 { 0x1C..0x21 }
  end;

{ ASKNODE_$INTERNET_INFO's heading, written here for OS, is in
  asknode/asknode_info.ins.pas with its parameter and reply records
  (which need RING_'s, DISK_'s, MEM_'s and CAL_'s records), together
  with ASKNODE_$INFO's and _$GET_INFO's. }

{ ASKNODE_$SERVER - answer one node query received on socket 4. }
procedure asknode_$server(var ctx: asknode_$server_ctx_t;
                          var routing: integer32); extern;

{ ASKNODE_$PROPAGATE_WHO - pass a who request on, or answer a time one. }
procedure asknode_$propagate_who(var ctx: asknode_$server_ctx_t;
                                 in routing: integer32); extern;

type
  { The list of node ids the who-routines fill: longwords from 1
    (WHO_REMOTE's stores and reads fold the lower bound, the first
    element at the base; WHO_NOTOPO's at the index count + 1).  linteger
    as node_$me, the value stored.  The bound is the clamp of both,
    asknode_$max_who_count (above); the callers' own lists may be
    shorter. }
  asknode_$node_list_t = array[1..asknode_$max_who_count] of linteger;

{ ASKNODE_$WHO - list the nodes of this node's network. }
procedure asknode_$who(out node_list: asknode_$node_list_t;
                       in max_count: integer;
                       out count: pinteger); extern;

{ ASKNODE_$WHO_NOTOPO - list the nodes of a network without topology. }
procedure asknode_$who_notopo(in node_id: linteger;
                              in port: integer32;
                              out node_list: asknode_$node_list_t;
                              in max_count: integer;
                              out count: pinteger;
                              out status: status_$t); extern;

{ ASKNODE_$WHO_REMOTE - list the nodes of a network through its servers. }
procedure asknode_$who_remote(in node_id: linteger;
                              in port: integer32;
                              out node_list: asknode_$node_list_t;
                              in max_count: integer;
                              out count: pinteger;
                              out status: status_$t); extern;

{ TODO(merge) move to rem_file/rem_file.ins.pas  REM_FILE_$2LONG1 (map
  symbol, one of the cells of the NET_ASM data; a word counter): read as
  a word by ASKNODE_$INTERNET_INFO: pinteger, as NETWORK_$2LONG1. }
var
  rem_file_$2long1: extern pinteger;
