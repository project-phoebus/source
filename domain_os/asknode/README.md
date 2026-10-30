# The ASKNODE subsystem in Domain Pascal

The node-information requester and server (ASKNODE_$INFO and its family
answering a request locally or asking another node, the server side
answering other nodes, and the WHO census).

## Layout

One module, `asknode.pas`, `module asknode;` (the map segments' name):
the code in .TEXT and the block in .DATA, the defaults (ref 7.1.1), as
`rem_name/rem_name.pas`.

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| .TEXT | ASKNODE, 0x21A0 bytes | ASKNODE_$INFO, _$GET_INFO, _$INTERNET_INFO, _$READ_FAILURE_REC, route_$validate_port, ASKNODE_$SERVER, _$PROPAGATE_WHO, _$WHO, _$WHO_NOTOPO, _$WHO_REMOTE | none (the default) |

Data: the map's ASKNODE data segment in .DATA, 0x20 bytes, no interior
symbol, through A5 (loaded by every routine but INFO, GET_INFO and
route_$validate_port, which reach no data):

| offset | variable | type | initial value |
|--------|----------|------|---------------|
| +0x00 | `asknode_$pkt_info` | asknode_$template_t (30 bytes) | flags 16#10, routing_type 2, addr_type 2, protocol 16#8031, retry_limit 16#FFFF, 0, 16#FFFF, the address zero |
| +0x1E | `asknode_$protocol_version` | integer | 3 |

The template is copied whole by five routines and the word is compared
on its own: two objects, not one 32-byte pkt_$info_t.

Routines: nine globals (every map symbol) and one module-local
(`internal`, no map symbol), route_$validate_port, whose fragment is
route/'s.  None is hand assembly.  No routine nests another.

### Probes

Probe modules (one store, `addr` or `sizeof` per field) put every field
of the records the module defines at the offset the image addresses:
asknode_$info_reply_t (all its variants, size 0x40A, request 16#31's
LOG_ buffer being the largest; the callers pass 0x200), asknode_$param_t
(size 0x10, its views), asknode_$template_t (0x1E), the block (the
version word at +0x1E, 0x20 bytes), asknode_$server_ctx_t (0x22) and
asknode_$server_args_t (0x14), SERVER's request (0x18) and reply
(0x200), asknode_$who_request_t (0x18), asknode_$who_reply_t (0x200),
asknode_$node_list_t (elements 4 bytes from 1, 8000 bytes),
asknode_$disp_entry_t (0x12), asknode_$port_entry_t (6),
asknode_$log_ctl_t (0xE), asknode_$signal2_t (0x10); and the other
subsystems' records used here (pkt_$internet_hdr_t, 0x16;
network_$failure_rec_t; app_$receive_rec_t, 0x2C; rip_$dest_addr_t, 12;
rip_$nexthop_t, 10; route_$port_t, 0x5C; the ring, disk, mem and cal
records copied whole).

`dpc --dump-locals` gives PROPAGATE_WHO, WHO, WHO_NOTOPO and WHO_REMOTE
the image's frame sizes, with every addressed scalar at the image's
offset; the records come out 2 to 0x10 bytes off, the image 8-aligning
them (the TODO(pascal) blocks in the three fragments).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| ASKNODE_$INFO | `info.pas` (its constant cells after it) |
| ASKNODE_$GET_INFO | `get_info.pas` |
| ASKNODE_$INTERNET_INFO | `internet_info.pas` (its constant cells after it) |
| ASKNODE_$READ_FAILURE_REC | `read_failure_rec.pas` |
| route_$validate_port | `../route/validate_port.pas` (route's; included here) |
| ASKNODE_$SERVER | `server.pas` (a constant cell after it) |
| ASKNODE_$PROPAGATE_WHO | `propagate_who.pas` |
| ASKNODE_$WHO | `who.pas` |
| ASKNODE_$WHO_NOTOPO | `who_notopo.pas` |
| ASKNODE_$WHO_REMOTE | `who_remote.pas` (to the segment's end) |
| (data) | the block in `asknode.pas` |

Headings: the default convention (every argument by address) for all.
INFO and GET_INFO (`asknode_info.ins.pas`) forward their slots;
INTERNET_INFO's reply is `var` (its version is read first), its request
type pinteger (the remote path's unsigned compare).  READ_FAILURE_REC
(`asknode_info.ins.pas`, beside INTERNET_INFO's, since its type is
NETWORK_'s): one `out` record.  SERVER's heading (`asknode.ins.pas`):
the context `var`, routing `var`; PROPAGATE_WHO's: the context `var`,
routing `in`.  WHO, WHO_NOTOPO and WHO_REMOTE (`asknode.ins.pas`): the
node and the port `in` (read; WHO passes NODE_$ME's and ROUTE_$PORT's
addresses), the list `out` (written before any element is read), the
maximum `in` integer, the count `out` pinteger (WHO_NOTOPO counts in
place and compares it zero-extended), the status `out`.

## Insert files

- `asknode.ins.pas`: the request codes, the three reply codes SERVER
  stores by value (the reply is otherwise the request + 1), the
  who-routines' constants (asknode_$max_who_count 2000,
  asknode_$who_socket 5, asknode_$done_marker -16#2151, i.e. 16#DEAF),
  the reply buffer, SERVER's context (its five longwords from +0x04 one
  record, asknode_$server_args_t, because SERVER copies them whole), the
  node list, and the headings of SERVER, PROPAGATE_WHO, WHO, WHO_NOTOPO
  and WHO_REMOTE.  `network/network.pas` includes it before RING_,
  DISK_, MEM_ and CAL_, so it holds nothing that needs them.  The
  request-code constants are used in every case label, compare, store
  and variant tag that is a request code; the tags that are views (0, 1,
  2, 3) stay numbers, and so does SERVER's otherwise arm's reply type 0.
- `asknode_info.ins.pas`: the parameter block and the reply record
  (variants per request, holding RING_'s, DISK_'s, MEM_'s and CAL_'s
  records whole), their component records, and the INFO, GET_INFO,
  INTERNET_INFO and READ_FAILURE_REC headings.  It needs the insert
  files of TIME_, VFMT_, IO_, PEB_, PROC1_, NETWORK_, NETLOG_, ROUTE_,
  LOG_, SMD_, OS_ and HINT_ before it; `os/os.pas` includes it after
  them, for network_$fetch_diskless_info's call.
- Other subsystems' declarations this translation settled:
  MMAP_$REAL_PAGES linteger (request 6 compares it unsigned);
  NETWORK_$MOTHER_NODE linteger (the unmasked merges);
  network_$backlog_t (the reply copies the two backlogs whole);
  pkt_$internet_hdr_t's dest_node at +0x08 (SERVER reads it as a
  longword); PROM_$MACHINE_ID as prom_$machine_id_t (the longword `id`,
  which request 16#27 copies, with a word view `sau` of its high half);
  route_$port_t's request-16#3D view (clock_4e at +0x4E, counts:
  route_$port_counts_t at +0x54); smd_disp_info_result_t's four words
  as one record, dims: smd_$disp_dims_t; the proc2_ list and info
  headings; GPU_$PRESENT, MMU_$SYSTEM_REV; the statuses
  status_$network_bad_asknode_version_number (16#00110015),
  _conflict_with_another_node_listing (16#110019),
  _quit_fault_during_node_listing (16#11001A),
  _waited_too_long_for_more_node_responses (16#11001B).
- `asknode.ins.pas`: `{ TODO(merge) move to rem_file/rem_file.ins.pas }`
  REM_FILE_$2LONG1, waiting for rem_file's translation.

## Open items

### TODO(pascal)

- `internet_info.pas`, "request 16#41: the local route copied from a
  constant in the code": three stores, as FLP_$DINIT's.
- The frames: "10 frame bytes of PROPAGATE_WHO hold nothing"
  (propagate_who.pas), "WHO_NOTOPO's frame has 46 bytes nothing
  addresses" (who_notopo.pas), "WHO_REMOTE's frame has 44 bytes nothing
  addresses" (who_remote.pas): the 8-aligned records, which dpc does not
  do, and the holes that are likely the register-held locals' homes; the
  stand-ins give dpc the image's scalar offsets and frame sizes.
  SERVER's frame has 8 bytes nothing addresses the same way.
