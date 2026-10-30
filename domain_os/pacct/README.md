# The PACCT subsystem in Domain Pascal

Process accounting.

## Layout

One module, `pacct.pas`, `module pacct;` (the map segments' name):

| section | code size | routines | attribute |
|---------|-----------|----------|-----------|
| OS_INIT_PROC | 0x24 | PACCT_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | 0x678 | PACCT_$SHUTDN, PACCT_$START (three constant cells), PACCT_$STOP, PACCT_$ON, pacct_$compress, pacct_$clock_to_comp, PACCT_$LOG (one cell) | none |

Data: the map's PACCT data segment in .DATA (0x20 bytes), all zero, no
interior symbol: seven module variables, used by every routine
(PACCT_$INIT reaches the block absolutely):

| offset | variable | type |
|--------|----------|------|
| +0x00 | `pacct_owner` | uid_$t |
| +0x08 | `pacct_lock_handle` | integer32 |
| +0x0C | `pacct_buf_remaining` | integer32 |
| +0x10 | `pacct_write_ptr` | integer32 |
| +0x14 | `pacct_map_offset` | integer32 |
| +0x18 | `pacct_map_ptr` | integer32 |
| +0x1C | `pacct_file_pos` | integer32 |

No routine is nested; two are module-local (`internal`).

## Routines and their fragments

| routine | fragment |
|---------|----------|
| PACCT_$INIT | `init.pas` |
| PACCT_$SHUTDN | `shutdn.pas` |
| PACCT_$START | `start.pas` |
| PACCT_$STOP | `stop.pas` |
| PACCT_$ON | `on.pas` |
| pacct_$compress | `compress.pas` (internal function) |
| pacct_$clock_to_comp | `clock_to_comp.pas` (internal function) |
| PACCT_$LOG | `log.pas` |

## Insert files

- `pacct.ins.pas`: sizes and constants, `comp_t`, the record and its
  flag word (a packed record with a word view), the times and command
  types, the six headings.
- `acl/acl.ins.pas`: `acl_sid_block_t`, `acl_prot_info_t`,
  `acl_$exsid_t`; ACL_$GET_EXSID, _$GET_RE_ALL_SIDS, _$ENTER_SUPER,
  _$EXIT_SUPER; status_$insufficient_rights_to_perform_operation.
- `rgyc/rgyc.ins.pas`: RGYC_$G_LOCKSMITH_UID.
- `file/file.ins.pas`: `file_$byte_t`, `file_$attr_info_t` (0x80
  bytes); FILE_$PRIV_LOCK, _$PRIV_UNLOCK (dtv_out a 48-bit clock),
  _$GET_ATTR_INFO, _$SET_LEN; status_$no_rights.
- `cal/cal.ins.pas`: CAL_$CLOCK_TO_SEC (hand assembly in .DATA).
- `mst/mst.ins.pas`, `time/time.ins.pas`: used as they are.

## Open items

### Form

- FILE_$PRIV_UNLOCK's dtv_out is a 6-byte clock (AST_$GET_DTV stores a
  longword and a word through it), so the PACCT callers' local is a
  time_$clock_t.  FILE_$PRIV_UNLOCK calls AST_$GET_DTV only when
  `is_exclusive & by_key' is negative; the three PACCT calls pass by_key
  false, so only longword clears reach the local at run time.
- PACCT_$LOG stores MST_$MAPS's result in pacct_map_ptr before testing
  the status.
- PACCT_$STOP and PACCT_$START: the locals' declaration order is the
  one that fits the frame.

### TODO(pascal)

- `stop.pas` (and `start.pas`): 4 frame bytes above exsid (stand-ins
  `unused_4`; perhaps an 8-byte alignment).
- `log.pas`: 4 frame bytes at the bottom (stand-in `unused_1a4`); the
  stand-ins between the blocks are the same 8-alignment lead.
- `compress.pas`: a bit test read as `(value & 4) <> 0`.