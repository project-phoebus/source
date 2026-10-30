{ asknode/asknode_info.ins.pas - the node-information request of
  ASKNODE_ (ASKNODE_$INFO, _$GET_INFO and _$INTERNET_INFO): their
  parameter and reply records and their headings, for the Domain Pascal
  tree.

  A second insert file beside asknode/asknode.ins.pas because the reply
  record holds other subsystems' records whole (the request-6 arm copies
  RING_$DATA[0], MEM_$MEM_REC and a DISK_$GET_STATS block into it, the
  request-8 arm CAL_$TIMEZONE), so it needs their insert files, and
  network/network.pas includes asknode/asknode.ins.pas before any of them
  (it uses only ASKNODE_$SERVER's and _$PROPAGATE_WHO's headings).

  os/os.pas includes this file after the ones it needs.  Include
  base/base.ins.pas, ring/ring.ins.pas, disk/disk.ins.pas,
  mem/mem.ins.pas, cal/cal.ins.pas and asknode/asknode.ins.pas before
  it.

  The other records' insert files come before it too: time/time.ins.pas,
  vfmt/vfmt.ins.pas, io/io.ins.pas, peb/peb.ins.pas, proc1/proc1.ins.pas,
  network/network.ins.pas, netlog/netlog.ins.pas, route/route.ins.pas,
  log/log.ins.pas, smd/smd.ins.pas, os/os.ins.pas and hint/hint.ins.pas.
}

type
  { The parts of the parameter block that are copied whole, by the local
    arms or by the remote path into its request.
    - asknode_$signal_t, 12 bytes (request 16#16): the process UID and
      the signal's parameter, passed by address to
      PROC2_$SIGNAL_PGROUP_OS, copied into the request by a byte loop;
    - asknode_$signal2_t, 16 bytes (request 16#35): the same and the
      selector of the inner `case' (compared unsigned: linteger), copied
      by the same loop;
    - asknode_$log_ctl_t, 14 bytes (request 16#25): the ring log's
      start/stop word, NETLOG_$CNTL's command, node and socket by
      address, its kinds copied; copied as three longwords and a word;
    - asknode_$log_req_t, 4 bytes (request 16#31): the first word read
      both as a set (element 0, the word's bit 0 in its low byte) and as
      LOG_$READ's unsigned maximum; the second word LOG_$READ2's offset
      by value; copied as one longword;
    - asknode_$port_key_t, 6 bytes (requests 16#3B, 16#3D, 16#5B): the
      port type and socket ROUTE_$FIND_PORT takes by value, copied as a
      longword and a word. }
  asknode_$signal_t = record
    uid: uid_$t;                          { 0x00 }
    param: status_$t;                     { 0x08 }
  end;
  asknode_$signal2_t = record
    uid: uid_$t;                          { 0x00 }
    param: status_$t;                     { 0x08 }
    selector: linteger;                   { 0x0C }
  end;
  asknode_$log_ctl_t = record
    mode: integer;                        { 0x00 }
    cmd: integer;                         { 0x02 }
    node: integer32;                      { 0x04 }
    sock: integer;                        { 0x08 }
    kinds: netlog_$kinds_t;               { 0x0A }
  end;
  asknode_$log_req_t = record
    case integer of
      1: (flags: set of 0..15;            { 0x00 }
          offset: pinteger);              { 0x02 }
      2: (max_len: pinteger);             { 0x00 }
  end;
  asknode_$port_key_t = record
    port_type: integer;                   { 0x00 }
    socket: integer32;                    { 0x02 }
  end;

  { The request's parameter block ("often a UID"), read by the local
    arms through its slot, loaded once.  Its views, one per request
    whose arm reads it (the labels are the requests; label 1 is the
    remote path's default view, no request's):
    - uid: the UID (requests 16#14, 16#23, 16#2B, 16#4B: to PROC2_'s
      `uid' formals);
    - 16#51 (DISK_$GET_STATS's controller and unit): two words pushed by
      value, integer as the formals;
    - 16#A, VOLX_$GET_INFO's volume index by address; 16#21,
      PROC2_$INFO's process id, tested unsigned: pinteger; 16#57 (and
      16#59), PROC2_$LIST2's and _$ZOMBIE_LIST's start index by address;
      16#16, 16#35, 16#25, 16#31, 16#3B: the records above; 16#3D (and
      16#5B), the unit NET_IO_$DEVICE_STAT takes by value, inside the
      port key's socket; 16#41, the network compared as a longword; 1,
      the longword the remote path copies for any other request.
    The caller's literal 0 (network_$fetch_diskless_info, a 4-byte cell)
    passes because the formals are `univ'.  The variants' tags are the
    request codes of asknode/asknode.ins.pas whose arms read them; 0 and
    1 are views several requests share, not codes. }
  asknode_$param_t = record
    case integer of
      0: (uid: uid_$t);                   { 0x00..0x07 }
      asknode_$req_disk_info:
        (cnum: integer;                     { 0x00 }
         unit: integer);                    { 0x02 }
      asknode_$req_volume_info:
        (vol_idx: integer);                 { 0x00 }
      asknode_$req_proc_info2:
        (pid: pinteger);                    { 0x00 }
      asknode_$req_proc_list2:
        (list_start: integer32);            { 0x00 }
      asknode_$req_signal:
        (sig: asknode_$signal_t);           { 0x00..0x0B }
      asknode_$req_signal2:
        (sig2: asknode_$signal2_t);         { 0x00..0x0F }
      asknode_$req_log_control:
        (log_ctl: asknode_$log_ctl_t);      { 0x00..0x0D }
      asknode_$req_log_read:
        (log: asknode_$log_req_t);          { 0x00..0x03 }
      asknode_$req_port_info:
        (port: asknode_$port_key_t);        { 0x00..0x05 }
      asknode_$req_device_stat:
        (unused_00: integer32;              { 0x00 }
         dev_unit: integer);                { 0x04 }
      asknode_$req_net_route:
        (route_net: integer32);             { 0x00 }
      1: (long: integer32);               { 0x00 }
  end;

  { A longword whose low 20 bits are a node, as the reply's node UIDs
    carry it: merged in place, the value unmasked (a linteger source;
    dpc masks an integer32 one, asknode/README.md), and read as
    the whole longword masked (the form of `network_$paging_file_uid.low
    & 16#FFFFF').  The two views as network/process_paging_request.pas
    network_$ps_log_word_t's. }
  asknode_$node_word_t = record
    case integer of
      1: (all: linteger);
      2: (bits: packed record
                  high: 0..4095;          { bits 31..20 }
                  node: 0..16#FFFFF;      { bits 19..0 }
                end);
  end;

  { Request 16#39's port entry, 6 bytes: the count bumped first and the
    entry addressed as 6 * count from the reply's +4, the socket widened
    signed and stored at +2.  Request 16#55's display entry, 0x12 bytes
    (the entry size the reply carries): the display type, the UID, and
    SMD_$INQ_DISP_INFO's four words after its type, one record
    (smd/smd.ins.pas smd_$disp_dims_t).  Request 16#3D's port counters,
    8 bytes copied whole from the port's +0x54: route/route.ins.pas's
    route_$port_counts_t (route_$port_t's counts). }
  asknode_$port_entry_t = record
    port_type: integer;                   { 0x00 }
    socket: integer32;                    { 0x02 }
  end;
  asknode_$disp_entry_t = record
    display_type: smd_$display_type_t;    { 0x00 }
    uid: uid_$t;                          { 0x02 }
    dims: smd_$disp_dims_t;               { 0x0A..0x11 }
  end;

  { The reply ASKNODE_$INTERNET_INFO fills, as its callers declare it,
    0x200 bytes (asknode/asknode.ins.pas asknode_$reply_t, the raw view).
    Every arm writes the header: the version tested and set, the
    response type, the status.  The version and the response type are
    pinteger: request 16#12's arm compares the version unsigned, and the
    remote path the response type with the request type + 1, both
    widened with zeros.  The rest is a variant per request type, labeled
    with the request it answers (labels 0, 1 and 3 are views no single
    request has), in the order the arms are written (w_08 and w_0e by
    offset).  The probe of offsets and size: asknode/README.md.
    - 6, the node's statistics: the version word 3, the node, the word
      1, NETWORK's eight counters as words, RING_$DATA[0] whole (15
      longwords to +0x20, ring/ring.ins.pas ring_$stats_t, 0x3C bytes),
      DISK_$GET_STATS's block (disk/disk.ins.pas disk_$stats_t, 22
      bytes), MEM_$MEM_REC whole (21 longwords and a word to +0x72,
      mem/mem.ins.pas mem_$mem_rec_t, 0x56 bytes), whose word at +4 is
      then overwritten (mem.board_errors[0], +0x76);
    - 8, the timezone: CAL_$TIMEZONE whole, three longwords to +0x08
      (cal/cal.ins.pas cal_$timezone_rec_t, 12 bytes);
    - 16#C, the paging node: the node longword and NETWORK_$DISKLESS's
      byte;
    - 16#51, a disk's statistics: DISK_$GET_STATS's block and flag;
    - 4 (and 16#18), the node or root UID: the UID copied, its high
      longword negated to +0x12, the node merged at +0x1E
      (asknode_$node_word_t), 1 minus the high longword to +0x22,
      ROUTE_$PORT[0]'s network to +0x26; the remote path reads +0x22 +
      +0x08 and +0x12 + +0x08, the node and the network back; the
      longwords at +0x16 and +0x1A are not addressed;
    - 16#10, four units' statistics, DISK_$GET_STATS's block copied to
      +0x08 + 0x16 * unit;
    - 2, the boot time and the clock's high longword;
    - 16#A, VOLX_$GET_INFO's UID and two counts; the remote path hands
      the UID to HINT_$ADDI;
    - 16#12 (and 16#4F), PROC2_$LIST's count and UIDs, the count
      compared signed: integer; 0x39 UIDs (the maximum);
    - 16#57 (and 16#59), PROC2_$LIST2's count, flag, next index and
      UIDs; 0x3E UIDs, to +0x1FF;
    - 16#14 (and 16#21), PROC2_$GET_INFO's and _$INFO's 0x1F8 bytes;
    - 16#1A, GET_BUILD_TIME's length and text;
    - 16#1C, six UIDs' worth: the count 6 at +0x08, the root, node and
      node-data UIDs at +0x0A, +0x12, +0x1A, the paging file's at +0x22,
      a fifth UID whose low longword at +0x2E takes the node
      (asknode_$node_word_t; its high longword at +0x2A is not written),
      ROUTE_$PORT[0]'s network at +0x36; the remote path reads the count
      signed;
    - 16#1F, the local diagnostics: the version 3, NETWORK_$DISKLESS,
      NETWORK_$MOTHER_NODE, RING_$DATA[0] whole to +0x10,
      NETWORK_$FAILURE_REC whole to +0x4C (four longwords),
      RING_$SWDIAG_DATA whole to +0x5C (seven longwords and a word,
      ring_$swdiag_t), then longwords at +0x5E and +0x76 (inside it: the
      view below) and four words to +0x7A..+0x80;
    - 1, the remote 16#1F's view: NETWORK_$RING_INFO's 0x7A bytes, the
      same span;
    - 16#23, PROC2_$GET_UPIDS's three words;
    - 16#27, the system's description: the word 0x11;
      PROM_$MACHINE_ID's longword at +0x0A; the display type;
      PEB_$GET_INFO's word; the real pages as a word and, at +0x4C, as
      a longword; NETWORK_$DISKLESS; the paging node; the boot volume's
      word at +0x1A (only cleared); MMU_$SYSTEM_REV; the GPU word;
      IO_$GET_CONFIG's four words; the volume count at +0x2A and two
      word arrays indexed by it from 1, eight entries each (the loop
      runs ten times: entries 9 and 10 of the first array would be the
      second's 1 and 2, as the image has it); the word 1 at +0x50;
    - 16#29, the network statistics, in the order of the stores'
      offsets;
    - 16#2B, PROC2_$GET_PID's word;
    - 16#2F, NETWORK_$FAILURE_REC whole (four longwords);
    - 16#31, LOG_$READ's or _$READ2's length and buffer, LOG_$READ2's
      maximum 0x400 bytes, so the reply is 0x40A bytes when this variant
      is the largest; the remote path stores the data length at +0x08;
    - 3, the remote path's view: the reply's data from +0x0A,
      PKT_$SAR_INTERNET's data buffer;
    - 16#33, PROC1_$GET_LIST's count and list;
    - 16#37, ROUTE_$PORT[0]'s network;
    - 16#39, the ports: the count at +0x08, the 6-byte entries from
      +0x0A (asknode_$port_entry_t), then the drivers' UIDs straight
      after the last entry (the arm reaches them through a pointer,
      asknode/internet_info.pas);
    - 16#3B, ROUTE_$SHORT_PORT's record;
    - 16#3D (and 16#5B), a port's device statistics: a 6-byte clock
      copied from the port's +0x4E, the counters
      (route_$port_counts_t), NET_IO_$DEVICE_STAT's length at +0x16, the
      offset of the statistics from +0x08 at +0x18, the device UID at
      +0x1A, the driver's maximum data length widened at +0x22, the
      statistics from +0x26 (0x80 bytes);
    - 16#3F, the routing statistics: two booleans, then the counters in
      the order of their offsets;
    - 16#41, a route: the network, the next hop's node, the expiration,
      the metric widened, the packet count, the state word,
      ROUTE_$SHORT_PORT's record at +0x1C;
    - 16#43, the queue depths: the count and the overflow count, then
      the longwords from +0x0E, ROUTE_$Q_DEPTH's 0x81;
    - 16#47, OS_$BOOT_DEVICE whole (two longwords);
    - 16#49, PROC1_$GET_LOADAV's three longwords;
    - 16#4B, MST_$GET_PRIVATE_SIZE's two longwords and
      MMAP_$GET_WS_SIZ's three, stored to +0x14, +0x10, +0x18;
    - 16#4D, OS_$GET_REV_INFO's record;
    - 16#55, the displays: the count (compared unsigned), the entry
      size, the 0x12-byte entries from +0x0C (asknode_$disp_entry_t).
    The variants' tags are the request codes of asknode/asknode.ins.pas
    whose arms fill them; 0, 1 and 3 are the raw bytes and the remote
    path's two views, not codes. }
  asknode_$info_reply_t = record
    version: pinteger;                    { 0x00 }
    response_type: pinteger;              { 0x02 }
    status: status_$t;                    { 0x04 }
    case integer of
      0: (raw: array[1..504] of char); { 0x08..0x1FF }
      asknode_$req_stats:
        (w_08: integer;                     { 0x08 }
         node: linteger;                    { 0x0A }
         w_0e: integer;                     { 0x0E }
         info_rqst_cnt: pinteger;           { 0x10 }
         pagin_rqst_cnt: pinteger;          { 0x12 }
         pagout_rqst_cnt: pinteger;         { 0x14 }
         read_call_cnt: pinteger;           { 0x16 }
         write_call_cnt: pinteger;          { 0x18 }
         read_viol_cnt: pinteger;           { 0x1A }
         write_viol_cnt: pinteger;          { 0x1C }
         bad_chksum_cnt: pinteger;          { 0x1E }
         ring: ring_$stats_t;               { 0x20..0x5B }
         disk: disk_$stats_t;               { 0x5C..0x71 }
         mem: mem_$mem_rec_t);              { 0x72..0xC7 }
      asknode_$req_timezone:
        (tz: cal_$timezone_rec_t);          { 0x08..0x13 }
      asknode_$req_paging_info:
        (paging_node: linteger;             { 0x08 }
         diskless: boolean);                { 0x0C }
      asknode_$req_disk_info:
        (disk_stats: disk_$stats_t;         { 0x08..0x1D }
         has_disk_stats: boolean);          { 0x1E }
      asknode_$req_node_uid:
        (uid: uid_$t;                       { 0x08 }
         unused_10: integer;                { 0x10 }
         neg_high: integer32;               { 0x12 }
         unused_16: integer32;              { 0x16 }
         unused_1a: integer32;              { 0x1A }
         node_word: asknode_$node_word_t;   { 0x1E }
         one_minus_high: integer32;         { 0x22 }
         network: integer32);               { 0x26 }
      asknode_$req_disk_stats:
        (disks: array[0..3] of disk_$stats_t); { 0x08..0x5F }
      asknode_$req_boot_time:
        (boot_time: time_$clockh_t;         { 0x08 }
         current_clockh: time_$clockh_t);   { 0x0C }
      asknode_$req_volume_info:
        (dir_uid: uid_$t;                   { 0x08 }
         free_blocks: integer32;            { 0x10 }
         total_blocks: integer32);          { 0x14 }
      asknode_$req_proc_list:
        (n_procs: integer;                  { 0x08 }
         proc_uids: array[1..57] of uid_$t); { 0x0A..0x1D1 }
      asknode_$req_proc_list2:
        (n_procs2: integer;                 { 0x08 }
         more: boolean;                     { 0x0A }
         next_index: integer32;             { 0x0C }
         proc_uids2: array[1..62] of uid_$t); { 0x10..0x1FF }
      asknode_$req_proc_info:
        (proc_info: array[1..504] of char); { 0x08..0x1FF }
      asknode_$req_build_time:
        (build_len: integer;                { 0x08 }
         build_time: vfmt_$string_t);       { 0x0A..0xD1 }
      asknode_$req_uids:
        (n_uids: integer;                   { 0x08 }
         root_uid: uid_$t;                  { 0x0A }
         node_uid: uid_$t;                  { 0x12 }
         node_data_uid: uid_$t;             { 0x1A }
         paging_uid: uid_$t;                { 0x22 }
         home_high: integer32;              { 0x2A }
         home_low: asknode_$node_word_t;    { 0x2E }
         unused_32: integer32;              { 0x32 }
         home_network: integer32);          { 0x36 }
      asknode_$req_network_diag:
        (diag_version: integer;             { 0x08 }
         diag_diskless: boolean;            { 0x0A }
         diag_mother: linteger;             { 0x0C }
         diag_ring: ring_$stats_t;          { 0x10..0x4B }
         diag_failure: network_$failure_rec_t; { 0x4C..0x5B }
         diag_swdiag: record                { 0x5C..0x79 }
           case integer of
             1: (data: ring_$swdiag_t);
             2: (unused_00: integer;        { 0x5C }
                 rcvcnt: integer32;         { 0x5E }
                 unused_06: array[1..9] of integer; { 0x62 }
                 unused_18: integer;        { 0x74 }
                 nodeid: integer32);        { 0x76 }
           end;
         xmit_biphase: pinteger;            { 0x7A }
         rcv_biphase: pinteger;             { 0x7C }
         xmit_esb: pinteger;                { 0x7E }
         rcv_esb: pinteger);                { 0x80 }
      1: (ring_info: network_$ring_info_t);  { 0x08..0x81 }
      asknode_$req_proc_upids:
        (upid: pinteger;                    { 0x08 }
         uppid: pinteger;                   { 0x0A }
         upgid: pinteger);                  { 0x0C }
      asknode_$req_system_info:
        (sys_version: integer;              { 0x08 }
         machine_id: integer32;             { 0x0A: PROM_$MACHINE_ID }
         display_type: smd_$display_type_t; { 0x0E }
         peb_flags: peb_$info_bits_t;       { 0x10 }
         real_pages_w: pinteger;            { 0x12 }
         sys_diskless: boolean;             { 0x14 }
         sys_paging_node: linteger;         { 0x16 }
         boot_w: integer;                   { 0x1A }
         system_rev: integer32;             { 0x1C }
         gpu: integer;                      { 0x20 }
         io_config: array[1..4] of io_$config_t; { 0x22..0x29 }
         n_vols: integer;                   { 0x2A }
         vol_types: array[1..8] of pinteger; { 0x2C..0x3B }
         vol_units: array[1..8] of pinteger; { 0x3C..0x4B }
         real_pages: linteger;              { 0x4C }
         w_50: integer);                    { 0x50 }
      asknode_$req_net_stats:
        (ns_version: integer;               { 0x08 }
         paging_backlog: network_$backlog_t; { 0x0A..0x2D }
         paging_overflow: pinteger;         { 0x2E }
         file_backlog: network_$backlog_t;  { 0x30..0x53 }
         file_overflow: pinteger;           { 0x54 }
         overflow_overflow: pinteger;       { 0x56 }
         delivery_failed: pinteger;         { 0x58 }
         net_2long1: pinteger;              { 0x5A }
         attrib_pagout: pinteger;           { 0x5C }
         rem_file_2long1: pinteger;         { 0x5E }
         l_60: integer32;                   { 0x60 }
         xmitcnt: integer32;                { 0x64 }
         xmit_waited: pinteger;             { 0x68 }
         send_null_cnt: pinteger;           { 0x6A }
         clobbered_hdr: pinteger;           { 0x6C }
         rcvcnt: integer32;                 { 0x6E }
         rcv_int_cnt: integer32;            { 0x72 }
         busy_on_rcv_int: pinteger;         { 0x76 }
         abort_cnt: pinteger;               { 0x78 }
         wakeup_cnt: pinteger;              { 0x7A }
         bad_data_cnt: pinteger;            { 0x7C }
         ns_pagin: pinteger;                { 0x7E }
         ns_mult_pagin: pinteger;           { 0x80 }
         ns_pagout: pinteger;               { 0x82 }
         ns_read_call: pinteger;            { 0x84 }
         ns_write_call: pinteger;           { 0x86 }
         ns_read_viol: pinteger;            { 0x88 }
         ns_write_viol: pinteger;           { 0x8A }
         ns_bad_chksum: pinteger;           { 0x8C }
         ns_attrib_rqst: pinteger;          { 0x8E }
         ns_info_rqst: pinteger;            { 0x90 }
         ns_set_attrib_call: pinteger;      { 0x92 }
         ns_rcv_read_ahead: pinteger);      { 0x94 }
      asknode_$req_proc_pid:
        (pid: integer);                     { 0x08 }
      asknode_$req_failure_rec:
        (failure: network_$failure_rec_t);  { 0x08..0x17 }
      asknode_$req_log_read:
        (log_len: pinteger;                 { 0x08 }
         log_buf: array[1..1024] of char); { 0x0A..0x409 }
      3: (data_len_w: integer;            { 0x08 }
          data: array[1..502] of char);  { 0x0A..0x1FF }
      asknode_$req_proc1_list:
        (p1_count: integer;                 { 0x08 }
         p1_list: proc1_$list_t);           { 0x0A..0x109 }
      asknode_$req_route_port:
        (route_network: integer32);         { 0x08 }
      asknode_$req_port_list:
        (n_ports: integer;                  { 0x08 }
         ports: array[1..8] of asknode_$port_entry_t); { 0x0A..0x39 }
      asknode_$req_port_info:
        (short_port: route_$short_port_t);  { 0x08..0x3F }
      asknode_$req_device_stat:
        (port_clock: time_$clock_t;         { 0x08 }
         port_counts: route_$port_counts_t; { 0x0E }
         stat_len: integer;                 { 0x16 }
         stat_offset: integer;              { 0x18 }
         dev_uid: uid_$t;                   { 0x1A }
         max_data_len: linteger;            { 0x22 }
         dev_stats: array[1..128] of char); { 0x26..0xA5 }
      asknode_$req_route_stats:
        (rs_version: integer;               { 0x08 }
         routing: boolean;                  { 0x0A }
         std_routing: boolean;              { 0x0B }
         start_time: time_$clockh_t;        { 0x0C }
         netbuf_alloc: integer;             { 0x10 }
         q_oflo: integer32;                 { 0x12 }
         misroute: integer32;               { 0x16 }
         too_far: integer32;                { 0x1A }
         pkts_routed: integer32;            { 0x1E }
         dlen_err: integer32;               { 0x22 }
         std_misroute: integer32;           { 0x26 }
         std_too_far: integer32;            { 0x2A }
         std_pkts_routed: integer32;        { 0x2E }
         std_dlen_err: integer32);          { 0x32 }
      asknode_$req_net_route:
        (nr_network: integer32;             { 0x08 }
         nr_nexthop: integer32;             { 0x0C }
         nr_expiration: integer32;          { 0x10 }
         nr_metric: integer;                { 0x14 }
         nr_pkts: integer32;                { 0x16 }
         nr_state: integer;                 { 0x1A }
         nr_port: route_$short_port_t);     { 0x1C..0x53 }
      asknode_$req_queue_depth:
        (qd_count: pinteger;                { 0x08 }
         qd_oflo: integer32;                { 0x0A }
         qd_depth: array[0..128] of integer32); { 0x0E..0x211 }
      asknode_$req_boot_device:
        (boot_device: os_$boot_device_t);   { 0x08..0x0F }
      asknode_$req_loadav:
        (loadav: proc1_$loadav_t);          { 0x08..0x13 }
      asknode_$req_proc_ws_info:
        (priv_size: integer32;              { 0x08 }
         priv_rw_size: integer32;           { 0x0C }
         ws_field_14: linteger;             { 0x10 }
         ws_page_count: linteger;           { 0x14 }
         ws_max_pages: linteger);           { 0x18 }
      asknode_$req_rev_info:
        (rev: os_$rev_t);                   { 0x08..0xD7 }
      asknode_$req_display_list:
        (n_displays: pinteger;              { 0x08 }
         disp_entry_size: integer;          { 0x0A }
         displays: array[1..28] of asknode_$disp_entry_t); { 0x0C..0x1FB }
  end;

{ ASKNODE_$INFO - ask a node for information, with the default lengths. }
procedure asknode_$info(in req_type: integer;
                        in node_id: linteger;
                        in param: univ asknode_$param_t;
                        var result: univ asknode_$info_reply_t;
                        out status: status_$t);
  extern;

{ ASKNODE_$GET_INFO - ask a node for information, with the default request
  length. }
procedure asknode_$get_info(in req_type: integer;
                            in node_id: linteger;
                            in param: univ asknode_$param_t;
                            in resp_len: integer;
                            var result: univ asknode_$info_reply_t;
                            out status: status_$t);
  extern;

{ ASKNODE_$INTERNET_INFO - answer a node-information request, locally or
  by asking the node. }
procedure asknode_$internet_info(in req_type: pinteger;
                                 in node_id: linteger;
                                 in req_len: integer32;
                                 in param: univ asknode_$param_t;
                                 in resp_len: integer;
                                 var result: univ asknode_$info_reply_t;
                                 out status: status_$t);
  extern;

{ ASKNODE_$READ_FAILURE_REC - copy out the network failure record. }
procedure asknode_$read_failure_rec(out failure_rec: network_$failure_rec_t);
  extern;
