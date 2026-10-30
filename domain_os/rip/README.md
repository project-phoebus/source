# The RIP subsystem in Domain Pascal

The routing information protocol (the routing table, its lookups, aging
and updates, the next hop of a destination, the routes of a closing
port, the standard IDP channel's demux and open, RIP's initialization;
its server, the table's read and write calls, the route updates by port
and the name server announcement; its sending, the table's broadcast and
the router's halt).

## Layout

The map has no module named RIP, so there is no `rip/rip.pas`.  Three
map modules, one module file each, which `tools/pascal_check.sh` finds
by their headings:

| file | heading | code | data |
|------|---------|------|------|
| `rip_wired.pas` | `module rip_wired, wired_proc, wired_data;` | RIP_WIRED, WIRED_PROC (0x654 bytes): rip_$lock .. RIP_$STD_OPEN; RIP_WIRED, OS_INIT_PROC (0x220 bytes): RIP_$INIT (`[section(os_init_proc, os_init_data)]`) | RIP_WIRED, WIRED_DATA (0xC8C bytes), through A5; RIP_WIRED, OS_INIT_DATA (4 bytes), RIP_$INIT's static |
| `rip_unwired.pas` | `module rip_unwired;` | RIP_UNWIRED, .TEXT (0x958 bytes): rip_$packet_length .. RIP_$ANNOUNCE_NS | none (RIP's symbols at their addresses) |
| `rip_rtwired.pas` | `module rip_rtwired, rtwired_code, rtwired_data;` | RIP_RTWIRED, RTWIRED_CODE (0x3EC bytes): RIP_$SEND's family .. RIP_$HALT_ROUTER | RIP_RTWIRED, RTWIRED_DATA (0x18 bytes), through A5 |

The RIP_WIRED block, its map symbols `define`d in `rip_wired.pas`, its
other objects module variables:

| offset | variable | type |
|--------|----------|------|
| +0x000 | rip_$route_port | rip_$nexthop_t (RIP_$INIT's source) |
| +0x00A | unused_0a | a stand-in (6 bytes, the TODO) |
| +0x010 | XNS_ERROR_$CLIENT_MUTEX | ml_$exclusion_t |
| +0x022 | unused_22 | a stand-in |
| +0x028 | ROUTE_$SERVICE_MUTEX | ml_$exclusion_t |
| +0x03A | unused_3a | a stand-in |
| +0x040 | rip_$exclusion | ml_$exclusion_t (the RIP lock) |
| +0x052 | unused_52 | a stand-in (2 bytes) |
| +0x054 | RIP_$STATS | rip_$stats_t := [unused_00 := 1] |
| +0x164 | RIP_$INFO | array[0..63] of rip_$entry_t |
| +0xC64 | RIP_$STD_IDP_CHANNEL | pinteger := 16#FFFF |
| +0xC66 | RIP_$NS_ANNOUNCEMENT | integer := 3 |
| +0xC68 | RIP_$BCAST_CONTROL | rip_$template_t := [flags := [4, 7], 2, 1, 1, .., field_0c := 16#FFFF] |
| +0xC86 | RIP_$STD_RECENT_CHANGES | boolean |
| +0xC88 | RIP_$RECENT_CHANGES | boolean |

The RIP_RTWIRED block: rip_$dest_addr (route_$xns_addr_t, the broadcast
destination), rip_$send_flags (integer), the stand-in unused_0e,
rip_$halt_data (8 bytes: a response, network -1 at 16 hops).  The
OS_INIT_DATA block is RIP_$INIT's static request (a word 0, its
packet's template).

Routines (26 compiled): 18 globals, every map symbol of the four code
segments; three module-local (`internal`, no map symbol): rip_$lock,
rip_$unlock (RIP_WIRED) and rip_$packet_length (RIP_UNWIRED); five
nested: rip_$compare_source and rip_$apply_update in RIP_$UPDATE_INT
(the second reads its link; the first, linkless, heads the family and
is called by the parent alone), rip_$process_request in RIP_$SERVER,
rip_$send_to_port_internet and rip_$send_to_port in RIP_$SEND.  The
first of the last two lies at RTWIRED_PROC_START, the wired routing
area's marker.  No hand assembly (there is no rip/sau2/).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| rip_$lock | `lock.pas` |
| rip_$unlock | `unlock.pas` |
| RIP_$NET_LOOKUP | `net_lookup.pas` |
| RIP_$AGE | `age.pas` |
| RIP_$FIND_NEXTHOP | `find_nexthop.pas` |
| RIP_$PORT_CLOSE | `port_close.pas` |
| RIP_$UPDATE_INT (with rip_$compare_source, rip_$apply_update nested) | `update_int.pas` |
| RIP_$STD_DEMUX | `std_demux.pas` |
| RIP_$STD_OPEN | `std_open.pas` |
| RIP_$INIT | `init.pas` |
| rip_$packet_length | `packet_length.pas` |
| RIP_$SEND_UPDATES | `send_updates.pas` |
| RIP_$SERVER (with rip_$process_request nested) | `server.pas` |
| RIP_$TABLE_D | `table_d.pas` |
| RIP_$TABLE | `table.pas` |
| RIP_$UPDATE_D | `update_d.pas` |
| RIP_$UPDATE | `update.pas` |
| RIP_$ANNOUNCE_NS | `announce_ns.pas` |
| RIP_$SEND (with rip_$send_to_port_internet, rip_$send_to_port nested) | `send.pas` |
| RIP_$BROADCAST | `broadcast.pas` |
| RIP_$HALT_ROUTER | `halt_router.pas` |
| (data) | the variables of the module files, RIP_$INIT's static |

The port routines are not adjacent in the image (port_close.pas, then
RIP_$UPDATE_INT's family, then std_demux.pas and std_open.pas), nor
are RIP_$ANNOUNCE_NS (RIP_UNWIRED) and RIP_$HALT_ROUTER (RIP_RTWIRED).

Headings (`rip.ins.pas`, map order): the default convention for the
system-call and dispatch entries, every argument by address
(RIP_$TABLE_D, _$TABLE, _$UPDATE_D, _$UPDATE, RIP_$STD_DEMUX, the
demux routine's type's modes) and for the routines without parameters
(RIP_$AGE, _$STD_OPEN, _$INIT, _$SERVER, _$ANNOUNCE_NS); `val_param`
for the kernel-internal ones, their words, bytes and longwords read
from the slots (RIP_$NET_LOOKUP, _$FIND_NEXTHOP, _$PORT_CLOSE,
_$UPDATE_INT, _$SEND_UPDATES, _$SEND, _$BROADCAST, _$HALT_ROUTER).
Functions: RIP_$NET_LOOKUP (an integer32 in A0, `a0_return`: one caller
parks it in D0, two do not) and RIP_$FIND_NEXTHOP (integer).  The
module-local and nested routines take words, bytes and longwords by
value.

Constant cells: RIP_$INIT's (the OS_INIT_PROC segment's end),
RIP_$SERVER's two and RIP_$TABLE's, rip_$send_to_port_internet's (the
module files list them).

## Insert files

- `rip.ins.pas` (users: mac_os, pkt, route, xns and RIP's three
  modules): RIP's constants and status; the byte type, the host's packed
  view, the route's flags, the route, the entry, the counters, the two
  table records, the packet and its entry, their pointers; the map
  symbols of the wired block; the headings of the globals (RIP_$STD_DEMUX's
  in rip_xns.ins.pas).  rip_$nexthop_t has a third variant arm,
  host_bits (rip_$host_bits_t, the host's 20-bit node as a packed
  field), for RIP_$TABLE's in-place merge into it.
- `rip_xns.ins.pas`: RIP_$STD_DEMUX's heading, which needs
  xns/xns.ins.pas; most includers of rip.ins.pas include that after it,
  so the heading is apart, included by rip_wired.pas alone.
- `../network/network.ins.pas`:
  status_$network_too_many_networks_in_internet.
- `../pkt/pkt.ins.pas`, with `../pkt/bld_internet_hdr.pas` and
  `../pkt/brk_internet_hdr.pas` repeating the headings:
  PKT_$BLD_INTERNET_HDR's pkt_info `univ`, as PKT_$SEND_INTERNET's:
  rip_$send_to_port_internet passes RIP_$BCAST_CONTROL, the 30-byte
  template; PKT_$BRK_INTERNET_HDR's src_node linteger, as BLD's: its one
  caller, RIP_$SERVER, merges the value into a 20-bit field unmasked.
- Used as they are: base, ec, ml, time, misc/crash_system, os, node,
  proc1, netbuf, route, sock, net, xns, xns_idp, app, net_io, mac_os,
  uid, hint, rem_name.  TIME_$CLOCKH_EC is read as
  `ec_$eventcount_ptr_t(addr(time_$clockh))`, flp/excs.pas's form.

## Open items

Form and names:
- A table entry's routes[1] is the standard (XNS) routing's: the
  routines' std flag picks it and sets RIP_$STD_RECENT_CHANGES.
- The per-entry counters are RIP_$STATS's packet counters, which
  RIP_$FIND_NEXTHOP counts through RIP_$NET_LOOKUP.
- RIP_$STD_DEMUX's descriptor fields are xns/xns.ins.pas's (the MAC
  source, the header, the data length, the port's word); its port words
  are the port's type and socket.  XNS_IDP_$OS_OPEN reads RIP_$STD_OPEN's
  record's addresses only when the flag word's bit 2 is set, and RIP's
  flags are 2, bit 1.
- A port summary's or table record's word at +6 / +0x12 is the port's
  type.
- The nested rip_$apply_update reads the source, hop count, port and
  flag from the parent's frame.
- The pads before calls are those of argument lists of 2 mod 4 bytes.

### TODO(pascal)

- `rip_wired.pas`: 20 bytes of the RIP_WIRED block (+0x0A, +0x22,
  +0x3A, +0x52).
- `rip_rtwired.pas`: 2 bytes of the RIP_RTWIRED block (+0x0E).
- `net_lookup.pas`: 8 frame bytes of RIP_$NET_LOOKUP.
- `age.pas`: 8 frame bytes of RIP_$AGE.
- `find_nexthop.pas`: 8 frame bytes of RIP_$FIND_NEXTHOP.
- `port_close.pas`: 4 frame bytes of RIP_$PORT_CLOSE.
- `update_int.pas`: 6 frame bytes of RIP_$UPDATE_INT.
- `init.pas`: 32 frame bytes of RIP_$INIT.
- `server.pas`: 12 frame bytes of rip_$process_request; 20 of
  RIP_$SERVER.
- `send.pas`: 6 frame bytes of RIP_$SEND and 4 of rip_$send_to_port.
- `broadcast.pas`: RIP_$BROADCAST's 0x18 bytes and three temporaries.
- `halt_router.pas`: 4 frame bytes of RIP_$HALT_ROUTER.

Frames explained exactly by the locals (register-held locals keeping
their slots; the 8-alignment of blocks): rip_$lock, rip_$unlock,
rip_$compare_source, rip_$apply_update, RIP_$STD_DEMUX, RIP_$STD_OPEN,
rip_$packet_length, RIP_$SEND_UPDATES, RIP_$TABLE_D, RIP_$TABLE,
RIP_$UPDATE_D, RIP_$UPDATE, RIP_$ANNOUNCE_NS,
rip_$send_to_port_internet.

## Named dispatch codes

RIP's port-type tests use ROUTE's named constants route_$port_type_local
and _routing (route/README.md).  RIP_$BCAST_CONTROL's
initializer (rip_wired.pas) uses pkt/pkt.ins.pas's `pkt_$routing_inet`
and `pkt_$addr_short`.
