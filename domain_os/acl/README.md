# The ACL_ subsystem in Domain Pascal

The access control list manager (the per-process SIDs and projects, the
super-user and subsystem states, the ACL image cache, rights evaluation,
ACL creation and conversion).

## Layout

Two module files, one per map module:

- `acl.pas`, `module acl_;` (the map segments' name): one compilation
  unit in four code sections and four data sections.  The .TEXT
  routines load A5 with the .DATA block, and ACL_$INIT reaches the same
  block by its address.
- `acl_wired.pas`, `module acl_wired, , wired_data;`: the ACL_WIRED
  segment, data only, the exclusion lock ACL_$EXCLUSION_LOCK
  (HINT_WIRED's and AUDIT_WIRED's shape).

`tools/pascal_check.sh` finds both (the first by its name, the second by
its heading).

| section | code size | routines (image order) | attribute |
|---------|-----------|------------------------|-----------|
| OS_INIT_PROC | 0xF8 | ACL_$INIT | `[section(os_init_proc, os_init_data)]` |
| .TEXT | 0x4CCC | the 19 module-local routines, then ACL_$MIN_RIGHTS .. ACL_$SERVER (43 globals) and the module-local acl_$setids and acl_$image_internal | none (the defaults) |
| PROC2_CREATE_PRO | 0x144 | ACL_$ALLOC_ASID | `[section(proc2_create_pro, proc2_create_dat)]` |
| PROC2_DELETE_PRO | 0x184 | ACL_$GET_SID, ACL_$FREE_ASID | `[section(proc2_delete_pro, proc2_delete_dat)]` |

Data:

| block | section | contents |
|-------|---------|----------|
| ACL_, 0xBFC bytes | .DATA | the module's variables (below) |
| ACL_, 4 bytes | OS_INIT_DATA | zero; A5 = its end in ACL_$INIT, unused |
| ACL_, 4 bytes | PROC2_CREATE_DAT | zero; A5 = its end in ACL_$ALLOC_ASID, unused |
| ACL_, 4 bytes | PROC2_DELETE_DAT | zero; A5 = its end in ACL_$GET_SID and ACL_$FREE_ASID, unused |
| ACL_$DATA, 0xAD98 bytes | its own load section | the overlay `var (acl_$data)` (below) |
| ACL_WIRED, 0x14 bytes | WIRED_DATA | ACL_$EXCLUSION_LOCK (acl_wired.pas) |

The .DATA block (zero but -1 at +0xAF0..+0xB69 and +0xB76; offsets
checked with a dpc probe unit):

| offset | variable | type |
|--------|----------|------|
| +0x000 | `acl_$workspace` | array[1..0x400] of char |
| +0x400 | `acl_$image_buf` | acl_$cache_slot_t (0x400) |
| +0x800 | `acl_$cache_dir` | array[0..30] of acl_$cache_dir_t (0x10 each) |
| +0x9F0 | `acl_$cache_lru_links` | array[0..31] of acl_$cache_link_t |
| +0xA70 | `acl_$cache_hash_links` | array[0..31] of acl_$cache_link_t |
| +0xAF0 | `acl_$cache_hash_buckets` | array[0..60] of integer, all -1 |
| +0xB6A | `unused_b6a`, a stand-in (no instruction addresses it) | integer |
| +0xB6C | `acl_$subs_magic` | integer32 |
| +0xB70 | `acl_$local_locksmith` | integer |
| +0xB72 | `acl_$locksmith_owner_pid` | integer |
| +0xB74 | `acl_$cache_free_head` | integer |
| +0xB76 | `acl_$cache_lru_head` | integer, -1 |
| +0xB78 | ACL_$SUPER_COUNT (`define`d, map symbol) | array[1..64] of integer |
| +0xBF8 | `acl_$locksmith_override` | boolean |

The overlay ACL_$DATA (zero: loaded past the file's end; ACL_$INIT
zeroes it):

| offset | variable | type |
|--------|----------|------|
| +0x0000 | `acl_$acl_cache` | array[0..30] of acl_$cache_slot_t |
| +0x7C00 | `acl_$original_sids` | array[1..64] of acl_sid_block_t |
| +0x8500 | `acl_$current_sids` | array[1..64] of acl_sid_block_t |
| +0x8E00 | `acl_$saved_sids` | array[1..64] of acl_sid_block_t |
| +0x9700 | `acl_$saved_proj` | array[1..64] of acl_proj_list_t |
| +0x9A00 | `acl_$proj_lists` | array[1..64] of acl_proj_list_t |
| +0x9D00 | `acl_$asid_free_bitmap` | packed array[1..64] of boolean |
| +0x9D08 | `acl_$proj_uids` | array[1..64] of acl_$proj_uids_t |
| +0xAD08 | `acl_$subsys_level` | array[1..64] of integer |
| +0xAD88 | `acl_$locksmith_override_bitmap` | packed array[1..64] of boolean |
| +0xAD90 | `acl_$asid_suser_bitmap` | packed array[1..64] of boolean |

The module's own names are prefixed `acl_$`.  Every
per-process table is from pid 1 and the objects are adjacent (a 0-based
view would see each table's element 0 as the previous object's tail,
and the super-mode count's element 0 as the LRU head).  The per-process
tables are reached from 60000 bytes into ACL_$DATA, the compiler's base
for sections over 0x8000 bytes.

Routines: 47 globals (every map symbol of the four code segments) and
the module-local ones (`internal`, no map symbol): the nineteen before
ACL_$MIN_RIGHTS (among them acl_$prim_create_internal with its four
nested routines), acl_$setids and acl_$image_internal.  None is hand
assembly (there is no `acl/sau2/`).  Every module-local routine's body
precedes its callers, so `acl.pas` has no forward headings.

## Routines and their fragments

| routine | fragment |
|---------|----------|
| ACL_$INIT | `init.pas` |
| acl_$cache_list_insert | `cache_list_insert.pas` |
| acl_$cache_list_remove | `cache_list_remove.pas` |
| acl_$sids_allowed | `sids_allowed.pas` |
| acl_$convert_rights | `convert_rights.pas` |
| acl_$convert_image | `convert_image.pas` |
| acl_$prim_create_internal, with its four nested routines | `prim_create_internal.pas` |
| acl_$alloc_cache_slot | `alloc_cache_slot.pas` |
| acl_$expand_default_acl | `expand_default_acl.pas` |
| acl_$load_acl_image | `load_acl_image.pas` |
| acl_$find_acl_slot | `find_acl_slot.pas` |
| acl_$get_obj_acl_attrs | `get_obj_acl_attrs.pas` |
| acl_$eval_acl_entries | `eval_acl_entries.pas` |
| acl_$check_suser_pid | `check_suser_pid.pas` |
| acl_$is_process_type_2 | `is_process_type_2.pas` |
| acl_$eval_rights | `eval_rights.pas` |
| ACL_$MIN_RIGHTS | `min_rights.pas` |
| ACL_$RIGHTS | `rights.pas` |
| ACL_$CHECK_RIGHTS | `check_rights.pas` |
| ACL_$RIGHTS_CHECK | `rights_check.pas` |
| acl_$setids | `setids.pas` |
| ACL_$ENTER_SUBS | `enter_subs.pas` |
| ACL_$ENTER_SUPER | `enter_super.pas` |
| ACL_$EXIT_SUPER | `exit_super.pas` |
| ACL_$CLEAR_SUPER | `clear_super.pas` |
| ACL_$UP | `up.pas` |
| ACL_$DOWN | `down.pas` |
| ACL_$IN_SUBSYS | `in_subsys.pas` |
| ACL_$SET_ACL_CHECK | `set_acl_check.pas` |
| ACL_$DEFAULT_ACL | `default_acl.pas` |
| ACL_$DEF_ACLDATA | `def_acldata.pas` |
| ACL_$PRIM_CREATE | `prim_create.pas` |
| acl_$image_internal | `image_internal.pas` (module-local; its callers all follow it) |
| ACL_$IMAGE | `image.pas` |
| ACL_$IS_SUSER | `is_suser.pas` |
| ACL_$ADD_PROJ | `add_proj.pas` |
| ACL_$DELETE_PROJ | `delete_proj.pas` |
| ACL_$GET_PROJ_LIST | `get_proj_list.pas` |
| ACL_$SET_PROJ_LIST | `set_proj_list.pas` |
| ACL_$SET_RE_ALL_SIDS | `set_re_all_sids.pas` |
| ACL_$SET_RES_ALL_SIDS | `set_res_all_sids.pas` (an ordinary routine with its own frame) |
| ACL_$GET_RE_ALL_SIDS | `get_re_all_sids.pas` |
| ACL_$GET_RES_ALL_SIDS | `get_res_all_sids.pas` |
| ACL_$GET_RE_SIDS | `get_re_sids.pas` |
| ACL_$GET_RES_SIDS | `get_res_sids.pas` |
| ACL_$GET_EXSID | `get_exsid.pas` |
| ACL_$GET_PID_SID | `get_pid_sid.pas` |
| ACL_$CHECK_FAULT_RIGHTS | `check_fault_rights.pas` |
| ACL_$CHECK_DEBUG_RIGHTS | `check_debug_rights.pas` |
| ACL_$SET_DEF_ACL_CHECK | `set_def_acl_check.pas` |
| ACL_$CONVERT_TO_9ACL | `convert_to_9acl.pas` |
| ACL_$CONVERT_TO_10ACL | `convert_to_10acl.pas` |
| ACL_$CONVERT_FROM_9ACL | `convert_from_9acl.pas` |
| ACL_$CONVERT_FUNKY_ACL | `convert_funky_acl.pas` |
| ACL_$INHERIT_SUBSYS | `inherit_subsys.pas` |
| ACL_$SET_LOCAL_LOCKSMITH | `set_local_locksmith.pas` |
| ACL_$GET_LOCAL_LOCKSMITH | `get_local_locksmith.pas` |
| ACL_$OVERRIDE_LOCAL_LOCKSMITH | `override_local_locksmith.pas` |
| ACL_$USED_SUSER | `used_suser.pas` |
| ACL_$COPY | `copy.pas` |
| ACL_$SERVER | `server.pas` |
| ACL_$ALLOC_ASID | `alloc_asid.pas` |
| ACL_$GET_SID | `get_sid.pas` |
| ACL_$FREE_ASID | `free_asid.pas` |
| (data) | the variables in `acl.pas`, `acl_wired.pas` |

Headings (`acl.ins.pas`): every global is the default convention
(every argument by address) but ACL_$ALLOC_ASID, ACL_$FREE_ASID,
ACL_$GET_PID_SID and ACL_$OVERRIDE_LOCAL_LOCKSMITH, `val_param`; the
module-local routines are `internal`, their pointers by address and
their words and bytes by value.  Function results: ACL_$MIN_RIGHTS a
rights word, ACL_$RIGHTS, _$CHECK_RIGHTS, _$RIGHTS_CHECK integer32,
ACL_$ENTER_SUBS, _$IN_SUBSYS, _$IS_SUSER and the other checks boolean,
ACL_$DEFAULT_ACL a uid_$t through a hidden address.  No routine returns
a pointer, so no D0 parking.  `acl.ins.pas` also holds FILE_'s and DIR's
headings that take the protection record (FILE_$SET_PROT, FILE_$OLD_AP,
DIR_$GET_DEF_PROTECTION, DIR_$SET_DEF_PROTECTION, DIR_$SET_PROTECTION),
one copy each with their bodies' modes.  The ACL_WIRED lock's extern is
declared in `acl.pas` and `acl_wired.pas`, not in `acl.ins.pas`, because
fim/fim.pas and pacct/pacct.pas include `acl.ins.pas` without
`ml/ml.ins.pas`.

ACL_$SERVER's `case` labels are rem_file/rem_file.ins.pas's operation
codes (rem_file_op_acl_image 16#64 .. _acl_check_rights 16#6C).  The
`10` in that routine is the 16#66 arm's `goto` label, not a `case` arm.

The SAU9's ACL_ (and the other 68020 builds', SAU6..SAU8) is this
source with no conditional arm: the fifteen routines its code
generation changes (ACL_$RIGHTS, ACL_$ENTER_SUPER, ACL_$CLEAR_SUPER,
ACL_$SET_ACL_CHECK, the four SID routines, ACL_$CHECK_DEBUG_RIGHTS,
the two locksmith routines, ACL_$USED_SUSER, ACL_$INIT, ACL_$ALLOC_ASID
and ACL_$FREE_ASID) have their sau9 addresses.

## Open items

ACL_$PRIM_CREATE does not set the status's fail bit when
FILE_$PRIV_CREATE fails: it branches to the cleanup past the bit's set,
so the create's own status comes back as it is.  The failures after the
file is mapped (MST_$MAPS, MST_$UNMAP_PRIVI, FILE_$MK_IMMUTABLE,
AST_$PURIFY) do set it.

Form and names:
- acl_$is_process_type_2's name says the opposite of its result (true
  when the type is not 2).
- ACL_$ENTER_SUBS' debugger lookup is PROC2_$GET_DEBUGGER_PID (a map
  symbol).
- ACL_$INIT computes the zeroing length as FILE_$LOT_DATA's address less
  ACL_$DATA's, 0xAD98.
- ACL_$SET_RE_ALL_SIDS' and ACL_$SET_RES_ALL_SIDS' five references to
  the process's tables are one `with' with five pseudonyms (ref C.3.18):
  each register holds the tables' index term, not an element address.

### TODO(pascal)

- `acl.pas`: the three 4-byte data blocks and the A5 loads into them
  (XPD's open point).
- `acl.pas`: the frames of many routines against their objects (the list
  there).
- `init.pas`: the zeroing length's left operand, FILE_$LOT_DATA's start,
  written as FILE's lock table's first byte through a stand-in overlay
  variable.
- `free_asid.pas`: the 12-byte project list copied from a constant in
  the code (VTOCE_$OLD_TO_NEW's and FLP_$DINIT's case).
- `def_acldata.pas`: the record's last 16 bytes copied from a constant
  cell after the code (free_asid's case).
- `prim_create.pas`: the magic longword's address formed in one register
  and copied into another before the store, the shape of a `with'
  temporary; the construct is not identified.
