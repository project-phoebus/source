# The REM_NAME subsystem in Domain Pascal

The remote naming service's client (locating a naming server, the
request/reply exchange with it, and the directory lookups built on
that).

## Layout

One module, `rem_name.pas`, `module rem_name;` (the map segments'
name): the code in .TEXT and the block in .DATA, the defaults (ref
7.1.1), as `hint/hint.pas`.

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| .TEXT | 0xB20 bytes | REM_NAME_SERVER_LOCAL, LOCATE_SERVER, REM_NAME_$REGISTER_SERVER, rem_name_$send_request, REM_NAME_$GET_ENTRY_BY_NAME, _$GET_INFO, _$LOCATE_SERVER, _$GET_ENTRY_BY_NODE_ID, _$GET_ENTRY_BY_UID, _$READ_DIR, _$READ_REP, _$DIR_READU, _$GET_ENTRY, _$FIND_NETWORK, _$FIND_UID | none (the default) |

Data: the map's 0x40-byte REM_NAME data segment in .DATA, through A5
(loaded by every routine but REM_NAME_SERVER_LOCAL, which reaches no
data, and REM_NAME_$REGISTER_SERVER, which addresses the block
absolutely; rem_name_$send_request inherits it):

| offset | variable | type | initial value |
|--------|----------|------|-------|
| +0x00 | `rem_name_$config` | rem_name_$config_t (15 words) | 16#10, 2, 2, 16#8031, 16#FFFF, 0, 16#FFFF, 0, zero |
| +0x1E | 2 bytes: the next object's alignment | | zero |
| +0x20 | `rem_name_$server_timeout` | linteger | 2400 |
| +0x24 | `rem_name_$reserved2` (no routine addresses it) | integer32 | 16#4B0 |
| +0x28 | REM_NAME_$TIME_HEARD_FROM_SERVER (`define`d) | time_$clockh_t | zero |
| +0x2C | REM_NAME_$LAST_STATUS (`define`d) | status_$t | the fail bit |
| +0x30 | REM_NAME_$CURR_NODE (`define`d) | integer32 | zero |
| +0x34 | REM_NAME_$CURR_NET (`define`d) | integer32 | zero |
| +0x38 | REM_NAME_$SERVICE_DELAY (`define`d) | pinteger | 16#10 |
| +0x3A | `rem_name_$retry_count` | integer | zero |
| +0x3C | REM_NAME_$HEARD_FROM_SERVER (`define`d) | boolean | false |
| +0x3D | 3 bytes: the block's rounding to 4 | | |

Nothing outside this module addresses the block.

Routines: fourteen globals (every map symbol, REM_NAME_SERVER_LOCAL and
LOCATE_SERVER too, whose names have no `$`) and one
module-local (`internal`, no map symbol), rem_name_$send_request.  None
is nested, none is hand assembly.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| REM_NAME_SERVER_LOCAL | `server_local.pas` |
| LOCATE_SERVER | `locate_server_internal.pas` |
| REM_NAME_$REGISTER_SERVER | `register_server.pas` (../domain-pascal's conformance unit) |
| rem_name_$send_request | `send_request.pas` (the 4-byte cell after it) |
| REM_NAME_$GET_ENTRY_BY_NAME | `get_entry_by_name.pas` |
| REM_NAME_$GET_INFO | `get_info.pas` |
| REM_NAME_$LOCATE_SERVER | `locate_server.pas` |
| REM_NAME_$GET_ENTRY_BY_NODE_ID | `get_entry_by_node_id.pas` |
| REM_NAME_$GET_ENTRY_BY_UID | `get_entry_by_uid.pas` |
| REM_NAME_$READ_DIR | `read_dir.pas` |
| REM_NAME_$READ_REP | `read_rep.pas` |
| REM_NAME_$DIR_READU | `dir_readu.pas` |
| REM_NAME_$GET_ENTRY | `get_entry.pas` |
| REM_NAME_$FIND_NETWORK | `find_network.pas` |
| REM_NAME_$FIND_UID | `find_uid.pas` |
| (data) | the block in `rem_name.pas` |

Headings (`rem_name.ins.pas`):
- `val_param` (longwords and words by value): GET_ENTRY_BY_NAME,
  GET_INFO, GET_ENTRY_BY_NODE_ID, GET_ENTRY_BY_UID, READ_DIR, READ_REP;
  rem_name_$send_request is `internal` (the same convention).
- The default convention (every argument by address):
  REM_NAME_SERVER_LOCAL (none), LOCATE_SERVER, REGISTER_SERVER,
  REM_NAME_$LOCATE_SERVER, DIR_READU, GET_ENTRY, FIND_NETWORK, FIND_UID.
- REM_NAME_SERVER_LOCAL and rem_name_$send_request are boolean
  functions (D0.b).  No routine returns a pointer, so no D0 parking.

## Insert files

- `rem_name.ins.pas`: the socket, the entry types and reply sizes, the
  template, name, entry-data, directory and replica entry records and
  their `univ` arrays, GET_INFO's 22 bytes, DIR_READU's continuation,
  the reply header and the two reply records, the request records, the
  six map-symbol variables of the block, and the fourteen headings in
  map order.
- `name/name.ins.pas`: Apollo's `name_$bad_pathname` (customer
  name.ins.pas) and four naming statuses (16#E0019, 16#E001A, 16#E001C,
  16#E001E), constants only.  Its users (`fim/fim.pas`,
  `flop/flop.pas`, `hint/hint.pas`, `log/log.pas`, `volx/volx.pas`,
  `misc/misc.ins.pas`'s modules) still check.
- `pkt/pkt.ins.pas` and `pkt/sar_internet.pas`: PKT_$SAR_INTERNET's
  heading changed in two parameters, with the evidence in its comment:
  `pkt_info` is `univ pkt_$info_t` (both callers pass a 30-byte
  template copied whole, rem_name_$send_request and
  ASKNODE_$INTERNET_INFO, which a 32-byte non-`univ` formal cannot
  take; the TODO in `send_request.pas` has the other reading), and
  `resp_tpl_len` is integer (only written there; REM_NAME's caller
  compares it signed).  Its only user in the tree is `pkt/pkt.pas` (the
  body); it still checks, and so does `netlog/netlog.pas` (pkt_$info_t
  is unchanged).
- Used as they are: `base`, `ec`, `time` (TIME_$CLOCKH), `os`
  (OS_$DATA_COPY), `node` (NODE_$ME), `netbuf` (NETBUF_$GET_HDR,
  _$RTN_HDR), `sock` (SOCK_$SOCKET_PTR, the flag set),
  `misc/crash_system`.

## Open items

### Types and names

- LOCATE_SERVER is a map symbol, a global, as
  REM_NAME_SERVER_LOCAL is.
- The 2 bytes at +0x1E of the block are the alignment of
  server_timeout after the 30-byte template; nothing addresses them.
- Bit 13 of the socket's flag word is sock's `sock_flag_allocated`
  (`server_local.pas`).
- The requests are the sizes sent (0x54, 0x3A, 0x32 ...), placed by the
  8-byte alignment of frame objects.
- GET_ENTRY_BY_NODE_ID stores the node address as two 24-bit fields,
  08 00 1E and the node.
- GET_INFO's and LOCATE_SERVER's frame byte for the send's result is
  a compiler spill, not a declared local.
- DIR_READU's shared code is the merge of identical copies.
- READ_DIR's and READ_REP's ways out of the loops are `exit`s.

### TODO(pascal)

- `send_request.pas`: the 30-byte template against PKT_$SAR_INTERNET's
  32-byte pkt_$info_t (`univ` here, or a 30-byte pkt_$info_t).
- `send_request.pas`: 20 to 26 frame bytes above sar_result (a
  declared local, or a larger result record than pkt_$sar_result_t).
- `get_entry_by_name.pas`: six frame bytes below reply_len, the same
  in GET_INFO, LOCATE_SERVER, GET_ENTRY_BY_NODE_ID and _BY_UID.
- `read_dir.pas`: 32 frame bytes (READ_REP's 16 likewise).
- `find_network.pas`: 48 frame bytes, the size of a directory entry.
