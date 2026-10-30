{ acl/acl.pas - the ACL_ module, the access control list manager.

  Image addresses:
    sau2  0x00E7CF54  ACL_ data (.DATA, 0xBFC bytes)
    sau2  0x00E35034  ACL_ data (OS_INIT_DATA, 0x4 bytes)
    sau2  0x00E86054  ACL_ data (PROC2_CREATE_DAT, 0x4 bytes)
    sau2  0x00E86060  ACL_ data (PROC2_DELETE_DAT, 0x4 bytes)
    sau2  0x00E88834  ACL_$DATA (overlay section, 0xAD98 bytes)

  One compilation unit: the map's ACL_ code segments in OS_INIT_PROC
  (ACL_$INIT), .TEXT (the module-local routines, then ACL_$MIN_RIGHTS ..
  ACL_$SERVER), PROC2_CREATE_PRO (ACL_$ALLOC_ASID) and PROC2_DELETE_PRO
  (ACL_$GET_SID, ACL_$FREE_ASID), each headed with its sections, and
  its data segments, the three small ones 4 zero bytes.

  ACL_WIRED (acl/acl_wired.pas) holds ACL_$EXCLUSION_LOCK.  ACL_$DATA
  is an overlay section (ref 3.14 p. 3-52), declared below.

  The .DATA block, zero but the 61 words -1 at +0xAF0..+0xB69 and the
  word -1 at +0xB76:
    +0x000  acl_$workspace          1024 bytes, the conversions' workspace
    +0x400  acl_$image_buf          1024 bytes, an ACL image
    +0x800  acl_$cache_dir          31 * 16 bytes, the cache directory

    +0x9F0  acl_$cache_lru_links    32 * 4 bytes
    +0xA70  acl_$cache_hash_links   32 * 4 bytes
    +0xAF0  acl_$cache_hash_buckets 61 * 2 bytes, all -1

    +0xB6A  (2 bytes no instruction addresses: unused_b6a, a stand-in)
    +0xB6C  acl_$subs_magic         4 bytes
    +0xB70  acl_$local_locksmith    2 bytes
    +0xB72  acl_$locksmith_owner_pid 2 bytes
    +0xB74  acl_$cache_free_head    2 bytes
    +0xB76  acl_$cache_lru_head     2 bytes, -1

    +0xB78  ACL_$SUPER_COUNT        64 * 2 bytes, from pid 1 (defined)
    +0xBF8  acl_$locksmith_override 1 byte
    +0xBF9  (3 bytes: the boolean's word and the block's rounding)

  The overlay ACL_$DATA, 44440 bytes, zero (ACL_$INIT zeroes it); each
  per-process table is from pid 1:
    +0x0000  acl_$acl_cache         31 * 1024 bytes, the image cache
    +0x7C00  acl_$original_sids     64 * 36 bytes
    +0x8500  acl_$current_sids      64 * 36 bytes

    +0x8E00  acl_$saved_sids        64 * 36 bytes
    +0x9700  acl_$saved_proj        64 * 12 bytes
    +0x9A00  acl_$proj_lists        64 * 12 bytes

    +0x9D00  acl_$asid_free_bitmap  64 bits
    +0x9D08  acl_$proj_uids         64 * 64 bytes
    +0xAD08  acl_$subsys_level      64 * 2 bytes
    +0xAD88  acl_$locksmith_override_bitmap 64 bits
    +0xAD90  acl_$asid_suser_bitmap 64 bits

  The routines live in one fragment file each (acl/<name>.pas, the
  nested ones with their parents), included below in image order;
  acl/README.md has their table.

  Build: dpc -I domain_os domain_os/acl/acl.pas.  Check:
  tools/pascal_check.sh.
}
module acl_;

{ TODO(pascal) the three 4-byte data blocks and the A5 loads into them

  The OS_INIT_DATA, PROC2_CREATE_DAT and PROC2_DELETE_DAT blocks, all
  zero, hold no object of the source that this module can name; the
  four routines of those code sections load A5 with their ends and
  never use it (above).  The same open point as xpd/xpd.pas's (the cause
  not known).  Until it is settled the module declares nothing for them,
  and dpc loads no A5 there. }

{ TODO(pascal) the ACL_ routines' frames against their locals

  Several routines' frames hold bytes that their objects do not
  explain: ACL_$MIN_RIGHTS, ACL_$FREE_ASID, ACL_$CLEAR_SUPER,
  acl_$convert_image, acl_$get_obj_acl_attrs, acl_$pci_uid_ge,
  acl_$pci_subsys_rights, acl_$prim_create_internal (fits only if each
  `with' and each register-held local keeps a slot), acl_$load_acl_image,
  acl_$eval_rights (too few bytes if each register-held local keeps a
  slot), acl_$eval_acl_entries, ACL_$SET_ACL_CHECK, ACL_$PRIM_CREATE,
  acl_$image_internal, the four project-list routines,
  ACL_$SET_RE_ALL_SIDS and ACL_$SET_RES_ALL_SIDS (the `with'
  temporaries' order is not settled), ACL_$GET_EXSID,
  ACL_$CHECK_DEBUG_RIGHTS, ACL_$SET_DEF_ACL_CHECK, ACL_$CONVERT_TO_9ACL
  and ACL_$CONVERT_TO_10ACL.  Exact: ACL_$INIT, acl_$setids,
  ACL_$ENTER_SUBS (an 8-byte alignment of objects of 8 bytes or more and
  the value parameters' copies below the locals), acl_$check_suser_pid,
  acl_$pci_rights_mask, acl_$pci_copy_entry, ACL_$DEFAULT_ACL,
  ACL_$IMAGE (but its rounding), ACL_$GET_PID_SID,
  ACL_$CHECK_FAULT_RIGHTS, ACL_$CONVERT_FROM_9ACL.  The `with'
  temporaries' slots are the lead. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'mst/mst.ins.pas';
%include 'fim/fim.ins.pas';
%include 'uid/uid.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'acl/acl.ins.pas';
%include 'ast/ast_acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'hint/hint.ins.pas';
%include 'rgyc/rgyc.ins.pas';

const
  { No slot: an empty list's head, the end of a hash chain
    (acl_$cache_list_insert, acl_$cache_list_remove). }
  acl_cache_no_slot = -1;

type
  { A pointer to a longword: ACL_$ENTER_SUBS reads the caller's return
    address through the user stack pointer. }
  acl_$long_ptr_t = ^integer32;
  { An ACL image as 256 longwords, as ACL_$PRIM_CREATE and
    acl_$image_internal copy one, and ACL_$PRIM_CREATE stores its last
    but one. }
  acl_$image_longs_t = array[1..256] of integer32;
  acl_$image_longs_ptr_t = ^acl_$image_longs_t;

  { acl_$cache_entry_t and acl_$cache_slot_t, the image types, are in
    acl/acl.ins.pas: ACL_$PRIM_CREATE's and ACL_$IMAGE's headings take
    the image by its type. }

  { One entry of a version-4 ACL image, 0x2C bytes: the person, group,
    organization and subsystem UIDs, two longwords, the rights longword.
    acl_$convert_image walks them from +0x34 of the image in steps of
    0x2C, compares the three UIDs with UID_$NIL, passes the rights by
    value, and copies the three UIDs as one 24-byte object (ids, the
    second variant). }
  { The first 0x24 bytes of a version-4 entry, its three SIDs, the
    subsystem UID and reserved_20, as one record: the routines that
    build entries store these five fields through one address register
    and the entry's reserved_24 and rights through another, in
    acl_$prim_create_internal's four blocks and in acl_$load_acl_image's
    appended entry: a `with' on this record, the two others named
    through the entry. }
  acl_$v4_ids_t = record
    person: uid_$t;                       { 0x00 }
    group: uid_$t;                        { 0x08 }
    org: uid_$t;                          { 0x10 }
    subsys: uid_$t;                       { 0x18 }
    reserved_20: integer32;               { 0x20 }
  end;
  acl_$v4_entry_t = record
    case integer of
      1: (person: uid_$t;                 { 0x00 }
          group: uid_$t;                  { 0x08 }
          org: uid_$t;                    { 0x10 }
          subsys: uid_$t;                 { 0x18 }
          reserved_20: integer32;         { 0x20 }
          reserved_24: integer32;         { 0x24 }
          rights: integer32);             { 0x28 }
      2: (ids: array[1..24] of char);     { 0x00 }
      3: (ids_block: acl_$v4_ids_t);      { 0x00 }
  end;
  { The two longwords at +0x20 are reserved_20 and reserved_24:
    acl_$prim_create_internal clears them one by one. }
  { The header shared by the version-4 and version-5 images as
    acl_$convert_image sees them: the cache slot's header
    (acl_$cache_slot_t), but the required and subsystem UIDs at +0x12
    one 16-byte object, copied byte by byte. }
  { acl_$prim_create_internal builds this image, so the header's names
    are its: the 16 bytes at +0x12 are also the required and subsystem
    UIDs (the second variant, stored as longwords), the six bytes at
    +0x22 the three entry-number words owner_slot, group_slot and
    org_slot. }
  acl_$v4_image_t = record
    version: integer;                     { 0x00 }
    type_uid: [aligned(1)] uid_$t;        { 0x02 }
    reserved_0a: [aligned(1)] integer32;  { 0x0A }
    entry_count: integer;                 { 0x0E }
    reserved_10: integer;                 { 0x10 }
    case integer of
      1: (ids16: array[1..16] of char;    { 0x12 }
          owner_slot: integer;            { 0x22 }
          group_slot: integer;            { 0x24 }
          org_slot: integer;              { 0x26 }
          world_entry_present: boolean;   { 0x28 }
          unused_29: char;                { 0x29 }
          reserved_2a: array[1..5] of integer;
                                          { 0x2A }
          entries: array[1..22] of acl_$v4_entry_t;
                                          { 0x34 }
          tail_3fc: array[1..4] of char); { 0x3FC }
      2: (required_uid: [aligned(1)] uid_$t;
                                          { 0x12 }
          subsys_uid: [aligned(1)] uid_$t);
                                          { 0x1A }
  end;
  acl_$v4_image_ptr_t = ^acl_$v4_image_t;
  { (acl_$cache_slot_ptr_t is in acl/acl.ins.pas.) }
  { The version-5 image acl_$convert_image builds: the cache slot as that
    routine addresses it, its header as acl_$v4_image_t's, then either
    twelve words from +0x2A (the clearing loop, which runs past
    reserved_2a into the first entry) or reserved_2a and the entries. }
  acl_$v5_build_t = record
    version: integer;                     { 0x00 }
    type_uid: [aligned(1)] uid_$t;        { 0x02 }
    reserved_0a: [aligned(1)] integer32;  { 0x0A }
    entry_count: integer;                 { 0x0E }
    reserved_10: integer;                 { 0x10 }
    ids16: array[1..16] of char;          { 0x12 }
    reserved_22: [aligned(1)] integer32;  { 0x22 }
    reserved_26: integer;                 { 0x26 }
    world_entry_present: boolean;         { 0x28 }
    unused_29: char;                      { 0x29 }
    case integer of
      1: (words_2a: array[1..12] of integer);
                                          { 0x2A }
      2: (reserved_2a: array[1..5] of integer;
                                          { 0x2A }
          entries: array[1..30] of acl_$cache_entry_t;
                                          { 0x34 }
          tail_3f4: array[1..12] of char);
                                          { 0x3F4 }
  end;
  acl_$v5_build_ptr_t = ^acl_$v5_build_t;
  { A UID as two longwords, compared in order and unsigned
    (acl_$pci_uid_ge). }
  acl_$uid_longs_t = array[1..2] of linteger;
  { One cache directory entry, 0x10 bytes. }
  acl_$cache_dir_t = record
    acl_uid: uid_$t;                      { 0x00 }
    hash_bucket: integer;                 { 0x08 }
    cached_flag: boolean;                 { 0x0A }
    reserved_0b: char;                    { 0x0B }
    world_rights: integer;                { 0x0C }
    subsys_rights: integer;               { 0x0E }
  end;

  { One node of the cache's slot lists, 4 bytes. }
  acl_$cache_link_t = record
    next: integer;                        { 0x00 }
    prev: integer;                        { 0x02 }
  end;
  { The two link arrays, one link per slot (32: the 31 cache slots and
    one spare): one named type, as acl_$cache_list_insert and _remove
    take either by address. }
  acl_$cache_links_t = array[0..31] of acl_$cache_link_t;
  { A UID's bytes, words and halves, as acl_$get_obj_acl_attrs reads
    them: the top byte and word of the high half, the low half's high
    word, the low half as a number and as a set (bit 24 cleared). }
  acl_$uid_view_t = record
    case integer of
      1: (uid: uid_$t);
      2: (w0: integer;                    { 0x00 }
          w1: integer;                    { 0x02 }
          w2: pinteger;                   { 0x04 }
          w3: integer);                   { 0x06 }
      3: (b0: acl_$attr_byte_t);          { 0x00 }
      4: (high: integer32;                { 0x00 }
          low: linteger);                 { 0x04 }
      5: (high_set: set of 0..31;         { 0x00 }
          low_set: set of 0..31);         { 0x04 }
  end;
  acl_$uid_view_ptr_t = ^acl_$uid_view_t;

{  AST_$GET_ACL_ATTRIBUTES' heading,
  declared here before, is ast/ast_acl.ins.pas's now (included above). }

{  The headings of FILE_$SET_PROT,
  FILE_$OLD_AP, DIR_$GET_DEF_PROTECTION, DIR_$SET_DEF_PROTECTION and
  DIR_$SET_PROTECTION that ACL_ parts 5 and 5e declared here are in
  acl/acl.ins.pas now, one copy each with the bodies' modes. }

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
var
  acl_$workspace: array[1..1024] of char;            { +0x000, zero }
  acl_$image_buf: acl_$cache_slot_t;                 { +0x400, zero }
  acl_$cache_dir: array[0..30] of acl_$cache_dir_t;  { +0x800, zero }
  acl_$cache_lru_links: acl_$cache_links_t;
                                                     { +0x9F0, zero }
  acl_$cache_hash_links: acl_$cache_links_t;
                                                     { +0xA70, zero }
  acl_$cache_hash_buckets: array[0..60] of integer := [* of -1];
                                                     { +0xAF0: -1 * 61 }
  unused_b6a: integer;                               { +0xB6A, zero:
                                                       above }
  acl_$subs_magic: integer32;                        { +0xB6C, zero }
  acl_$local_locksmith: integer;                     { +0xB70, zero }
  acl_$locksmith_owner_pid: integer;                 { +0xB72, zero }
  acl_$cache_free_head: integer;                     { +0xB74, zero }
  acl_$cache_lru_head: integer := -1;                { +0xB76: -1 }

define
  acl_$super_count;                                  { +0xB78, zero }

var
  acl_$locksmith_override: boolean;                  { +0xBF8, zero }

{ The overlay section ACL_$DATA (above), in the order of its offsets. }
var (acl_$data)
  acl_$acl_cache: array[0..30] of acl_$cache_slot_t;           { +0x0000 }
  acl_$original_sids: array[1..64] of acl_sid_block_t;         { +0x7C00 }
  acl_$current_sids: array[1..64] of acl_sid_block_t;          { +0x8500 }
  acl_$saved_sids: array[1..64] of acl_sid_block_t;            { +0x8E00 }
  acl_$saved_proj: array[1..64] of acl_proj_list_t;            { +0x9700 }
  acl_$proj_lists: array[1..64] of acl_proj_list_t;            { +0x9A00 }
  acl_$asid_free_bitmap: packed array[1..64] of boolean;       { +0x9D00 }
  acl_$proj_uids: array[1..64] of acl_$proj_uids_t;            { +0x9D08 }
  acl_$subsys_level: array[1..64] of integer;                  { +0xAD08 }
  acl_$locksmith_override_bitmap: packed array[1..64] of boolean;
                                                               { +0xAD88 }
  acl_$asid_suser_bitmap: packed array[1..64] of boolean;      { +0xAD90 }

{ The first object of FILE's overlay section FILE_$LOT_DATA, the lock
  object table, 1792 entries of 0x1C bytes: ACL_$INIT bounds the zeroing
  of ACL_$DATA by its address (acl/init.pas, see the TODO(pascal)
  there). }
var (file_$lot_data)
  file_$lock_entries: array[1..50176] of char;                { FILE_$LOT_DATA +0 }

var
  { ACL_$EXCLUSION_LOCK, the ACL_WIRED module's (acl/acl_wired.pas):
    declared here, not in acl/acl.ins.pas, so that the insert file needs
    no ml/ml.ins.pas (fim/fim.pas and pacct/pacct.pas include it
    without). }
  acl_$exclusion_lock: extern ml_$exclusion_t;

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order.  The ones whose fragments are not written yet join the list
  with them (acl/README.md). }
define
  acl_$init;
  acl_$min_rights;
  acl_$rights;
  acl_$check_rights;
  acl_$rights_check;
  acl_$enter_subs;
  acl_$enter_super;
  acl_$exit_super;
  acl_$clear_super;
  acl_$up;
  acl_$down;
  acl_$in_subsys;
  acl_$set_acl_check;
  acl_$default_acl;
  acl_$def_acldata;
  acl_$prim_create;
  acl_$image;
  acl_$is_suser;
  acl_$add_proj;
  acl_$delete_proj;
  acl_$get_proj_list;
  acl_$set_proj_list;
  acl_$set_re_all_sids;
  acl_$set_res_all_sids;
  acl_$get_re_all_sids;
  acl_$get_res_all_sids;
  acl_$get_re_sids;
  acl_$get_res_sids;
  acl_$get_exsid;
  acl_$get_pid_sid;
  acl_$check_fault_rights;
  acl_$check_debug_rights;
  acl_$set_def_acl_check;
  acl_$convert_to_9acl;
  acl_$convert_to_10acl;
  acl_$convert_from_9acl;
  acl_$convert_funky_acl;
  acl_$inherit_subsys;
  acl_$set_local_locksmith;
  acl_$get_local_locksmith;
  acl_$override_local_locksmith;
  acl_$used_suser;
  acl_$copy;
  acl_$server;
  acl_$alloc_asid;
  acl_$get_sid;
  acl_$free_asid;

{ Every module-local routine's body precedes its callers in image
  order, so no forward headings are needed. }

{ ---- OS_INIT_PROC ---- }
%include 'acl/init.pas';                    { ACL_$INIT }

{ ---- .TEXT ---- }
%include 'acl/cache_list_insert.pas';       { acl_$cache_list_insert }
%include 'acl/cache_list_remove.pas';       { acl_$cache_list_remove }
%include 'acl/sids_allowed.pas';            { acl_$sids_allowed }
%include 'acl/convert_rights.pas';          { acl_$convert_rights }
%include 'acl/convert_image.pas';           { acl_$convert_image }
%include 'acl/prim_create_internal.pas';    { acl_$prim_create_internal, its four nested
                                              routines }
%include 'acl/alloc_cache_slot.pas';        { acl_$alloc_cache_slot }
%include 'acl/expand_default_acl.pas';      { acl_$expand_default_acl }
%include 'acl/load_acl_image.pas';          { acl_$load_acl_image }
%include 'acl/find_acl_slot.pas';           { acl_$find_acl_slot }
%include 'acl/get_obj_acl_attrs.pas';       { acl_$get_obj_acl_attrs }
%include 'acl/eval_acl_entries.pas';        { acl_$eval_acl_entries }
%include 'acl/check_suser_pid.pas';         { acl_$check_suser_pid }
%include 'acl/is_process_type_2.pas';       { acl_$is_process_type_2 }
%include 'acl/eval_rights.pas';             { acl_$eval_rights }
%include 'acl/min_rights.pas';              { ACL_$MIN_RIGHTS }
%include 'acl/rights.pas';                  { ACL_$RIGHTS }
%include 'acl/check_rights.pas';            { ACL_$CHECK_RIGHTS }
%include 'acl/rights_check.pas';            { ACL_$RIGHTS_CHECK }
%include 'acl/setids.pas';                  { acl_$setids }
%include 'acl/enter_subs.pas';              { ACL_$ENTER_SUBS }
%include 'acl/enter_super.pas';             { ACL_$ENTER_SUPER }
%include 'acl/exit_super.pas';              { ACL_$EXIT_SUPER }
%include 'acl/clear_super.pas';             { ACL_$CLEAR_SUPER }
%include 'acl/up.pas';                      { ACL_$UP }
%include 'acl/down.pas';                    { ACL_$DOWN }
%include 'acl/in_subsys.pas';               { ACL_$IN_SUBSYS }
%include 'acl/set_acl_check.pas';           { ACL_$SET_ACL_CHECK }
%include 'acl/default_acl.pas';             { ACL_$DEFAULT_ACL }
%include 'acl/def_acldata.pas';             { ACL_$DEF_ACLDATA }
%include 'acl/prim_create.pas';             { ACL_$PRIM_CREATE }
%include 'acl/image_internal.pas';          { acl_$image_internal }
%include 'acl/image.pas';                   { ACL_$IMAGE }
%include 'acl/is_suser.pas';                { ACL_$IS_SUSER }
%include 'acl/add_proj.pas';                { ACL_$ADD_PROJ }
%include 'acl/delete_proj.pas';             { ACL_$DELETE_PROJ }
%include 'acl/get_proj_list.pas';           { ACL_$GET_PROJ_LIST }
%include 'acl/set_proj_list.pas';           { ACL_$SET_PROJ_LIST }
%include 'acl/set_re_all_sids.pas';         { ACL_$SET_RE_ALL_SIDS }
%include 'acl/set_res_all_sids.pas';        { ACL_$SET_RES_ALL_SIDS }
%include 'acl/get_re_all_sids.pas';         { ACL_$GET_RE_ALL_SIDS }
%include 'acl/get_res_all_sids.pas';        { ACL_$GET_RES_ALL_SIDS }
%include 'acl/get_re_sids.pas';             { ACL_$GET_RE_SIDS }
%include 'acl/get_res_sids.pas';            { ACL_$GET_RES_SIDS }
%include 'acl/get_exsid.pas';               { ACL_$GET_EXSID }
%include 'acl/get_pid_sid.pas';             { ACL_$GET_PID_SID }
%include 'acl/check_fault_rights.pas';      { ACL_$CHECK_FAULT_RIGHTS }
%include 'acl/check_debug_rights.pas';      { ACL_$CHECK_DEBUG_RIGHTS }
%include 'acl/set_def_acl_check.pas';       { ACL_$SET_DEF_ACL_CHECK }
%include 'acl/convert_to_9acl.pas';         { ACL_$CONVERT_TO_9ACL }
%include 'acl/convert_to_10acl.pas';        { ACL_$CONVERT_TO_10ACL }
%include 'acl/convert_from_9acl.pas';       { ACL_$CONVERT_FROM_9ACL }
%include 'acl/convert_funky_acl.pas';       { ACL_$CONVERT_FUNKY_ACL }
%include 'acl/inherit_subsys.pas';          { ACL_$INHERIT_SUBSYS }
%include 'acl/set_local_locksmith.pas';     { ACL_$SET_LOCAL_LOCKSMITH }
%include 'acl/get_local_locksmith.pas';     { ACL_$GET_LOCAL_LOCKSMITH }
%include 'acl/override_local_locksmith.pas'; { ACL_$OVERRIDE_LOCAL_LOCKSMITH }
%include 'acl/used_suser.pas';              { ACL_$USED_SUSER }
%include 'acl/copy.pas';                    { ACL_$COPY }
%include 'acl/server.pas';                  { ACL_$SERVER }

{ ---- PROC2_CREATE_PRO ---- }
%include 'acl/alloc_asid.pas';              { ACL_$ALLOC_ASID }

{ ---- PROC2_DELETE_PRO ---- }
%include 'acl/get_sid.pas';                 { ACL_$GET_SID }
%include 'acl/free_asid.pas';               { ACL_$FREE_ASID }
