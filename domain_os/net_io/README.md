# The NET_IO subsystem in Domain Pascal

The network drivers' interface (the send and receive paths, the ports'
creation, statistics and cleanup).

## Layout

Two map modules, so two module files.

`net_io.pas`, `module net_io, wired_proc, wired_data;` (the map segments'
name):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| WIRED_PROC | NET_IO, 0x68C bytes | net_io_$put_in_sock_common, NET_IO_$PUT_IN_SOCK, _$PUT_IN_SOCK_INT, _$COPY_PACKET, _$SEND | none (the heading's) |

Data: the map's NET_IO data segment in WIRED_DATA, 0xAC bytes, through
A5:

| offset | variable | type |
|--------|----------|------|
| +0x00 | NET_IO_$ALL_F_ADDR (`define`d) | integer32, 16#000FFFFF |
| +0x04 | NET_IO_$NIL_DRIVER (`define`d) | net_io_$driver_t, initialized (2, 16#1000, 16#1400; proc2_cleanup NET_IO_$CLEANUP_NIL) |
| +0x54 | NET_IO_$USER_DRIVER (`define`d) | net_io_$driver_t, initialized (2, 16#400; sendp ROUTE_$SEND_USER_PORT, get_stats ROUTE_$READ_USER_STATS, proc2_cleanup NET_IO_$CLEANUP_USER) |
| +0xA4 | RING_$OVERFLOW_OVERFLOW (`define`d) | pinteger |
| +0xA6 | RING_$FILE_OVERFLOW (`define`d) | pinteger |
| +0xA8 | RING_$DELIVERY_FAILED (`define`d) | pinteger |
| +0xAA | 2 bytes: the block's rounding to 4 | |

`net_io_unwired.pas`, `module net_io_unwired;` (the map segments' name;
the block is in .DATA, the default, so the heading names no sections):

| section | code | routines | attribute |
|---------|------|----------|-----------|
| OS_INIT_PROC | NET_IO_UNWIRED, 0xD4 bytes | NET_IO_$BOOT_DEVICE, _$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | NET_IO_UNWIRED, 0x324 bytes | NET_IO_$DEVICE_STAT, _$DEVICE_STAT2, _$CREATE_PORT | none (the default) |
| PROC2_DELETE_PRO | NET_IO_UNWIRED, 0xF8 bytes | NET_IO_$FREE_ASID, _$CLEANUP_NIL, _$CLEANUP_USER | `[section(proc2_delete_pro, proc2_delete_dat)]` |

Data: the map's NET_IO_UNWIRED data segment in .DATA, 0x14 bytes,
through A5 in NET_IO_$CREATE_PORT, by its address in NET_IO_$BOOT_DEVICE
and the cleanup routines:

| offset | variable | type |
|--------|----------|------|
| +0x00 | `net_io_$port_asid` | array[0..7] of integer |
| +0x10 | `net_io_$boot_unit` | integer, initialized 999 |
| +0x12 | `net_io_$boot_port_type` | integer |

`tools/pascal_check.sh` finds `net_io_unwired.pas` by its module heading
(its default list takes any `<sub>/*.pas` that has one).

Routines: twelve globals (every map symbol), one module-local
(`internal`): net_io_$put_in_sock_common, which has no map symbol and
four map-named callers.  None is nested; none is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| net_io_$put_in_sock_common | `put_in_sock_common.pas` |
| NET_IO_$PUT_IN_SOCK | `put_in_sock.pas` |
| NET_IO_$PUT_IN_SOCK_INT | `put_in_sock_int.pas` |
| NET_IO_$COPY_PACKET | `copy_packet.pas` |
| NET_IO_$SEND | `send.pas` |
| NET_IO_$BOOT_DEVICE | `boot_device.pas` |
| NET_IO_$INIT | `init.pas` |
| NET_IO_$DEVICE_STAT | `device_stat.pas` |
| NET_IO_$DEVICE_STAT2 | `device_stat2.pas` |
| NET_IO_$CREATE_PORT | `create_port.pas` |
| NET_IO_$FREE_ASID | `free_asid.pas` |
| NET_IO_$CLEANUP_NIL | `cleanup_nil.pas` |
| NET_IO_$CLEANUP_USER | `cleanup_user.pas` |
| (data) | the blocks in `net_io.pas` and `net_io_unwired.pas`; the constant cells (the set [3] passed to ROUTE_$SERVICE after NET_IO_$CLEANUP_NIL, the ringlog flags and the crash status in the NET_IO segment) |

## Insert files

- `net_io.ins.pas` (reviewed; extended): NET_IO_$NIL_DRIVER unchanged;
  NET_IO_$SEND's heading unchanged by the translation, but its review
  made hdr_ptr `var` (was `in`, which under `val_param` passes a 4-byte
  argument by value, ref 5.2 Table 5-1; the callers push its address;
  `netlog/send_page.pas`'s call text is unchanged), and for the same
  reason NET_IO_$PUT_IN_SOCK's and _INT's hdr_va, NET_IO_$COPY_PACKET's
  hdr_src and the worker's hdr_va.  net_io_$send_info_t.xmit_status is
  pinteger (NET_IO_$SEND sets 16#8008 in it, above integer's range);
  net_io_$data_pages_t is pkt_$data_pages_t itself (the same layout;
  NET_IO_$SEND passes it to NET_IO_$COPY_PACKET's `in` formal); the
  driver record's sendp, get_stats, get_stats2, start and proc2_cleanup
  entries are routine pointer types (the same layout; NET takes only the
  svc_ entries' addresses).  Also: three statuses, net_io_$no_boot_unit,
  the entry types, net_io_$driver_ptr_t, NET_IO_$ALL_F_ADDR,
  NET_IO_$USER_DRIVER, the eleven other headings.  It needs
  ec/ec.ins.pas before it.  Users: `net/net.pas`, `netlog/netlog.pas`.
- `pkt/pkt.ins.pas`: pkt_$hdr_t is the header record (its users passed
  it whole: `network/network.ins.pas`, `netlog/send_page.pas`), with
  pkt_$byte_t, pkt_$hdr_bits_t, pkt_$hdr_flags_t and pkt_$inet_addr_t.
  The layout was checked with `dpc -o` (the offsets 0x2E, 0x38, 0x3A,
  0x40, 0x46 and the size 0x5C).  Users: `app`, `netlog`, `net`,
  `netbuf`, `sock`, and `mac_os/mac_os.pas` (which includes MAC's
  fragments).
- `route/route.ins.pas`: route_$port_t.socket is pinteger (NET_IO
  zero-extends it and passes it to SOCK_$ALLOCATE's pinteger `out`);
  unused_32 is a word, part_34 a record (queue_len, port_ec,
  driver_stats), then four longwords.  Also: the user statistics record
  and ROUTE_$USER_STAT, the short port record, the service operation
  set, ROUTE_$SOCK, ROUTE_$Q_OFLO, status_$route_illegal_op_for_port_type,
  the headings of ROUTE_$SHORT_PORT, _$SERVICE, _$READ_USER_STATS,
  _$SEND_USER_PORT.  It needs ec/ec.ins.pas and pkt/pkt.ins.pas before
  it.  Users: `app`, `net`, `hint`, `mac_os` (with MAC's fragments).
  The review made route_$user_stat_t's variant `in_use; unused_01: char;
  unused_02: array[2..0x8F]`: with the filler array at 1 the record was
  0x92 bytes in dpc (an array field is word-aligned), against the
  image's 0x90 stride.
- `ring/ring.ins.pas`: RING_$DELIVERY_FAILED.  `ring/ringlog.ins.pas`:
  RING_$LOGGING_NOW, RINGLOG_$DATA and its types, RINGLOG_$LOGIT.
- `network/network.ins.pas`: three statuses.  `uid/uid.ins.pas`:
  NIL_$NETWORK_UID, USER_$NETWORK_UID, UNKNOWN_$NETWORK_UID.
- Used as they are: `ec`, `time`, `misc/crash_system`, `os` (OS_$DATA_COPY),
  `node`, `netlog`, `sock`, `netbuf`, `net` (its status), `proc1`,
  `proc2`.

## Open items

Facts of the image's form: net_io_$put_in_sock_common stores the
header's byte 7, widened, in a frame word before it tests it, and copies
the data pages by stepping two pointers up; NET_IO_$COPY_PACKET has its
failure path at the second failure, the first one branching into it;
the 2-byte pushes before the entry calls are the alignment pads.

### TODO(pascal)

- `put_in_sock_common.pas`: the frame has bytes no local accounts for
  (0x68 against about 0x5C).
- `copy_packet.pas`: the frame has no room for the failure loops'
  index.
- `ring/ringlog.ins.pas`: the log buffer's layout is read from one store
  only (NET_IO_$SEND's); RING settles it.

## Named dispatch codes

NET_IO_$CREATE_PORT's port types (its `case ptype of' and the two
`in [1, 2]' tests) are ROUTE's named constants route_$port_type_local
and _routing (route/README.md); the code is unchanged.

Batch 2: NET_IO_$BOOT_DEVICE stores `route_$port_type_ring`,
NET_IO_$CLEANUP_USER passes `route_$port_type_routing`, and NET_IO_$SEND
and put_in_sock_common test `pkt_$routing_local` (pkt/pkt.ins.pas). Boot
port types 4 and 5 stay numbers (route/README.md).
