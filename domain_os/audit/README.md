# The AUDIT subsystem in Domain Pascal

The audit trail (the per-process suspension counts, the audit list and
its hash table, the mapped log buffer, the server process that flushes
it, the control call).

## Layout

Two map modules with AUDIT's name, so two module files, and five routines
of a third (DIR's):

| map segment | section | routines / objects | Pascal |
|---------|---------|--------------------|--------|
| AUDIT, 0x18 bytes | WIRED_PROC | GET_WIRED | `../misc/get_wired.pas`, `[section(wired_proc, wired_data)]` |
| AUDIT data, 0x20 bytes | WIRED_DATA | GET_WIRED's static (the eventcount and lock) | `../misc/get_wired.pas` |
| AUDIT, 0xE14 bytes | .TEXT | AUDIT_$INIT .. audit_$close_log (below) | `audit.pas`, the default |
| AUDIT, 4 bytes | .TEXT | AUDIT_$PROC_END, four zero bytes | none: no code |
| AUDIT data, 0x1AC bytes | .DATA | the module's variables, the ten event UIDs | `audit.pas`'s variables and defined globals |
| AUDIT_LIST, 0xC00 bytes | its own load section | the hash nodes' pool | `audit.pas`, `var (audit_list)` |
| AUDIT_WIRED data, 4 bytes | WIRED_DATA | AUDIT_$CORRUPTED, AUDIT_$ENABLED | `audit_wired.pas`, data only |
| DIR, 0x8FD0 bytes (part) | .TEXT | DIR's five event loggers | fragments here, included by `../dir/dir.pas` |

`audit.pas` is `module audit;` (.TEXT and .DATA are the defaults; A5 is
the block's start).  `audit_wired.pas` is `module audit_wired, ,
wired_data;`, a unit with no code (HINT_WIRED's form), found by
`tools/pascal_check.sh` by its heading.

The AUDIT block (zero but the event UIDs):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `audit_$suspend_count` | array[1..64] of integer |
| +0x080 | `audit_$log_file_uid` | uid_$t |
| +0x088 | `audit_$buffer_base` | integer32 (an address) |
| +0x08C | `audit_$buffer_size` | integer32 |
| +0x090 | `audit_$write_ptr` | integer32 (an address) |
| +0x094 | `audit_$bytes_remaining` | integer32 |
| +0x098 | `audit_$file_offset` | integer32 |
| +0x09C | `audit_$dirty` | boolean |
| +0x0A0 | `audit_$list_uid` | uid_$t |
| +0x0A8 | `audit_$flags` | set of 0..15 |
| +0x0AA | `audit_$timeout` | integer |
| +0x0AC | `audit_$list_count` | integer |
| +0x0B0 | `audit_$hash_buckets` | array[0..37] of audit_$hash_node_ptr_t |
| +0x148 | AUDIT_$SCSI_ACQUIRE_EU .. AUDIT_$SET_SID_EU (`define`d, map symbols) | uid_$t, [16#0004001E, 0] .. [16#00040007, 0] |
| +0x198 | `audit_$wired` | audit_$wired_ptr_t (GET_WIRED's result) |
| +0x19C | `audit_$lock_id` | integer32 |
| +0x1A0 | `audit_$server_pid` | pinteger |
| +0x1A2 | `audit_$server_running` | boolean |
| +0x1A4 | `audit_$pool_next` | linteger |
| +0x1A8 | `audit_$pool_limit` | linteger |

Routines (24): eleven AUDIT_ globals in .TEXT (every map symbol of the
segment) and GET_WIRED; six module-local (`internal`, no map symbol):
audit_$start_logging, _$stop_logging, _$alloc, _$load_list, _$open_log,
_$close_log (and the DIR loggers below); two nested in audit_$load_list,
audit_$clear_hash_table (it reads its static link) and audit_$add_to_hash
(between it and the parent, called only from the parent).
None is hand assembly.  DIR's audit_$log_prot_op, _$log_mount_op,
_$log_link_op, _$log_dir_op and _$log_cname_op are module-local routines
of DIR (no map symbols), written here as DIR fragments.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| GET_WIRED | `../misc/get_wired.pas` |
| AUDIT_$INIT | `init.pas` |
| audit_$start_logging | `start_logging.pas` |
| AUDIT_$SHUTDOWN | `shutdown.pas` |
| audit_$stop_logging | `stop_logging.pas` |
| AUDIT_$IS_PROCESS_AUDITED | `is_process_audited.pas` |
| AUDIT_$SUSPEND | `suspend.pas` |
| AUDIT_$RESUME | `resume.pas` |
| AUDIT_$LOG_EVENT | `log_event.pas` |
| AUDIT_$LOG_EVENT_S | `log_event_s.pas` |
| AUDIT_$SERVER | `server.pas` |
| audit_$alloc | `alloc.pas` |
| audit_$clear_hash_table | `load_list.pas` (nested) |
| audit_$add_to_hash | `load_list.pas` (nested) |
| audit_$load_list | `load_list.pas` |
| AUDIT_$ADMINISTRATOR | `administrator.pas` |
| AUDIT_$CONTROL | `control.pas` |
| AUDIT_$INHERIT_AUDIT | `inherit_audit.pas` |
| audit_$open_log | `open_log.pas` |
| audit_$close_log | `close_log.pas` |
| (DIR) audit_$log_prot_op | `log_prot_op.pas` |
| (DIR) audit_$log_mount_op | `log_mount_op.pas` |
| (DIR) audit_$log_link_op | `log_link_op.pas` |
| (DIR) audit_$log_dir_op | `log_dir_op.pas` |
| (DIR) audit_$log_cname_op | `log_cname_op.pas` |
| (data) | the variables in `audit.pas`, `audit_wired.pas` |

Headings (`audit.ins.pas`): every AUDIT_ global the default convention
(every argument by address: the SVC cells of AUDIT_$LOG_EVENT and
AUDIT_$CONTROL, and every compiled caller, push addresses); the
module-local routines take words by value (`internal`), audit_$alloc's
result an integer (read in D0) converted by its caller.  No routine's
caller parks an A0 result in D0.  DIR's loggers: the event word, the
status and the lengths by value, the UIDs, data and texts by address
(their callers' pushes).

## Insert files

- `audit.ins.pas`: the statuses, the control commands and list flags,
  the wired record, the hash node and its link pointer, the list file's
  image, the event record (with its packed node field), the event UID as
  DIR builds it (a variant record), the protection data, the AUDIT_WIRED
  flags and the ten event UIDs (extern), the code and data markers, the
  eleven global headings.
- `file/file.ins.pas`: file_$attributes_t (0x90 bytes, the length at
  +0x14) and the headings of FILE_$GET_ATTRIBUTES, _$SET_TYPE, _$FW_FILE
  and _$TRUNCATE.
- `acl/acl.ins.pas`: the headings of ACL_$GET_PID_SID (`val_param`),
  _$GET_RE_SIDS and _$RIGHTS.
- `rgyc/rgyc.ins.pas`: RGYC_$G_LOGIN_UID; `uid/uid.ins.pas`:
  UNSTRUCT_$UID.
- Used as they are: base, ec, ml, time, vfmt, misc (GET_WIRED,
  CRASH_SYSTEM), proc1, proc2, os, mmu, wp, mst, node, name.

## Open items

Facts of the image's form:
- The list flag member 0 makes AUDIT_$LOG_EVENT_S log every event, so
  its name, audit_flag_selective, says the opposite.
- The ten event UIDs fill +0x148..+0x197 of the block.
- audit_$open_log, audit_$close_log and the DIR loggers have no map
  symbols; the loggers are DIR's module-local routines, not AUDIT's.
- audit_$log_prot_op copies the protection data inline as a record.
- AUDIT_$INIT's pooled zero longword cell is the literal 0 passed by
  address, which audit_$open_log also uses.
- PROC2_$GET_MY_UPIDS gets the record's +0x40, +0x44, +0x42 in that
  order (upid, upgid, uppid by `proc2/proc2.ins.pas`'s heading: upid,
  uppid, upgid); the record's field names are kept as they are.

### TODO(pascal)

- `init.pas`: 4 frame bytes of AUDIT_$INIT (stand-in).
- `start_logging.pas`: 44 frame bytes of audit_$start_logging; and
  `stop_logging.pas`: 8 of audit_$stop_logging (stand-ins).
- `alloc.pas`: 4 frame bytes of audit_$alloc.
- `load_list.pas`: 12 frame bytes of audit_$load_list, 12 of
  audit_$add_to_hash (and 4 of audit_$clear_hash_table, under
  AUDIT_$INIT's TODO).
- `open_log.pas`: 8 frame bytes of audit_$open_log.
- `log_event_s.pas`: actual_len's type (an unsigned compare and a
  sign-extending widening).
- `log_prot_op.pas`: 6 and 4 frame bytes of DIR's audit_$log_prot_op and
  _$log_mount_op.

Frames explained exactly: AUDIT_$SHUTDOWN,
_$LOG_EVENT, _$LOG_EVENT_S, _$SERVER, _$ADMINISTRATOR, _$CONTROL,
audit_$close_log, DIR's _$log_dir_op, _$log_link_op, _$log_cname_op.
