{ dir/old_dir.pas - the OLD_DIR module, directories in the old (pre-SR10)
  format: their hashed entry blocks, the per-process directory locks,
  and the DIR_$OLD_* entry points DIR's routines fall back on.

  Image addresses:
    sau2  0x00E3503C  OLD_DIR data (OS_INIT_DATA, 0x4 bytes)
    sau2  0x00E7FD24  OLD_DIR data (.DATA, 0x4C0 bytes)

  One compilation unit: the map's OLD_DIR code segments in OS_INIT_PROC
  (DIR_$OLD_INIT, headed `[section(os_init_proc, os_init_data)]') and in
  .TEXT (MAP_CASE .. DIR_$OLD_VALIDATE_ROOT_ENTRY), and its data
  segments in OS_INIT_DATA (4 bytes, zero) and .DATA (1216 bytes).

  The .DATA block, zero but the two sets, in its order:
    +0x000  name_$leaf_char_set         a set of char, 32 bytes
    +0x020  name_$leaf_first_char_set   a set of char, 32 bytes
    +0x040  name_$lock_slot             64 * 4 bytes, from pid 1

    +0x140  name_$lock_mode             64 * 2 bytes
    +0x1C0  name_$lock_handle           64 * 4 bytes
    +0x2C0  name_$lock_uid              64 * 8 bytes

  The fragments are dir/<name>.pas, name/<name>.pas for the name_
  family (name/README.md), and file/map_case.pas and
  file/unmap_case.pas, included below in image order.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/dir/old_dir.pas.  Check: tools/pascal_check.sh.
}
module old_dir;

{ TODO(pascal) the 4-byte OS_INIT_DATA block and the A5 load into it

  The map's 4-byte OLD_DIR segment in OS_INIT_DATA is zero, no object
  of the source that this module can name; DIR_$OLD_INIT loads A5 with
  its end and never uses it (dir/dir.pas's TODO, the same open
  point). }

{ TODO(pascal) the two char sets: OLD_DIR's variables or an insert file's

  The block begins with name_$leaf_char_set and name_$leaf_first_char_set
  (+0x00, +0x20), which only name_$validate_leaf reads.  They are not
  its statics: those would follow the module's variables (the lock
  tables after them), as DIR's statics follow DIR's (dir/dir.pas).
  NAMEU's .DATA block (0x40 bytes) is the same 64 bytes and nothing
  else, and nothing in NAMEU addresses it (name/nameu.pas's TODO): the
  sets come first in both blocks, which an insert file's initialized
  `var' declarations, included by both units before their own
  declarations, would give.  So they are most likely an insert file's
  (which one, and the original names, the image does not say).  Here
  they stay module variables in that place; if the insert file is
  written, both units include it and drop their own copies. }

{ TODO(pascal) OLD_DIR's frames against their locals

  As DIR's (dir/dir.pas) and FILE_'s: the frames hold bytes no declared
  object explains, fitting the register-held locals' slots under the
  8-byte alignment of frame objects.  The routines with such bytes:
  name_$validate_leaf, dir_$old_init_buf, dir_$old_create_obj,
  name_$unlock_dir, name_$lock_dir. }

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'uid/uid.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'mst/mst.ins.pas';
%include 'cal/cal.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'acl/acl.ins.pas';
%include 'audit/audit.ins.pas';
%include 'os/os.ins.pas';
%include 'name/name.ins.pas';
%include 'rem_name/rem_name.ins.pas';
%include 'hint/hint.ins.pas';
%include 'dir/dir.ins.pas';
%include 'rem_file/rem_file.ins.pas';

type
  { The old-format directory as the OLD_DIR routines map it: a
    0x400-byte page 0 (the header, 18 slots kept in the page, the
    information block and the hash-chain heads), then the 0x96-byte
    overflow blocks, numbered from 1.  The layout:
    - the header's first ten bytes are one object: dir_$old_init_buf
      copies them in one piece from a 10-byte constant (1, 16#2B, 16#12,
      16#1AD, 3);
    - the slots kept in the page are slots[1..18] from +0x1A, 0x30
      apart: dir_$old_init_buf clears each one's +0x27 in an 18-pass
      loop; 18 * 0x30 from 0x1A ends at 0x37A, the information block's
      first byte;
    - the hash heads are hash[0..42] at +0x3AA, to the page's end 0x400;
    - block k is at +0x400 + 0x96 * (k - 1); the header's max_blocks
      (16#1AD = 429) bounds them: 0x400 + 429 * 0x96 = 0xFF5E, inside
      the 0x10000 bytes NAME_$LOCK_DIR maps. }
  { buckets, max_blocks and block_slots are pinteger: the image divides
    by buckets unsigned (dir_$old_reclaim_block), counts the overflow
    blocks against max_blocks unsigned (dir_$old_alloc_block,
    dir_$old_find_overflow_slot) and a block's used count against
    block_slots unsigned, and the `for' loops bounded by block_slots
    test for zero trips. }
  dir_$old_hdr_t = record
    version: pinteger;                    { 0x00: 1 (pinteger:
                                            DIR_$OLD_FIX_DIR compares it
                                            unsigned; the others store 1
                                            or test = 1) }
    buckets: pinteger;                    { 0x02: 16#2B }
    inline_slots: pinteger;               { 0x04: 16#12 }
    max_blocks: pinteger;                 { 0x06: 16#1AD }
    block_slots: pinteger;                { 0x08: 3 }
  end;
  { An entry slot's flags word as a set: member 15, the word's sign bit
    (0x80 in its first byte), keeps the slot from eviction; the image
    tests it on the word (dir_$old_reclaim_block,
    dir_$old_find_overflow_slot) and removes it on the byte
    (member 15 in the word's first byte). }
  dir_$old_slot_flags_t = set of 0..15;
  { One entry slot, 0x30 bytes (the bytes at +0x24 its flags word). }
  dir_$old_slot_t = record
    name: array[1..32] of char;           { 0x00 }
    extra: integer32;                     { 0x20 }
    flags: dir_$old_slot_flags_t;         { 0x24 (a set) }
    name_len: dir_$byte_t;                { 0x26 }
    slot_type: dir_$byte_t;               { 0x27: 1 = in use }
    uid: uid_$t;                          { 0x28 }
  end;
  { One overflow block, 0x96 bytes. }
  dir_$old_block_t = record
    next: integer;                        { 0x00 (dir + 0x96 * k + 0x36A) }
    prev: integer;                        { 0x02 }
    used: dir_$byte_t;                    { 0x04 }
    block_type: dir_$byte_t;              { 0x05: 0 free, 1 entries, 3 text }
    case integer of
      1: (slots: array[1..3] of dir_$old_slot_t);
                                          { 0x06 }
      2: (text: array[1..144] of char);   { 0x06 }
  end;
  dir_$old_dir_t = record
    hdr: dir_$old_hdr_t;                  { 0x000 }
    blocks_used: pinteger;                { 0x00A (compared unsigned
                                            with max_blocks) }
    free_block: pinteger;                 { 0x00C (an index scaled by
                                            an unsigned multiply) }
    parent_uid: uid_$t;                   { 0x00E }
    entries_used: pinteger;               { 0x016 (pinteger: widened
                                            with zeros and compared
                                            unsigned with a linteger
                                            count) }
    max_entries: pinteger;                { 0x018 (the same; every
                                            other user tests, assigns
                                            or adds 1) }
    slots: array[1..18] of dir_$old_slot_t;
                                          { 0x01A }
    initialized: dir_$byte_t;             { 0x37A: 1 }
    unused_37b: char;                     { 0x37B }
    info_write_len: integer;              { 0x37C }
    info_read_len: integer;               { 0x37E }
    unused_380: integer;                  { 0x380 }
    case integer of
      1: (info: array[1..40] of char;     { 0x382 }
          hash: array[0..42] of integer;  { 0x3AA }
          blocks: array[1..429] of dir_$old_block_t);
                                          { 0x400 }
      2: (dir_acl: uid_$t;                { 0x382 }
          file_acl: uid_$t);              { 0x38A }
  end;
  dir_$old_dir_ptr_t = ^dir_$old_dir_t;
  { A pointer to one entry slot: dir_$old_find_entry hands back the
    found slot's address. }
  dir_$old_slot_ptr_t = ^dir_$old_slot_t;
  { A soft link's reference, the 8 bytes a type-3 slot holds in its UID
    field: the text's length and the one or two type-3 blocks that hold
    it, then a zero word.  dir_$old_add_link_entry builds it in its
    frame and passes it as the slot's UID (the third view);
    dir_$old_delete_entry copies a slot's UID out into one and reads its
    two blocks; dir_$old_read_link_data walks the words after the length
    as an array (the second view, its third element the zero word).  The
    lengths and block numbers are pinteger: zero-extended, compared
    unsigned in dir_$old_add_link_entry, scaled by an unsigned
    multiply. }
  dir_$old_link_refs_t = record
    case integer of
      1: (text_len: pinteger;             { 0x00 }
          block1: pinteger;               { 0x02 }
          block2: pinteger;               { 0x04 }
          reserved_06: integer);          { 0x06 }
      2: (unused_00: pinteger;            { 0x00 }
          blocks: array[1..3] of pinteger);
                                          { 0x02 }
      3: (uid: uid_$t);                   { 0x00 }
  end;

  { An object location record (file/file.ins.pas file_$obj_loc_t) with
    its +0x1C byte, the flag word's high byte (members 8..15), as a
    number: DIR_$OLD_SET_DEFAULT_ACL keeps the directory's and compares
    the ACL object's with it, a byte field read zero-extended, which no
    member test of the set gives. }
  dir_$old_loc_view_t = record
    case integer of
      1: (loc: file_$obj_loc_t);          { 0x00 }
      2: (unused_00: array[1..28] of char;
                                          { 0x00 }
          byte_1c: dir_$byte_t);          { 0x1C }
  end;
  { An old-format entry as name_$old_get_root_entry fills it,
    dir/dir.ins.pas dir_$old_entry_t's 14 bytes with its UID and extra
    longword also one 12-character array: the routine copies them from
    the naming server's entry one byte at a time, the copy of an array
    of rem_name/rem_name.ins.pas's type rem_name_$entry_data_t (the same
    12 bytes of REM_NAME's entry, copied the same way there).  A dpc
    probe confirmed uid +0x02, extra +0x0A, data +0x02, size 0x0E.  The
    names are dir_$old_entry_t's and rem_name_$dir_entry_t's. }
  dir_$old_entry_view_t = record
    entry_type: integer;                  { 0x00 }
    case integer of
      1: (uid: uid_$t;                    { 0x02 }
          extra: integer32);              { 0x0A }
      2: (data: rem_name_$entry_data_t);  { 0x02 }
  end;

{ The module's own variables, in the order of the block (above). }
var
  name_$leaf_char_set: set of char :=
    ['!'..'.', '0'..'[', ']'..'~'];                  { +0x000 }
  name_$leaf_first_char_set: set of char :=
    ['!'..'-', '0'..'_', 'a'..'}'];                    { +0x020 }
  name_$lock_slot: array[1..64] of integer32;        { +0x040, zero }
  name_$lock_mode: array[1..64] of integer;          { +0x140, zero }
  name_$lock_handle: array[1..64] of integer32;      { +0x1C0, zero }
  name_$lock_uid: array[1..64] of uid_$t;            { +0x2C0, zero }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  dir_$old_init;
  map_case;
  unmap_case;
  dir_$old_cleanup;
  dir_$old_find_uid;
  dir_$old_find_net;
  dir_$old_set_dad;
  dir_$old_fix_dir;
  dir_$old_read_infoblk;
  dir_$old_write_infoblk;
  dir_$old_set_default_acl;
  dir_$old_get_default_acl;
  dir_$old_addu;
  dir_$old_add_hard_linku;
  dir_$old_root_addu;
  dir_$old_dropu;
  dir_$old_drop_hard_linku;
  dir_$old_add_baku;
  dir_$old_delete_fileu;
  dir_$old_create_diru;
  dir_$old_drop_diru;
  dir_$old_cnameu;
  dir_$old_add_linku;
  dir_$old_read_linku;
  dir_$old_drop_linku;
  dir_$old_dir_readu;
  dir_$old_get_entryu;
  dir_$old_validate_root_entry;

{ dir_$old_delete_entry, forward: dir_$old_reclaim_block and
  dir_$old_find_overflow_slot, before it, call it with the directory
  pointer's value and three words by value; the result is not read.
  All three words are pinteger: the slot index and the chain level are
  widened with zeros as indexes, and hash is passed on to
  dir_$old_free_slot's pinteger.  `internal'. }
{ body: dir/old_delete_entry.pas }
procedure dir_$old_delete_entry(dir: dir_$old_dir_ptr_t; slot_idx: pinteger;
                                chain_level: pinteger; hash: pinteger);
  forward; internal;

{ name_$old_add_entry, forward: DIR_$OLD_FIND_UID and DIR_$OLD_FIND_NET,
  before it, call it with a UID's address, a word, an address, a word, a
  UID's address, a longword and the status's address.  The modes, from
  the body (name/old_add_entry.pas): rights is passed on only as
  name_$lock_dir's pinteger rights (as name_$old_add_link_local passes
  its own); name is passed on as name_$validate_leaf's `in univ' name,
  name_len as its pinteger length; dir_uid and file_uid are passed on
  as `in' values; the status is written first or passed on to
  name_$lock_dir's `out': `out'.  `internal'. }
{ body: name/old_add_entry.pas }
procedure name_$old_add_entry(in dir_uid: uid_$t; rights: pinteger;
                              in name: univ name_$long_name_t;
                              name_len: pinteger; in file_uid: uid_$t;
                              flags: integer32; out status_ret: status_$t);
  forward; internal;

{ name_$old_delete_entryu (no map symbol), forward: DIR_$OLD_DROPU and
  DIR_$OLD_DROP_HARD_LINKU, before it, call it with two addresses, a
  word, three booleans by value in word slots and two addresses.
  dir_uid and name are passed on to DIR_$OLD_GET_ENTRYU's `in' formals,
  name_len's own slot to its `in' pinteger (pinteger), the status to its
  `out' status (dir/old_get_entryu.pas): `out'; the UID is passed on
  only to name_$old_drop_entry's `out' uid_ret: `out'.  Confirmed
  against the body and all four callers (name/old_delete_entryu.pas).
  `internal'. }
{ body: name/old_delete_entryu.pas }
procedure name_$old_delete_entryu(in dir_uid: uid_$t;
                                  in name: univ name_$long_name_t;
                                  name_len: pinteger;
                                  check_del_right: boolean;
                                  no_lock: boolean; allow_link: boolean;
                                  out uid_ret: uid_$t;
                                  out status_ret: status_$t);
  forward; internal;

{  FILE_$SET_PROT's heading is in acl/acl.ins.pas. }

{  REM_FILE_$NAME_GET_ENTRYU's heading is in rem_file/rem_file.ins.pas:
  its entry is that file's rem_file_$name_get_entryu_result_t, `out
  univ', which name_$old_get_entry_nonroot passes its dir_$old_entry_t
  to. }

{ ---- OS_INIT_PROC ---- }
%include 'dir/old_init.pas';                 { DIR_$OLD_INIT }

{ ---- .TEXT ---- }
%include 'file/map_case.pas';                { MAP_CASE }
%include 'file/unmap_case.pas';              { UNMAP_CASE }
%include 'name/validate_leaf.pas';           { name_$validate_leaf }
%include 'dir/old_init_buf.pas';             { dir_$old_init_buf }
%include 'dir/old_create_obj.pas';           { dir_$old_create_obj }
%include 'name/unlock_dir.pas';              { name_$unlock_dir }
%include 'name/lock_dir.pas';                { name_$lock_dir }
%include 'dir/old_cleanup.pas';              { DIR_$OLD_CLEANUP }
%include 'dir/old_hash_name.pas';            { dir_$old_hash_name }
%include 'dir/old_find_entry.pas';           { dir_$old_find_entry }
%include 'dir/old_chain_push.pas';           { dir_$old_chain_push }
%include 'dir/old_chain_unlink.pas';         { dir_$old_chain_unlink }
%include 'dir/old_find_free_inline_slot.pas';
                                             { dir_$old_find_free_inline_
                                               slot }
%include 'dir/old_alloc_block.pas';          { dir_$old_alloc_block }
%include 'dir/old_reclaim_block.pas';        { dir_$old_reclaim_block }
%include 'dir/old_find_overflow_slot.pas';   { dir_$old_find_overflow_slot }
%include 'dir/old_free_slot.pas';            { dir_$old_free_slot }
%include 'dir/old_add_entry.pas';            { dir_$old_add_entry }
%include 'dir/old_add_entry_ext.pas';        { dir_$old_add_entry_ext }
%include 'dir/old_add_link_entry.pas';       { dir_$old_add_link_entry }
%include 'dir/old_delete_entry.pas';         { dir_$old_delete_entry }
%include 'dir/old_unlink_entry.pas';         { dir_$old_unlink_entry }
%include 'dir/old_read_link_data.pas';       { dir_$old_read_link_data }
%include 'dir/old_find_uid_slot.pas';        { dir_$old_find_uid_slot }
%include 'dir/old_find_uid.pas';             { DIR_$OLD_FIND_UID }
%include 'dir/old_find_node_slot.pas';       { dir_$old_find_node_slot }
%include 'dir/old_find_net.pas';             { DIR_$OLD_FIND_NET }
%include 'dir/old_set_dad.pas';              { DIR_$OLD_SET_DAD }
%include 'dir/old_fix_dir.pas';              { DIR_$OLD_FIX_DIR }
%include 'dir/old_read_infoblk.pas';         { DIR_$OLD_READ_INFOBLK }
%include 'dir/old_write_infoblk.pas';        { DIR_$OLD_WRITE_INFOBLK }
%include 'dir/old_set_default_acl.pas';      { DIR_$OLD_SET_DEFAULT_ACL }
%include 'dir/old_get_default_acl.pas';      { DIR_$OLD_GET_DEFAULT_ACL }
%include 'name/old_add_link_local.pas';      { name_$old_add_link_local }
%include 'name/old_add_entry.pas';           { name_$old_add_entry }
%include 'name/old_add_link.pas';            { name_$old_add_link }
%include 'dir/old_addu.pas';                 { DIR_$OLD_ADDU }
%include 'dir/old_add_hard_linku.pas';       { DIR_$OLD_ADD_HARD_LINKU }
%include 'dir/old_root_addu.pas';            { DIR_$OLD_ROOT_ADDU }
%include 'name/old_drop_entry.pas';          { name_$old_drop_entry }
%include 'dir/old_dropu.pas';                { DIR_$OLD_DROPU }
%include 'dir/old_drop_hard_linku.pas';      { DIR_$OLD_DROP_HARD_LINKU }
%include 'name/old_delete_entryu.pas';       { name_$old_delete_entryu }
%include 'dir/old_add_baku.pas';             { DIR_$OLD_ADD_BAKU }
%include 'dir/old_delete_fileu.pas';         { DIR_$OLD_DELETE_FILEU }
%include 'dir/old_create_diru.pas';          { DIR_$OLD_CREATE_DIRU }
%include 'dir/old_drop_diru.pas';            { DIR_$OLD_DROP_DIRU }
%include 'dir/old_cnameu.pas';               { DIR_$OLD_CNAMEU }
%include 'dir/old_add_linku.pas';            { DIR_$OLD_ADD_LINKU }
%include 'dir/old_read_linku.pas';           { DIR_$OLD_READ_LINKU }
%include 'dir/old_drop_linku.pas';           { DIR_$OLD_DROP_LINKU }
%include 'dir/old_read_entries.pas';         { dir_$old_read_entries }
%include 'dir/old_dir_readu.pas';            { DIR_$OLD_DIR_READU }
%include 'name/old_get_entry_nonroot.pas';   { name_$old_get_entry_nonroot }
%include 'name/old_get_root_entry.pas';      { name_$old_get_root_entry }
%include 'dir/old_get_entryu.pas';           { DIR_$OLD_GET_ENTRYU }
%include 'dir/old_validate_root_entry.pas';  { DIR_$OLD_VALIDATE_ROOT_ENTRY }
