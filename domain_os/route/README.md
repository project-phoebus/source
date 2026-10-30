# The ROUTE subsystem in Domain Pascal

The network routing (the routing ports' lookups and summary, the routing
service that opens, changes and closes ports and starts the routing
process, the eventcounts and statistics of the user ports, the shutdown
of every port, the routing process that forwards packets, and the user
ports' calls and driver entry).

## Layout

The map has no module named ROUTE, so there is no `route/route.pas`.
Three map modules, one module file each, which `tools/pascal_check.sh`
finds by their headings:

| file | heading | code | data |
|------|---------|------|------|
| `route_wired.pas` | `module route_wired, wired_proc, wired_data;` | ROUTE_WIRED, 0x98 bytes, WIRED_PROC: ROUTE_$FIND_PORT, ROUTE_$FIND_PORTP | ROUTE_WIRED, 0x3C bytes, WIRED_DATA, through A5; and ROUTE_$PORT, the overlay section NET_PORT_TABLE |
| `route_unwired.pas` | `module route_unwired;` | ROUTE_UNWIRED, 0xB88 bytes, .TEXT: route_$cleanup_wired .. ROUTE_$READ_USER_STATS | ROUTE_UNWIRED, 8 bytes, .DATA, through A5 in ROUTE_$SERVICE's family |
| `route_rtwired.pas` | `module route_rtwired, rtwired_code, rtwired_data;` | ROUTE_RTWIRED, 0x97C bytes, RTWIRED_CODE: ROUTE_$PROCESS .. ROUTE_$SEND_USER_PORT | ROUTE_RTWIRED, 0x4A8 bytes, RTWIRED_DATA, through A5 |
| none | (ASKNODE's) | route_$validate_port, a module-local routine of the ASKNODE code segment (.TEXT) | |

route_$validate_port's code lies inside the ASKNODE module (between
ASKNODE_$READ_FAILURE_REC and ASKNODE_$SERVER; callers ASKNODE_$SERVER
and ASKNODE_$WHO_REMOTE).  `validate_port.pas` is a fragment for that
module: asknode/asknode.pas includes it in image order.

ROUTE_$SERVICE_MUTEX, RIP_$STD_IDP_CHANNEL and RIP_$BCAST_CONTROL are in
RIP's block (RIP_WIRED; `../rip/rip.ins.pas`).  ROUTE_$PORT, the eight
port records, is the overlay section NET_PORT_TABLE, which
`route_wired.pas` defines with the image's initial values (dpc).

The ROUTE_WIRED block, every object a map symbol `define`d in
`route_wired.pas`:

| offset | variable | type |
|--------|----------|------|
| +0x00 | ROUTE_$SOCK_ECVAL | integer32 |
| +0x04 | ROUTE_$PORTP | array[0..7] of route_$port_ptr_t := addr(route_$port[i]) |
| +0x24 | ROUTE_$CONTROL_ECVAL | integer32 |
| +0x28 | ROUTE_$CONTROL_EC | ec_$eventcount_t |
| +0x34 | ROUTE_$SOCK | integer := -1 |
| +0x36 | ROUTE_$STD_N_ROUTING_PORTS | integer |
| +0x38 | ROUTE_$N_ROUTING_PORTS | integer |
| +0x3A | ROUTE_$ROUTING | boolean |

The ROUTE_UNWIRED block: ROUTE_$START_TIME (`define`d, time_$clockh_t)
and the module variable `route_$announce_template` (integer := 2).

The ROUTE_RTWIRED block (zero but the last 8 bytes): ROUTE_$WIRED_PAGES
(from 1), ROUTE_$Q_DEPTH (from 0), the nine counters
ROUTE_$STD_DLEN_ERR .. ROUTE_$Q_OFLO, ROUTE_$NETBUF_ALLOC,
ROUTE_$N_WIRED_PAGES, ROUTE_$N_USER_PORTS, ROUTE_$USER_STAT, ROUTE_$PID,
ROUTE_$USER_CHECKSUM (all `define`d), then the module variables
`unused_49a` (stand-in, a TODO), `route_$service_id`,
`route_$ptr_control_ec` := addr(route_$control_ec), `route_$fwd_timeout`
:= 1, `route_$packet_seq` := 16#8000 (with the module's prefix).
`route_rtwired.pas` has the table.

Routines (19 compiled): 11 globals, every map symbol of the three code
segments; three module-local (`internal`, no map symbol):
route_$cleanup_wired, route_$wire_routing_area (ROUTE_UNWIRED's) and
route_$validate_port (ASKNODE's); four nested in ROUTE_$SERVICE:
route_$init_routing and route_$close_port (each reads its static link),
route_$decrement_port and route_$announce_net (no link; nested by their
place in the family).  No hand
assembly (there is no route/sau2/).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| ROUTE_$FIND_PORT | `find_port.pas` |
| ROUTE_$FIND_PORTP | `find_portp.pas` |
| route_$validate_port | `validate_port.pas` (ASKNODE's; asknode/asknode.pas includes it) |
| route_$cleanup_wired | `cleanup_wired.pas` |
| route_$wire_routing_area | `wire_routing_area.pas` |
| ROUTE_$SHORT_PORT | `short_port.pas` |
| ROUTE_$GET_EC | `get_ec.pas` |
| route_$init_routing | `service.pas` (nested in ROUTE_$SERVICE) |
| route_$decrement_port | `service.pas` (nested in ROUTE_$SERVICE) |
| route_$close_port | `service.pas` (nested in ROUTE_$SERVICE) |
| route_$announce_net | `service.pas` (nested in ROUTE_$SERVICE) |
| ROUTE_$SERVICE | `service.pas` |
| ROUTE_$SHUTDOWN | `shutdown.pas` |
| ROUTE_$READ_USER_STATS | `read_user_stats.pas` |
| ROUTE_$PROCESS | `process.pas` |
| ROUTE_$INCOMING | `incoming.pas` |
| ROUTE_$OUTGOING | `outgoing.pas` |
| ROUTE_$SEND_USER_PORT | `send_user_port.pas` |
| (data) | the variables of the three module files |

Headings (`route.ins.pas`, in map order): ROUTE_$FIND_PORT,
_$FIND_PORTP, _$READ_USER_STATS and _$SEND_USER_PORT `val_param` (their
words and longwords read from the slots; the last two are NET_IO's
driver entries, their headings the routine types' in
`../net_io/net_io.ins.pas`); the others the default convention: the SVC
entries ROUTE_$GET_EC, _$SERVICE, _$INCOMING and _$OUTGOING every
argument by address, ROUTE_$SHORT_PORT the port and the summary by
address, ROUTE_$SHUTDOWN and ROUTE_$PROCESS none.  Functions:
ROUTE_$FIND_PORT (integer) and ROUTE_$FIND_PORTP (a pointer in A0; its
callers do not park it in D0).  The module-local and nested routines
take words, bytes and longwords by value (`internal`, nested).

The constant cells are listed in `route_unwired.pas` and
`route_rtwired.pas` (route_wired has none).

## Insert files

- `route.ins.pas` (users: app, hint, mac, mac_os, msg, net, net_io, pkt,
  rip, vtoc, xns and ROUTE's three modules, all checked by the gate):
  the ROUTE statuses, the operation members and two constants; the user
  packet and next-hop records, the user counters' record; the map
  symbols of the three blocks and the two wired area markers; the
  headings in map order.  Changed, every user re-checked:
  - **route_$port_t.socket and route_$short_port_t.socket integer**:
    ROUTE sign-extends both (ROUTE_$FIND_PORT and six more); the four
    NET_IO sites and three ROUTE sites that pass the port's word to a
    pinteger `var` or `out` formal compile without a message; the other
    users read it by value or compare
    words;
  - **route_$port_part_t a variant record**: its fields as the first arm
    (names unchanged), the two words at offsets 0x34, 0x36 the second
    (`unused_34`, `queue_length`), for ROUTE_$SHORT_PORT's and
    ROUTE_$READ_USER_STATS's word reads;
  - **route_$user_stat_t's first arm**: `counts` (route_$user_counts_t,
    the two longwords at 2), `queue_depth` (array[0..32] of integer32 at
    0xA) and `unused_8e`; NET_IO's fields (in_use, bytes) unchanged;
  - **ROUTE_$SEND_USER_PORT's header a pointer by value**
    (`hdr: pkt_$hdr_ptr_t`) and its **data_len pinteger**: the body
    passes its slot to a `var` and compares the length
    unsigned.
- `../rip/rip.ins.pas` (appended at the end, nothing above changed):
  the template type and its flags set, ROUTE_$SERVICE_MUTEX,
  RIP_$STD_IDP_CHANNEL, RIP_$BCAST_CONTROL, the headings of
  RIP_$PORT_CLOSE, _$SEND_UPDATES, _$UPDATE_D, _$BROADCAST and
  _$HALT_ROUTER.  RIP_$UPDATE_D's port summary makes the file need
  route.ins.pas first; every module file including it has it first.
- `../network/network.ins.pas` (appended at the end): NETWORK_$MOTHER_NODE.
- `../pkt/pkt.ins.pas` and `../pkt/send_internet.pas`:
  PKT_$SEND_INTERNET's **pkt_info `univ`**, as PKT_$SAR_INTERNET's: the
  announcer passes the 30-byte template.
- `../net_io/net_io.ins.pas`: net_io_$sendp_t's **header a pointer by
  value** and its **data length pinteger** (ROUTE_$SEND_USER_PORT's
  heading); NET_IO_$PUT_IN_SOCK's **data_pa `univ`** (ROUTE_$INCOMING
  passes one longword); `../net_io/put_in_sock.pas` repeats that
  heading; `../net_io/send.pas` passes `hdr_ptr` to the driver (the
  same push).
- Used as they are: base, ec, ml, time, pkt, proc1, misc/crash_system,
  uid, node, netbuf, os, sock, net, net_io, mac_os, xns, xns_idp, app,
  mst, wp, hint, ring/ringlog.  Nothing is declared here for the other
  agent's subsystems (no `TODO(merge)`).

## Open items

Form and names:
- No routine outside ROUTE_$SERVICE's family calls
  route_$decrement_port; RIP_$PORT_CLOSE's calls go to RIP's own
  routines.
- RIP_$SEND_UPDATES is a procedure: the word below its one-word argument
  is the alignment pad.
- The cells after ROUTE_$PROCESS are four: the third a 2-byte `false`
  and the `2048` after it a filler.
- ROUTE_$WIRED_PAGES is read 1-based by both walks.
- The port's socket is a signed word in the image.
- The summary's word at +6 (and ROUTE_$FIND_PORT's first parameter) is
  the port type, not a network.
- ROUTE_$SHORT_PORT copies the port's active word and socket.
- The packet header's lengths are at +0x14, +0x18 of the user packet
  (+0x10, +0x14 of the header).
- ROUTE_$OUTGOING reads the destination node from the internet header's
  address triple (pkt/pkt.ins.pas pkt_$inet_addr_t's node).
- route_$validate_port is ASKNODE's code.
- ROUTE_$SEND_USER_PORT takes the header as a pointer by value.

### TODO(pascal)

- `route_rtwired.pas`: 2 bytes of the ROUTE_RTWIRED block (+0x49A).
- `service.pas`: 8 frame bytes of ROUTE_$SERVICE; 8 of
  route_$init_routing.
- `process.pas`: 26 frame bytes of ROUTE_$PROCESS.
- `incoming.pas`: 10 frame bytes of ROUTE_$INCOMING.
- `outgoing.pas`: 26 frame bytes of ROUTE_$OUTGOING.
- `validate_port.pas`: 6 frame bytes of route_$validate_port.

Frames explained exactly by the locals (register-held locals keeping
their slots; the `with` temporaries; 8-byte alignment):
ROUTE_$FIND_PORT, _$FIND_PORTP, _$SHORT_PORT, _$GET_EC, _$SHUTDOWN,
_$READ_USER_STATS, _$SEND_USER_PORT, route_$cleanup_wired,
route_$wire_routing_area, route_$decrement_port, route_$close_port,
route_$announce_net.

## Named dispatch codes

ROUTE's dispatch codes are named constants: route/route.ins.pas
gives the port types route_$port_type_local (1) and _routing (2) and
ROUTE_$GET_EC's key (route_$ec_socket, _port).  get_ec.pas, incoming.pas,
outgoing.pas, process.pas, service.pas and shutdown.pas use them, as do rip/
and net_io/.  A token comparison against the previous text shows the code
unchanged.

Batch 2: a second block adds `route_$port_type_ring` = 0 (new;
RING_$INIT's port, ASKNODE's ring test, NET_IO_$BOOT_DEVICE's ring
boot). ROUTE_$READ_USER_STATS and _$SEND_USER_PORT pass
`route_$port_type_routing` to ROUTE_$FIND_PORT; ROUTE_$PROCESS tests
`pkt_$routing_inet` (pkt/pkt.ins.pas). Port types 4 and 5 stay numbers:
user drivers' types nothing names.
