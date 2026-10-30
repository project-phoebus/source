# The MAC subsystem in Domain Pascal

The MAC layer's user interface (open, close, send, receive a channel;
the receive callback; the port of a network).

## Layout

No module of its own.  The map has no MAC_ segment: the six MAC_
routines lie inside the map's MAC_OS code segment (WIRED_PROC, 0x11E0
bytes), between MAC_OS_$DEMUX and MAC_OS_$PROC2_CLEANUP, and reach
MAC_OS's data block (WIRED_DATA, 0x8EC bytes) through A5 (the channel
table at +0x7A0, the exclusion lock at +0x868, the broadcast next hop
at +0x8E0).  So they are fragments of the MAC_OS module, whose module
file is `mac_os/mac_os.pas` (`module mac_os, wired_proc, wired_data;`,
the map segments' name, with MAC_OS_$INIT in OS_INIT_PROC); it
includes them in image order among MAC_OS's own fragments:

| section | routines (image order) | attribute |
|---------|------------------------|-----------|
| WIRED_PROC (of MAC_OS's segment) | MAC_$OPEN, MAC_$CLOSE, MAC_$SEND, MAC_$DEMUX, mac_$copy_to_buffers (nested), MAC_$RECEIVE; MAC_$NET_TO_PORT_NUM after MAC_OS_$PUT_INFO | none (the heading's) |

`mac_os/mac_os.pas` declares MAC_OS's block, the objects the fragments
reach among them: the channel table `mac_os_$channel_table:
array[0..9] of mac_os_$channel_t` (+0x7A0), the lock
`mac_os_$exclusion` (+0x868) and the broadcast next hop
`mac_os_$broadcast_nexthop` (+0x8E0, `00 00 00 00 ff ff ff ff ff ff`;
the map names none of the three);
`../mac_os/README.md` has the whole block.
`tools/pascal_check.sh` checks the fragments with `mac_os/mac_os.pas`.

All six are global (map symbols), the default convention (every
argument by address: the system-call table's callers; MAC_$DEMUX
through MAC_OS_$DEMUX's call with four addresses).  One nested routine,
mac_$copy_to_buffers, inside MAC_$RECEIVE.  None is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MAC_$OPEN | `open.pas` |
| MAC_$CLOSE | `close.pas` |
| MAC_$SEND | `send.pas` |
| MAC_$DEMUX | `demux.pas` |
| MAC_$RECEIVE | `receive.pas` (with the nested mac_$copy_to_buffers, before it in the image) |
| MAC_$NET_TO_PORT_NUM | `net_to_port_num.pas` |

## Insert files

- `mac.ins.pas`: MAC's status codes and bounds, the caller's records
  (`mac_$open_params_t`, a variant record whose results overlay the
  ranges; `mac_$send_pkt_t` = MAC_OS's; `mac_$recv_pkt_t`), the six
  headings.
- `mac_os/mac_os.ins.pas`: the records MAC_ and MAC_OS_ share (the link
  address, buffer descriptors and chain entries, packet-type ranges, the
  receive and send records, the channel with its flag word read both as
  a set and as packed fields, MAC_OS_$OPEN's record), the callback type,
  two MAC_OS status codes, the headings of MAC_OS_$OPEN, _CLOSE, _SEND
  and _ARP.  The link address is route/route.ins.pas's
  route_$link_addr_t; the rest is `../mac_os/README.md`'s.
- `rip/rip.ins.pas`: `rip_$nexthop_t` (its host also as three words, a
  variant; the layout unchanged).
- `route/route.ins.pas`: `route_$port_t` 0x5C bytes with active,
  port_type and socket; `route_$port` (ROUTE_$PORT);
  status_$internet_network_port_not_open.
- `sock/sock.ins.pas`: the descriptor's flag word as the packed record
  `sock_$flags_t`; `sock_$pkt_info_t`'s hops from 0 and data_len/hdr_len
  pinteger; SOCK_$ALLOCATE_USER, SOCK_$CLOSE.  APP's fragments use none
  of the changed fields but by word copies and a word pushed by value
  (same code); `app/app.pas` still checks.
- `ec/ec.ins.pas`: Apollo's `ec2_$eventcount_t`, `ec2_$ptr_t`;
  EC2_$REGISTER_EC1.
- `fim/fim.ins.pas`: Apollo's `fault_$cleanup_set`, the cleanup record
  `fim_$cleanup_rec_t` (0x18 bytes), FIM_$CLEANUP (`options(abnormal,
  extern)`, as Apollo's pfm_$cleanup) and FIM_$RLS_CLEANUP.
- `netbuf/netbuf.ins.pas`: NETBUF_$RTN_PKT (it needs `pkt/pkt.ins.pas`
  first; both its users include it).

## Open items

### Form

- Three failure blocks per routine (bound, in use, owner) are one block
  in the image, reached by branches (mac/close.pas).
- MAC_$OPEN widens the channel number with zeros to index the table;
  the other routines scale their channel in word arithmetic.
- MAC_$DEMUX and MAC_$RECEIVE bound their word copies by the word just
  stored.
- MAC_$SEND reads the channel's port at the ARP call.
- MAC_$NET_TO_PORT_NUM reads the network through its slot in each pass.
- The open record's byte at 0x54 is a boolean, the promiscuous flag
  (MAC_$OPEN reads its top bit).
- SOCK_$ALLOCATE_USER takes four words, which SOCK_$OPEN's body stores
  into four descriptor fields (sock/sock.ins.pas).

### TODO(pascal)

- `send.pas`: 8 frame bytes (stand-ins `unused_6c`, `unused_7c`).
- `receive.pas`: 4 frame bytes (stand-in `unused_78`).
- `demux.pas`: the word copies' guard, a branch on the bound's
  subtraction with no test, for a loop from 0 (also MAC_$RECEIVE's and
  MAC_$OPEN's loops).
