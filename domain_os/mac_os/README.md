# The MAC_OS subsystem in Domain Pascal

The MAC layer's OS side (the channels, the ports' packet-type tables,
the drivers' open, close and send entries, ARP for the link-level
address, the receive demultiplexer).

## Layout

One module, `mac_os.pas`, `module mac_os, wired_proc, wired_data;` (the
map segments' name).  It holds the MAC_ routines of `../mac/` too: the
map has no MAC_ segment, and those six routines lie inside MAC_OS's
WIRED_PROC segment and use its block (`../mac/README.md`).

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| WIRED_PROC | MAC_OS, 0x11E0 bytes | mac_os_$check_range_overlap, mac_os_$find_packet_type, mac_os_$nop, MAC_OS_$OPEN, MAC_OS_$CLOSE, mac_os_$copy_buffer_data (nested), MAC_OS_$SEND, MAC_OS_$DEMUX, MAC_$OPEN, MAC_$CLOSE, MAC_$SEND, MAC_$DEMUX, mac_$copy_to_buffers (nested), MAC_$RECEIVE, MAC_OS_$PROC2_CLEANUP, MAC_OS_$ARP, MAC_OS_$PUT_INFO, MAC_$NET_TO_PORT_NUM | none (the heading's) |
| OS_INIT_PROC | MAC_OS, 0x134 bytes | MAC_OS_$INIT | `[section(os_init_proc, os_init_data)]` |

Data: the map's MAC_OS data segment in WIRED_DATA, 0x8EC bytes, through
A5 in the WIRED_PROC routines, by its address in MAC_OS_$INIT; zero but
the broadcast record:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `mac_os_$port_pkt_tables` | array[0..7] of mac_os_$port_pkt_table_t (0xF4 each) |
| +0x7A0 | `mac_os_$channel_table` | array[0..9] of mac_os_$channel_t (0x14 each) |
| +0x868 | `mac_os_$exclusion` | ml_$exclusion_t (0x12) |
| +0x87A | 2 bytes: the next object's alignment | |
| +0x87C | MAC_OS_$PORTP_TABLE (`define`d, map symbol) | array[0..7] of mac_os_$port_info_ptr_t |
| +0x89C | MAC_OS_$PORT_TABLE (`define`d, map symbol) | array[0..7] of mac_os_$port_info_t (8 each) |
| +0x8DC | `unused_8dc`, a stand-in for 4 bytes nothing addresses | integer32 |
| +0x8E0 | `mac_os_$broadcast_nexthop` | rip_$nexthop_t, network 0, host all ones |
| +0x8EA | 2 bytes: the block's rounding to 4 | |

The names are the map's where it has them.

Routines: eight MAC_OS_ globals (every MAC_OS_ map symbol) and the six
MAC_ globals; three module-local (`internal`, no map symbol) at the
segment's start, mac_os_$check_range_overlap, mac_os_$find_packet_type
and mac_os_$nop; one nested in MAC_OS_$SEND, mac_os_$copy_buffer_data
(and MAC_$RECEIVE's mac_$copy_to_buffers).  None is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| mac_os_$check_range_overlap | `check_range_overlap.pas` |
| mac_os_$find_packet_type | `find_packet_type.pas` |
| mac_os_$nop | `nop.pas` (empty procedure) |
| MAC_OS_$OPEN | `open.pas` |
| MAC_OS_$CLOSE | `close.pas` |
| mac_os_$copy_buffer_data | `send.pas` (nested in MAC_OS_$SEND, before it in the image) |
| MAC_OS_$SEND | `send.pas` |
| MAC_OS_$DEMUX | `demux.pas` |
| (MAC_$OPEN .. MAC_$RECEIVE) | `../mac/*.pas` (`../mac/README.md`) |
| MAC_OS_$PROC2_CLEANUP | `proc2_cleanup.pas` |
| MAC_OS_$ARP | `arp.pas` |
| MAC_OS_$PUT_INFO | `put_info.pas` (the address compare is inline) |
| (MAC_$NET_TO_PORT_NUM) | `../mac/net_to_port_num.pas` |
| MAC_OS_$INIT | `init.pas` |
| (data) | the block in `mac_os.pas` |

Headings (`mac_os.ins.pas`): MAC_OS_$OPEN, _$CLOSE, _$SEND, _$DEMUX and
_$PUT_INFO the default convention (every argument by address);
_$PROC2_CLEANUP and _$ARP `val_param` (a word by value); _$INIT none.
No caller copies an A0 result to D0 (no routine here returns a pointer).

## Insert files

- `mac_os.ins.pas` (reviewed in C2): mac_os_$link_addr_t is
  route/route.ins.pas's route_$link_addr_t, the same record (the port's
  field has that type), so the insert needs `route/route.ins.pas`
  first.  It has seven statuses, the bounds and sizes, the network
  types, the packet-type entry, its array and the port's table, the
  port record and its pointer, the driver's three entry types,
  MAC_OS_$PORTP_TABLE and MAC_OS_$PORT_TABLE, and the headings.
- `route/route.ins.pas`: the port record's bytes 0x04..0x2B are
  n_link_addrs, n_net_addrs, link_addr (route_$link_addr_t) and
  xns_addr (an array from 0 of route_$xns_addr_t, the host as three
  words); the layout is unchanged.  Its users (`app/app.pas`,
  `hint/hint.pas`, `net/net.pas`, `net_io/net_io.pas`,
  `net_io/net_io_unwired.pas`) still check.
- `rip/rip.ins.pas`: rip_$nexthop_t's host is also three words, a
  variant beside host_hi and host_lo (MAC_OS_$ARP reads the words); the
  layout is unchanged.  Its users are mac_os.ins.pas and `mac/send.pas`
  (by the whole record).
- Used as they are: `net_io/net_io.ins.pas` (the driver record, its
  open_os, close_os, send_os univ_ptr converted at each call),
  `node/node.ins.pas`, `ml`, `time`, `fim`, `os`, `netbuf`, `sock`,
  `proc1`, `proc2`, `pkt`, `misc/crash_system`, `mac/mac.ins.pas`.

## Open items

Form and names:
- MAC_OS_$ARP is 0x15A bytes, the jump tables' arms included.
- mac_os_$check_range_overlap's result is a boolean byte.
- The three module-local routines and the nested
  mac_os_$copy_buffer_data have no map symbols.
- mac_os_$copy_buffer_data reaches its parent's two variables through
  the static link.
- The routing port's XNS host is three words, which MAC_OS_$INIT
  stores and MAC_OS_$PUT_INFO compares (route/route.ins.pas).
- MAC_OS_$INIT keeps the node's high part as a common subexpression in
  a register (its frame has no room for a local) and stores the XNS
  host's third word from the link address it has just written.
- MAC_OS_$DEMUX's third argument is the flag the callback type takes.

### TODO(pascal)

- `check_range_overlap.pas` (and `find_packet_type.pas`): two frame
  bytes, the same in both (a `for` loop's cost?).
- `open.pas`: six frame bytes; and the owner field's merge of
  PROC1_$AS_ID is unmasked, the form of an unsigned value, against
  proc1.ins.pas's `integer`.
- `send.pas`: four frame bytes.
- `demux.pas`: 0x46 frame bytes above the clock and 4 below.
- `proc2_cleanup.pas`: four frame bytes.
- `put_info.pas`: twelve frame bytes.

Each counts the `with` temporaries' slots (a lead); MAC_OS_$CLOSE's and
MAC_OS_$INIT's frames are explained by them exactly, MAC_OS_$ARP's by its
locals.
