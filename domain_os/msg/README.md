# The MSG subsystem in Domain Pascal

The message sockets (the ownership and depth tables over SOCK's sockets,
the open, allocate and close calls, the receive calls and their shared
body, the send calls and their shared body with the bounce page, wait,
send-and-receive, the eventcount, and the address spaces' fork and
exit).

## Layout

The map has no module named MSG, so there is no `msg/msg.pas`.  Two map
modules, one module file each, which `tools/pascal_check.sh` finds by
their headings:

| file | heading | code | data |
|------|---------|------|------|
| `msg_wired.pas` | `module msg_wired, wired_proc, wired_data;` | MSG_WIRED, 0x2DC bytes, WIRED_PROC: MSG_$$SEND | MSG_WIRED, 0x20 bytes, WIRED_DATA, through A5 |
| `msg_unwired.pas` | `module msg_unwired;` | MSG_UNWIRED, 0x90 bytes, OS_INIT_PROC: MSG_$INIT (`[section(os_init_proc, os_init_data)]`); 0x100C bytes, .TEXT: MSG_$GET_MY_NET .. MSG_$SHARE_SOCKET (the defaults); 0x90 bytes, PROC2_CREATE_PRO: MSG_$FORK (`[section(proc2_create_pro, proc2_create_dat)]`); 0x58 bytes, PROC2_DELETE_PRO: MSG_$FREE_ASID (`[section(proc2_delete_pro, proc2_delete_dat)]`) | MSG_UNWIRED, 0x8E4 bytes, .DATA, through A5 in .TEXT (absolutely from the other sections) |

The MSG_WIRED block (zero but DPAGE_LOCK), its map symbols `define`d in
`msg_wired.pas`, declared in `msg.ins.pas` (MSG_UNWIRED's routines
reach them by their addresses):

| offset | variable | type |
|--------|----------|------|
| +0x00 | MSG_$SOCK_LOCK | ml_$exclusion_t (0x12 bytes) |
| +0x14 | DPAGE_VA | integer32 |
| +0x18 | DPAGE_PA | integer32 |
| +0x1C | DPAGE_LOCK | integer := -1 |

The MSG_UNWIRED block (zero but the template's first 16 bytes), module
variables in `msg_unwired.pas`:

| offset | variable | type |
|--------|----------|------|
| +0x000 | `msg_$send_template` | msg_$template_t (30 bytes) |
| +0x01E | `unused_1e` | integer (a stand-in; the TODO in `msg_unwired.pas`) |
| +0x020 | `msg_$depth` | array[1..0xE0] of integer |
| +0x1E0 | `msg_$ownership` | array[1..0xE0] of msg_$owner_t (a record of a 64-member set) |
| +0x8E0 | `msg_$open_count` | integer |

Routines (29 compiled): 28 globals, every map symbol of the five code
segments; one module-local (`internal`, no map symbol),
msg_$$rcv_internal, the shared receive body.  No nested routine, no
hand assembly (there is no msg/sau2/).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| MSG_$$SEND | `send_internal.pas` (MSG_WIRED's) |
| MSG_$INIT | `init.pas` |
| MSG_$GET_MY_NET | `get_my_net.pas` |
| MSG_$GET_MY_NODE | `get_my_node.pas` |
| MSG_$SET_HPIPC | `set_hpipc.pas` |
| MSG_$OPEN | `open.pas` |
| MSG_$OPENI | `openi.pas` |
| MSG_$ALLOCATE | `allocate.pas` |
| MSG_$ALLOCATEI | `allocatei.pas` |
| MSG_$CLOSE | `close.pas` |
| MSG_$CLOSEI | `closei.pas` |
| MSG_$RCV | `rcv.pas` |
| msg_$$rcv_internal | `rcv_internal.pas` |
| MSG_$RCVI | `rcvi.pas` (apart from MSG_$RCV: msg_$$rcv_internal lies between) |
| MSG_$RCV_CONTIG | `rcv_contig.pas` |
| MSG_$RCV_CONTIGI | `rcv_contigi.pas` |
| MSG_$RCV_HW | `rcv_hw.pas` |
| MSG_$SEND | `send.pas` |
| MSG_$SENDI | `sendi.pas` |
| MSG_$SEND_HW | `send_hw.pas` |
| MSG_$WAIT | `wait.pas` |
| MSG_$WAITI | `waiti.pas` |
| MSG_$GET_EC | `get_ec.pas` |
| MSG_$SAR | `sar.pas` |
| MSG_$SARI | `sari.pas` |
| MSG_$TEST_FOR_MESSAGE | `test_for_message.pas` |
| MSG_$SHARE_SOCKET | `share_socket.pas` |
| MSG_$FORK | `fork.pas` |
| MSG_$FREE_ASID | `free_asid.pas` |
| (data) | the variables of `msg_wired.pas`, `msg_unwired.pas` |

Headings (`msg.ins.pas`, in map order): MSG_$$SEND `val_param` (its
words and longwords read from the slots); msg_$$rcv_internal `internal`
(the socket and the two maxima by value); every other routine the
default convention.  The user calls are SVC entries: a scalar read
through its slot is `in`, MSG_$SEND's scalars and MSG_$RCV_CONTIG's
buffer pointer, copied at entry, value parameters.  Functions:
MSG_$OPEN, _$ALLOCATE, _$WAIT, _$TEST_FOR_MESSAGE and _$FORK
(booleans).  No routine returns a pointer to a caller that parks it.
The socket parameters are `in integer` (compared signed with 0),
MSG_$ALLOCATE(I)'s `out pinteger` (SOCK_$ALLOCATE_USER's formal).

The constant cells are listed in the header of `msg_unwired.pas`;
MSG_WIRED has none.

## Insert files

- `msg.ins.pas`: the statuses, the limits and members, the resource
  lock number (ml_lock_net_io), the asid set and the ownership element,
  the 30-byte template and its flag set, the send report's
  transmit-status view (a packed record with a set variant) and record,
  the internet address, the address record, the reply header; the
  MSG_WIRED variables; every MSG global's heading.
- `../network/network.ins.pas` (appended, nothing above changed):
  status_$network_unknown_network, the NETWORK_$SET_SERVICE operations
  and routing member, network_$service_set_t and network_$service_t,
  NETWORK_$USER_SOCK_OPEN, the heading of NETWORK_$SET_SERVICE.
- `../route/route.ins.pas` (appended): the heading of ROUTE_$FIND_PORT.
- `../proc2/proc2.ins.pas` (appended): the heading of PROC2_$GET_ASID.
- Used as they are: base, ec, ml, time, pkt, proc1, fim, crash_system,
  os, node, netbuf, route, sock, net
  (status_$internet_unknown_network_port), xns (for app), app, net_io.
  No heading or type of another unit is changed: where MSG passes one
  variable to formals of two types (MSG_$$SEND's packet info, its
  header cell, its packet record), the local has two views
  (`send_internal.pas`).

## Open items

### Types and names

- msg_$hw_addr_t.flags is the receive record's bits 17..24, APP's
  net_type (app/app.ins.pas), not its queue_count (bits 9..16).
- The depth and ownership tables are arrays from 1 at +0x20 and +0x1E0
  (the 2 bytes at +0x1E: the TODO in `msg_unwired.pas`), and an
  ownership element is a record of one 64-member set, which MSG_$FORK
  and MSG_$FREE_ASID reach through a `with` (the copy at the loop
  head).
- The copied template type is 30 bytes (pkt_$info_t without its pad
  word), and its flags word is a set.
- MSG_$WAITI widens its timeout with zeros, MSG_$SARI sign-extends its.
- ROUTE_$FIND_PORT's first parameter is compared with the port's
  port_type.
- MSG_$RCV_CONTIGI clamps the template's length to the maximum first,
  so its data budget is never negative.
- MSG_$INIT stores one set constant five times; there is no loop and no
  table of the sockets.
- MSG_$GET_EC's result is EC2_$REGISTER_EC1's pointer, ec2_$ptr_t (the
  customer ipc.ins.pas's ipc_$get_ec).
- MSG writes the transmit status as a packed record with a set view
  (bit 3 set, bit 15 a boolean's store, its test the word's sign).

### TODO(pascal)

- `msg_unwired.pas`: the 2 bytes at +0x1E of the MSG_UNWIRED block.
- `msg_unwired.pas`: the 8-byte alignment of MSG's frame objects (the
  2-byte stand-ins in `rcv.pas`, `sar.pas`, `rcv_hw.pas`).
- `rcvi.pas`: 52 frame bytes of MSG_$RCVI no object explains (and
  MSG_$RCV_HW's 48 + 4, `rcv_hw.pas`).
- `sari.pas`: 58 frame bytes of MSG_$SARI no object explains.

Frames explained exactly by the locals (each
register-held local keeping its slot), the reserved slot of
msg_$$rcv_internal and the `with` temporaries: MSG_$$SEND, MSG_$INIT,
MSG_$OPEN, MSG_$OPENI, MSG_$ALLOCATE(I), MSG_$CLOSE(I),
msg_$$rcv_internal, MSG_$RCV_CONTIGI, MSG_$SENDI, MSG_$SEND_HW,
MSG_$WAIT(I), MSG_$TEST_FOR_MESSAGE, MSG_$SHARE_SOCKET, MSG_$FORK,
MSG_$FREE_ASID; MSG_$RCV, MSG_$RCV_CONTIG, MSG_$SEND and MSG_$SAR with
the 8-byte alignment (the TODO).

## Named dispatch codes

MSG_$SEND's template (msg_unwired.pas) uses pkt/pkt.ins.pas's
`pkt_$routing_inet` and `pkt_$addr_long` (pkt's dispatch-code block).
msg_proto_subtype_inet (16#29) is pkt's `pkt_$subtype_long_addr`.
