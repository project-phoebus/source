# The XNS subsystem in Domain Pascal

The XNS internet datagram protocol (IDP: the channel table and the
routing ports' MAC channels, the OS calls that open, close and send on a
channel and demultiplex received packets, the user calls on top of them,
the checksum) and the XNS error protocol (an error packet sent back for
an undeliverable one).

## Layout

The map has no module named XNS, so there is no `xns/xns.pas`.  The
compiled routines are two map modules, one module file each, which
`tools/pascal_check.sh` finds by their headings; the checksum engine is
hand assembly:

| file | heading | code | data |
|------|---------|------|------|
| `xns_error.pas` | `module xns_error, wired_proc, wired_data;` | XNS_ERROR, 0x3A8 bytes, WIRED_PROC: xns_$is_local_addr .. XNS_ERROR_$SEND | XNS_ERROR, 0x78 bytes, WIRED_DATA, through A5 |
| `xns_idp.pas` | `module xns_idp, wired_proc, wired_data;` | XNS_IDP, 0x14C4 bytes, WIRED_PROC: xns_$add_port .. XNS_IDP_$REGISTER_ADDR; 0xD8 bytes, OS_INIT_PROC: XNS_IDP_$INIT (`[section(os_init_proc, os_init_data)]`) | XNS_IDP, 0x53C bytes, WIRED_DATA, through A5 (absolutely from XNS_IDP_$INIT) |
| none | (hand assembly) | XNS_IDP_ASM, 0x4C bytes, code in a data segment: XNS_IDP_$CHECKSUM, XNS_IDP_$HOP_AND_SUM (`m68k/idp_checksum.s`) | |

XNS_ERROR's lock, XNS_ERROR_$CLIENT_MUTEX, is in RIP's block
(RIP_WIRED; `../rip/rip.ins.pas`).

XNS_ERROR's block (zero but the two RELOC cells and the channel):

| offset | variable | type |
|--------|----------|------|
| +0x00 | `xns_error_$send_rec` | xns_$os_send_rec_t (0x48 bytes) |
| +0x48 | `unused_48` (stand-in, nothing addresses it) | 0x24 bytes |
| +0x6C | `xns_error_$buf_va_high` | univ_ptr := addr(netpool_end) (a RELOC cell) |
| +0x70 | `xns_error_$buf_va_low` | univ_ptr := addr(network_$bufpool) (a RELOC cell) |
| +0x74 | CLIENT_REF_COUNT (`define`d, map symbol without `$`) | integer |
| +0x76 | XNS_ERROR_$STD_IDP_CHANNEL (`define`d) | pinteger := 16#FFFF |

XNS_IDP's block (all zero; XNS_IDP_$INIT fills it): the three
counters, `unused_0c`, the registered addresses' ports (+0x10) and
hosts (+0x20) with the stand-ins `unused_18` and `unused_38` between (a
TODO in `xns_idp.pas`), XNS_IDP_$PORT_TABLE (+0x40, `define`d;
ROUTE_$PROCESS reaches it), the 16 channels (+0xA0), the lock (+0x520),
`unused_532`, the open count, the next socket and the registered count
(+0x534..+0x539).  `xns_idp.pas` has the table.

Routines (28 compiled): every map symbol of the two code segments' 17
globals plus MAYBE_OPEN_ERROR_SOCKET and MAYBE_CLOSE_ERROR_SOCKET (map
symbols without `$`, globals); seven module-local
(`internal`, no map symbol): xns_$is_local_addr,
xns_$pkt_bufs_in_netbuf_pool (XNS_ERROR's), xns_$add_port,
xns_$delete_port, xns_$find_socket, xns_$get_checksum,
xns_$is_broadcast_addr (XNS_IDP's); two nested: xns_$setup_error_header
in XNS_ERROR_$SEND and xns_$copy_packet_data in XNS_IDP_$RECEIVE (each
reads its static link and lies right before its parent).  Hand
assembly: XNS_IDP_$CHECKSUM and XNS_IDP_$HOP_AND_SUM.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| xns_$is_local_addr | `is_local_addr.pas` (XNS_ERROR's) |
| xns_$pkt_bufs_in_netbuf_pool | `pkt_bufs_in_netbuf_pool.pas` |
| MAYBE_OPEN_ERROR_SOCKET | `maybe_open_error_socket.pas` |
| MAYBE_CLOSE_ERROR_SOCKET | `maybe_close_error_socket.pas` |
| XNS_ERROR_$SEND (with the nested xns_$setup_error_header) | `error_send.pas` |
| xns_$add_port | `add_port.pas` |
| xns_$delete_port | `delete_port.pas` |
| xns_$find_socket | `find_socket.pas` |
| xns_$get_checksum | `get_checksum.pas` |
| xns_$is_broadcast_addr | `is_broadcast_addr.pas` |
| XNS_IDP_$OS_OPEN | `idp_os_open.pas` |
| XNS_IDP_$OS_CLOSE | `idp_os_close.pas` |
| XNS_IDP_$OS_SEND | `idp_os_send.pas` (apart from XNS_IDP_$SEND in the image) |
| XNS_IDP_$OS_DEMUX | `idp_os_demux.pas` |
| XNS_IDP_$OS_ADD_PORT | `idp_os_add_port.pas` |
| XNS_IDP_$OS_DELETE_PORT | `idp_os_delete_port.pas` |
| XNS_IDP_$OPEN | `idp_open.pas` |
| XNS_IDP_$CLOSE | `idp_close.pas` |
| XNS_IDP_$SEND | `idp_send.pas` |
| XNS_IDP_$DEMUX | `idp_demux.pas` |
| XNS_IDP_$RECEIVE (with the nested xns_$copy_packet_data) | `idp_receive.pas` |
| XNS_IDP_$PROC2_CLEANUP | `idp_proc2_cleanup.pas` |
| XNS_IDP_$GET_PORT_INFO | `idp_get_port_info.pas` |
| XNS_IDP_$GET_STATS | `idp_get_stats.pas` |
| XNS_IDP_$REGISTER_ADDR | `idp_register_addr.pas` |
| XNS_IDP_$INIT | `idp_init.pas` |
| XNS_IDP_$CHECKSUM, XNS_IDP_$HOP_AND_SUM | none: hand assembly (XNS_IDP_ASM, `sau2/`) |
| (data) | the variables of `xns_error.pas`, `xns_idp.pas` |

Headings (`xns.ins.pas`, `xns_idp.ins.pas`): every global the default
convention, every argument by address (the user calls are SVC entries,
their addresses in .DATA cells; the OS calls' compiled callers push
addresses), but XNS_IDP_$PROC2_CLEANUP (`val_param`, its address
space's word by value); XNS_IDP_$OS_DEMUX and XNS_IDP_$DEMUX have the
modes of the routine pointer types whose fields hold their addresses
(MAC_OS's callback, `xns_$demux_proc_t`).  The module-local helpers take
words by value (`internal`), records by address; the nested routines
the internal convention (xns_$copy_packet_data's length by value, its
source cell `var`).  No routine's caller parks an A0 result in D0;
XNS_IDP_$DEMUX keeps the header's address in D0 and converts it at each
dereference.

## Insert files

- `xns.ins.pas` (users: `../app/app.pas`, `../pkt/pkt.pas`, the two XNS
  module files): the statuses, the bounds and constants, the open flag
  members, xns_$byte_t, the address types (xns_$addr_t is
  `../route/route.ins.pas`'s route_$xns_addr_t; xns_$addr_bytes_t),
  XNS's buffer descriptor and data part, the open flag set, the
  descriptor's pointer type.  Changed, every user re-checked:
  - **xns_$idp_header_t**: the 24 bytes from 6 a variant part (arm 1
    the existing fields, arm 2 dest/src, arm 3 the bytes); **length
    integer** and **transport_ctl and packet_type xns_$byte_t**: the
    image widens them (the type's comment); APP reads none of the three;
  - **xns_$pkt_desc_t**: the fields from 0x18 a variant part (arm 1 the
    existing fields, its inner variant given a third arm `data`; arm 2
    `head`); **pkt_len pinteger** (widened with zeros); APP's fields
    unchanged;
  - **xns_$os_open_opt_t**: the fields from 0x02 a variant part (arm 1
    the existing fields with an inner variant for src/dest and the
    bytes; arm 2 the flag set); APP's fields unchanged.
  The file needs `../route/route.ins.pas` before it (APP and PKT include
  it first already).
- `xns_idp.ins.pas` (users: the two XNS module files): the channel flag
  and state members, the host words, XNS's view of MAC's packet record,
  the port state, the channel's flag word and state, the channel, the
  request records of XNS_IDP_$OS_SEND, _$SEND, _$RECEIVE and _$OPEN, the
  counters' record, the error packet, XNS_IDP_$PORT_TABLE,
  CLIENT_REF_COUNT, XNS_ERROR_$STD_IDP_CHANNEL, NETPOOL_END (`{
  TODO(merge) move to network/network.ins.pas }`), and the headings of
  every XNS global but XNS_IDP_$OS_OPEN, the two hand assembly routines'
  included.  Kept apart from `xns.ins.pas` because it needs the mac_os,
  rip, ml and ec inserts, which APP's and PKT's module files do not
  include.
- `../rip/rip.ins.pas`: XNS_ERROR_$CLIENT_MUTEX (the file needs
  `../ml/ml.ins.pas` before it; MAC_OS's and PKT's module files include
  it first already); **RIP_$FIND_NEXTHOP's first formal `in addr_info:
  univ rip_$dest_addr_t`** (XNS passes its xns_$addr_t records; a 12-byte
  record goes by address with or without `univ` under `val_param`, so
  PKT's two calls compile as before).
- `../route/route.ins.pas`: ROUTE_$STD_N_ROUTING_PORTS,
  ROUTE_$STD_TOO_FAR and ROUTE_$STD_MISROUTE; nothing changed.
- `../mac_os/mac_os.ins.pas`: mac_os_$data_desc_t; **mac_os_$send_pkt_t's
  last two fields (data_length, data_pages) wrapped in a variant part**
  whose second arm is `data: mac_os_$data_desc_t` (XNS_IDP_$OS_SEND
  copies the 20 bytes as one record); the field names and offsets are
  unchanged, and the users (`../mac/send.pas`, `../mac_os/send.pas`,
  `../mac/mac.ins.pas`'s alias) check as before.
- Used as they are: base, ec, ml, time, pkt, proc1, proc2, fim,
  crash_system, os, node, netbuf, network, sock, net_io, mac.

## Open items

### Types and names

- The map names MAYBE_OPEN_ERROR_SOCKET and MAYBE_CLOSE_ERROR_SOCKET
  (globals); the Pascal has the map's names.
- xns_$is_local_addr tests for the broadcast host, and its code is
  XNS_ERROR's, not IDP's.
- The open flag member 15 that XNS_IDP_$RECEIVE tests is not
  xns_open_flag_no_alloc (member 14, mask 0x4000).
- The open flag no_alloc is what the statuses call "send only"
  (16#3B0018, 16#3B0019).
- The image copies each of the channel's addresses as a 12-byte record
  and the two as 24 bytes (the Pascal's views).  XNS_IDP_$OS_DEMUX's
  parameter is the MAC record seen as XNS's own type
  (`xns_idp.ins.pas` xns_$mac_pkt_t).
- XNS_ERROR's two bounds are the addresses of NETPOOL_END and
  NETWORK_$BUFPOOL (RELOC cells).

### TODO(pascal)

- `is_local_addr.pas`: 4 frame bytes of xns_$is_local_addr (and of
  xns_$pkt_bufs_in_netbuf_pool) no object explains.
- `find_socket.pas`, `is_broadcast_addr.pas`, `get_checksum.pas`: 4
  frame bytes in each of three XNS_IDP helper functions.
- `error_send.pas`: 4 frame bytes of XNS_ERROR_$SEND.
- `idp_os_open.pas`: 14 frame bytes of XNS_IDP_$OS_OPEN.
- `idp_os_close.pas`: 4 frame bytes of XNS_IDP_$OS_CLOSE.
- `idp_os_send.pas`: 12 frame bytes of XNS_IDP_$OS_SEND.
- `idp_os_demux.pas`: 14 frame bytes of XNS_IDP_$OS_DEMUX.
- `idp_send.pas`: 4 frame bytes of XNS_IDP_$SEND.
- `idp_demux.pas`: 4 frame bytes of XNS_IDP_$DEMUX.
- `idp_receive.pas`: 14 frame bytes of XNS_IDP_$RECEIVE.
- `idp_proc2_cleanup.pas`: 8 frame bytes of XNS_IDP_$PROC2_CLEANUP.
- `idp_register_addr.pas`: 4 frame bytes of XNS_IDP_$REGISTER_ADDR.
- `idp_init.pas`: 16 frame bytes of XNS_IDP_$INIT.
- `xns_idp.pas`: 20 bytes of the XNS_IDP block.

Frames explained exactly (with the `with` temporaries and 8-aligned
blocks):
MAYBE_OPEN_ERROR_SOCKET, MAYBE_CLOSE_ERROR_SOCKET,
xns_$setup_error_header, xns_$add_port, xns_$delete_port,
xns_$get_checksum, XNS_IDP_$OPEN, XNS_IDP_$CLOSE, xns_$copy_packet_data,
and the frameless OS_ADD_PORT, OS_DELETE_PORT, GET_PORT_INFO,
GET_STATS.
