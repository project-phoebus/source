# The REM_FILE subsystem in Domain Pascal

The remote file manager (the client stubs that send FILE_, AST_, ACL_,
AREA_ and NAME_ requests to another node, the transport they share, and
REM_FILE_$SERVER, which answers them).

## Layout

One map module, so one module file, **`rem_file.pas`, `module rem_file;`**
(the map segment's name): one compilation unit in one code section and
one data section, with a named data section of its own.

| section | code | routines (image order) | attribute |
|---------|------|------------------------|-----------|
| .TEXT | 0x35C0 bytes | rem_file_$send_request, REM_FILE_$RN_DO_OP .. REM_FILE_$SERVER: 31 globals, one module-local routine and the eight routines nested in REM_FILE_$SERVER (table below) | none (the defaults) |

The routines with frames load A5 with the .DATA block's start (30
loads); REM_FILE_$SEND_REQUEST loads none and uses its callers'.

Data:

| block | section | contents |
|-------|---------|----------|
| the map's REM_FILE data segment, 0xC bytes | .DATA | the module's variables (below) |
| REM_FILE_$DATA, 0x7C bytes | its own load section | `var (rem_file_$data)`, initialized (below) |

The .DATA block (probed with dpc: the offsets, the bytes and the size
0xC):

| offset | variable | type, image bytes |
|--------|----------|-------------------|
| +0x00 | `rem_file_$stale_link_count` | integer32, zero |
| +0x04 | `rem_file_$busy_retry_count` | integer32, zero |
| +0x08 | REM_FILE_$COMPLETION_TIME (`define`d) | pinteger: 16#14 |
| +0x0A | (2 bytes: the block's rounding to 4) | |

The section REM_FILE_$DATA (probed: dpc puts the three at +0x00, +0x1E,
+0x3C with the image's bytes, size 0x7C, in a section named
REM_FILE_$DATA):

| offset | variable | type, image contents |
|--------|----------|----------------------|
| +0x00 | `rem_file_$pkt_info` | rem_file_$pkt_template_t: flags 16#10, routing 2, address type 2, protocol 16#8031, retry limit 16#FFFF, 0, 16#FFFF, the address zero |
| +0x1E | `rem_file_$server_pkt_info` | rem_file_$pkt_template_t: the same with flags 16#20 |
| +0x3C | `rem_file_$diskless_crash_msg` | array[1..64] of char: `*** diskless partner node has crashed and rebooted - so must we%` |

Only REM_FILE's code addresses the three, absolutely (a byte search of
the image), so no other module declares them.  The map names only the
section REM_FILE_$DATA; the first variable is `rem_file_$pkt_info`.

Records (probed with dpc):

| record | fields (offset) | size |
|--------|-----------------|------|
| rem_file_$pkt_template_t (`rem_file.pas`) | flags 0x00 .. field_0c 0x0C, addr 0x0E | 0x1E |
| rem_file_$request_hdr_t (`rem_file.ins.pas`) | msg_type 0x00, magic 0x02, opcode 0x03 | 4 |
| rem_file_$response_t (`rem_file.ins.pas`) | pkt_flag 0x00, magic 0x02, opcode 0x03, status 0x04 | 8 |
| rem_file_$req_t (`rem_file.pas`) | hdr 0x00, uid 0x04; create: session_uid 0x0C, type_uid 0x14, parent_uid2 0x1C, owner 0x24, create_size 0x54, create_type 0x58, create_flags 0x5A; presr10: type 0x0C, version 0x0E, super 0x10, index 0x12, session 0x14; truncate: flags 0x0C, size 0x0E, version 0x12, super 0x14; set_attribute: attr_id 0x0C, attr_value 0x0E; lock: key 0x0C, node 0x10, type 0x14, mode 0x16, then version 0x18, super 0x1A, one 0x1E or flags 0x18, one 0x1A, loc 0x1C, exsid 0x3C, wait 0xA0; unlock: rem_key 0x0C, rem_node 0x10, mode 0x14, version 0x18, super 0x1A, key 0x1C, release 0x20; unlock_all: version 0x0C, super 0x0E; verify_lock 0x0C; bytes_0c 0x0C..0xAF; the variants 10..25 of the other clients | 0xB0 |
| rem_file_$reply_t (`rem_file.pas`) | hdr 0x00; reply_uid 0x08; reply_attrs 0x0C, reply_loc 0x9C, reply_key 0xBC, reply_loc_addr 0xAC; reply_clock 0x08; lock_handle 0x08, lock_word 0x0C; dtv 0x08, unlock_result 0x0E, attrs_valid 0x0F, dtu 0x10; reply_lock 0x08; the variants 7..13 | 0xBE |
| rem_file_$loc_view_t (`rem_file.pas`) | loc 0x00; addr 0x10 | 0x20 |
| rem_file_$pkt_view_t (`rem_file.pas`) | tmpl 0x00; flags_set 0x00 | 0x1E |
| rem_file_$rn_op_buf_t (`rem_file.ins.pas`) | hdr 0x00, op_data 0x04, subsys_ids 0x14, flags_20 0x20, sids 0x28, proj_list 0x4C, proj_count 0x8C; list_data_va 0x8E, list_data_len 0x92, list_reply_va 0xAC, list_inline_data 0xB0; entry_dest_off 0x8E, entry_data_len 0x90, entry_data_va 0x92; read_dir_reply_max 0x96, read_dir_reply_va 0x9A; bytes 0x00 | 0x122 |
| rem_file_$server_req_t (`rem_file.pas`) | the client request; the `sa_`, `dl_`, `sv_`, `dir` and `acl` views; bytes | 0x298 |
| rem_file_$server_resp_t (`rem_file.pas`) | the client reply; bytes; the `dir`, `acl` and `sv_` views | 0x120 |
| rem_file_$log_info_t (`rem_file.pas`) | an 8-bit code, a 4-bit queue count and a 20-bit node, or two words | 4 |

Routines: the 31 map symbols are globals, REM_FILE_$SEND_REQUEST
module-local (`internal`), the eight server_* helpers nested in
REM_FILE_$SERVER: each reads its static link, from the dynamic link or
from A1 at entry.  The opcode-to-log-code mapping has no routine of its
own: it is a compare chain inline in REM_FILE_$SERVER (no call).  None
is hand assembly (there is no `rem_file/sau2/`).

Each nested helper is its own fragment, `server_<name>.pas`, included
by `server.pas`'s declaration part in image order; `rem_file.pas`
includes only `server.pas`.  The helpers name these objects of
REM_FILE_$SERVER (its frame; it has no parameters), which `server.pas`
declares with these names and types:

| object | type | used by |
|--------|------|---------|
| request_len | pinteger (compared unsigned and zero-extended) | server_get_entry_sids (the old protocol's length 16#32) |
| reply_len | pinteger (compared unsigned; DIR_$SERVER's `var integer` and ACL_$SERVER's `out pinteger` are identical types for it) | every helper stores the reply's length |
| tmp_index | integer | server_unmap_name's `for` index |
| request | rem_file_$server_req_t (0x298) | all eight |
| response | rem_file_$server_resp_t (0x120) | all eight |
| uid_retry | integer | server_generate_uid |
| trunc_result | boolean | server_truncate_delete, AST_$TRUNCATE's `out` result |
| location_unused | integer32 | server_generate_uid, AST_$GET_LOCATION's unread `var` longword |

## Routines and their fragments

`rem_file.pas` includes them all in image order.  The sizes are to the
next routine; constant cells after a routine's code are counted in its
size and named in its fragment.

| routine | size | kind | fragment |
|---------|------|------|----------|
| rem_file_$send_request | 0x560 | local | `send_request.pas` |
| REM_FILE_$RN_DO_OP | 0x1E2 | global | `rn_do_op.pas` |
| REM_FILE_$CREATE_TYPE | 0x14E | global | `create_type.pas` |
| REM_FILE_$CREATE_TYPE_PRESR10 | 0x10E | global | `create_type_presr10.pas` |
| REM_FILE_$TRUNCATE | 0xBC | global | `truncate.pas` |
| REM_FILE_$SET_ATTRIBUTE | 0x7C | global | `set_attribute.pas` |
| REM_FILE_$LOCK | 0x1C4 | global | `lock.pas` |
| REM_FILE_$UNLOCK_ALL | 0xAA | global | `unlock_all.pas` |
| REM_FILE_$UNLOCK | 0x104 | global | `unlock.pas` |
| REM_FILE_$LOCAL_VERIFY | 0x7A | global | `local_verify.pas` |
| REM_FILE_$LOCAL_READ_LOCK | 0xA4 | global | `local_read_lock.pas` |
| REM_FILE_$GET_SEG_MAP | 0x15C | global | `get_seg_map.pas` |
| REM_FILE_$NAME_GET_ENTRYU | 0x11E | global | `name_get_entryu.pas` |
| REM_FILE_$NEIGHBORS | 0xA4 | global | `neighbors.pas` |
| REM_FILE_$PURIFY | 0x92 | global | `purify.pas` |
| REM_FILE_$SET_DEF_ACL | 0x86 | global | `set_def_acl.pas` |
| REM_FILE_$TEST | 0x64 | global | `test.pas` |
| REM_FILE_$INVALIDATE | 0x80 | global | `invalidate.pas` |
| REM_FILE_$RESERVE | 0x94 | global | `reserve.pas` |
| REM_FILE_$NAME_ADD_HARD_LINKU | 0x9C | global | `name_add_hard_linku.pas` |
| REM_FILE_$DROP_HARD_LINKU | 0x9A | global | `drop_hard_linku.pas` |
| REM_FILE_$CREATE_AREA | 0xAA | global | `create_area.pas` |
| REM_FILE_$DELETE_AREA | 0x68 | global | `delete_area.pas` |
| REM_FILE_$GROW_AREA | 0x74 | global | `grow_area.pas` |
| REM_FILE_$ACL_IMAGE | 0x94 | global | `acl_image.pas` |
| REM_FILE_$ACL_CREATE | 0xF4 | global | `acl_create.pas` |
| REM_FILE_$ACL_SETIDS | 0xB8 | global | `acl_setids.pas` |
| REM_FILE_$ACL_CHECK_RIGHTS | 0xC0 | global | `acl_check_rights.pas` |
| REM_FILE_$SET_ACL | 0xBC | global | `set_acl.pas` |
| REM_FILE_$FILE_SET_PROT | 0xBE | global | `file_set_prot.pas` |
| REM_FILE_$FILE_SET_ATTRIB | 0xC8 | global | `file_set_attrib.pas` |
| server_unmap_name | 0x60 | nested | `server_unmap_name.pas` |
| server_get_entry | 0x9E | nested | `server_get_entry.pas` |
| server_set_attribute | 0x16C | nested | `server_set_attribute.pas` |
| server_get_entry_sids | 0x142 | nested | `server_get_entry_sids.pas` |
| server_drop_link | 0x12C | nested | `server_drop_link.pas` |
| server_truncate_delete | 0x100 | nested | `server_truncate_delete.pas` |
| server_generate_uid | 0x82 | nested | `server_generate_uid.pas` |
| server_set_prot_attrib | 0x242 | nested | `server_set_prot_attrib.pas` |
| REM_FILE_$SERVER | 0x1012 | global | `server.pas` (the eight helpers included in its declaration part; a status cell and 2 zero bytes follow its code) |

## Insert files

- `rem_file.ins.pas` (users: acl, area, dir, dir_server, old_dir, file,
  network, asknode, rem_file; its earlier headings were written by those
  subsystems' translations from their callers, each checked against its
  body here): the types rem_file_$byte_t, rem_file_$request_hdr_t,
  rem_file_$response_t and rem_file_$rn_op_buf_t (base, uid and acl
  types only), rem_file_$owner_info_t, rem_file_$acl_buf_t,
  rem_file_$op_buf_t, rem_file_$name_get_entryu_result_t, the variable
  REM_FILE_$SOCK_LOCK, the request operation codes rem_file_op_* (an
  insert's constants, so that ACL_$SERVER names its five from the same
  definitions), and every routine's heading.  The modes follow the
  bodies: an addr_info passed only to the sender's `in univ` is `in` (by
  address either way under the default convention); under `val_param`
  addr_info stays `var` (an `in` 4-byte parameter would go by value).
- `rem_file.pas`: rem_file_$pkt_template_t, the request and reply records
  and their views, the module's constants (rem_file_req_magic,
  rem_file_req_version, rem_file_acl_req_flags, rem_file_prot_attr_*,
  rem_file_server_socket, rem_file_op_bad_version, its reply code,
  the DIR_ and ACL_ ranges, the three log-only codes; most names new),
  the module's variables, the REM_FILE_$DATA section.
- `../file/file.ins.pas`: file_$attributes_t's fourth variant (REM_FILE_
  $LOCK's plain result, lock_handle +0x2C and lock_word +0x30), its fifth
  (byte_00, for server_truncate_delete's test of the attributes' first
  byte; the filler a 1-char field then an array from +0x02: a char array
  is word-aligned), and file_$remote_lock_table_full (16#000F000A,
  stcode.db.10.2's "remote lock table is full").
- `../uid/uid.ins.pas`: SLINK_$UID, the symbolic link's type UID
  server_set_attribute compares with.
- DIR_$SERVER's heading (dir/dir_server.ins.pas) agrees with
  REM_FILE_$SERVER's three pushes (the request and reply `univ`,
  reply_len a word).
- The DIR_ operations whose text or buffer travels as bulk data
  (16#3C, 16#3E, 16#42, 16#58) are dir/dir.ins.pas's dir_op_add_linku,
  _read_linku, _dir_readu and _resolve; server_set_prot_attrib's
  protection kinds are file/file.ins.pas's file_$prot_*.  REM_FILE_$SERVER's
  NETLOG log codes and REM_FILE_$SEND_REQUEST's connection states are
  not dispatch codes and stay numbers.

## Open items

Facts about the image the names do not tell:
- REM_FILE_$SEND_REQUEST's data-page test reads bulk_max: a request with
  extra data but no bulk buffer and a reply of at most 0x200 bytes gets
  no data page, and one with a bulk buffer always gets one.
- server_drop_link, for a locksmith request, puts the locksmith's UID
  into the login SID of the SID block it installs, and UID_$NIL into it
  before restoring.
- server_truncate_delete's reply clock is the attributes' DTA, their
  +0x34 longword and +0x38 word.
- REM_FILE_$CREATE_AREA's `local_volx` is the negotiated packet size
  (NETWORK_$GET_PKT_SIZE's result); its `shared` is never read.
- The split reply's bulk pointer, the reply's +0x200, lies past the
  reply record and REM_FILE_$SERVER's frame, in
  NETWORK_$REQUEST_SERVER's frame; the Pascal writes it
  addr(response.bytes[16#200]), a constant subscript out of range (a
  warning in the reference; dpc now warns, "best effort (not
  byte-identical)").

### TODO(pascal)

- `rem_file.pas`: REM_FILE_'s frames against their locals (send_request:
  0x40 and 12 bytes held by stand-ins, 4 open; rn_do_op: 18 open bytes;
  create_type: 0x28 bytes above its reply held by the stand-in
  unused_28; unlock: 6 open bytes; the nested helpers' open bytes;
  REM_FILE_$SERVER: 0x40 bytes held by the stand-in unused_70, 20 open).
