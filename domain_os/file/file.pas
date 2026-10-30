{ file/file.pas - the FILE_ module, file objects and their locks.

  Image addresses:
    sau2  0x00E35150  FILE_ data (OS_INIT_DATA, 4 bytes)
    sau2  0x00E82128  FILE_ data (.DATA, 0x2D4 bytes)
    sau2  0x00E86058  FILE_ data (PROC2_CREATE_DAT, 4 bytes)
    sau2  0x00E86064  FILE_ data (PROC2_DELETE_DAT, 4 bytes)
    sau2  0x00E935CC  FILE_$LOT_DATA (overlay, 0x1086C bytes)

  One compilation unit: the map's FILE_ code segments in OS_INIT_PROC
  (0xF0 bytes, FILE_$LOCK_INIT), .TEXT (0x3F88 bytes, OS_PROC_SHUTWIRED
  .. FILE_$UNLOCK_PROC), PROC2_CREATE_PRO (0x408 bytes, FILE_$SET_LEN ..
  FILE_$RESERVE) and PROC2_DELETE_PRO (0xB8 bytes, FILE_$UNLOCK_ALL,
  FILE_$INVALIDATE), its four data segments, and the overlay
  FILE_$LOT_DATA (ref 3.14 p. 3-52; 7.2.4, Method 4).

  The FILE_WIRED segment (FILE_$UID_LOCK_EC) is a module of its own,
  file/file_wired.pas.

  The heading names no section (acl/acl.pas's form); FILE_$LOCK_INIT is
  headed `[section(os_init_proc, os_init_data)]', the PROC2 routines
  `[section(proc2_create_pro, proc2_create_dat)]' and
  `[section(proc2_delete_pro, proc2_delete_dat)]'.  The three 4-byte
  blocks are zero (see the TODO(pascal) below).

  The .DATA block, 0x2D4 bytes:

    +0x000  file_$uid_lock_holders  17 * 1  the per-UID bucket locks'
                                            holders, a pid's low byte each
    +0x011  (1 byte: the next array's word alignment)
    +0x012  unused_012, a stand-in   6  never addressed (see the TODO)
    +0x018  file_$lock_conflict_table 8 * 2
    +0x028  file_$lock_compat_table 12 * 2

    +0x040  file_$lock_mode_map    12 * 2
    +0x058  file_$lock_mode_table  24 * 2
    +0x088  file_$lock_req_table   12 * 2
    +0x0A0  file_$lock_cvt_table   12 * 2
    +0x0B8  file_$base_uid           8      UID_$NIL with NODE_$ME in its
                                            low 20 bits

    +0x0C0  file_$generated_uid      8      FILE_$LOCK_INIT's UID_$GEN
    +0x0C8  FILE_$LOT_HASHTAB  251 * 2      defined (a map symbol)
    +0x2BE  unused_2be, a stand-in   2      never addressed (see the TODO)
    +0x2C0  file_$default_size       4
    +0x2C4  file_$lot_seqn           4      starts at 1

    +0x2C8  file_$lock_illegal_mask  2      a set of 0..15: [3, 5, 6, 7]
    +0x2CA  file_$lot_pending        2
    +0x2CC  file_$lot_high           2
    +0x2CE  FILE_$LOT_FREE           2      defined (a map symbol)
    +0x2D0  file_$lot_full           1      a boolean
    +0x2D1  (3 bytes: the block's rounding to 4)

  OS_DATA_SHUTWIRED (a map symbol at +0x000) is the start of the data
  OS_$SHUTDOWN wires; see the TODO(pascal) below.

  The overlay FILE_$LOT_DATA, 0x1086C bytes, zero:

    +0x00000  file_$lock_entries  1792 * 0x1C  the lock object table,
                                            from entry 1
    +0x0C400  file_$lock_table  58 * 150 * 2  each address space's lock
                                            list, from asid 0 and slot 1
    +0x107F8  file_$lock_table2  58 * 2     each address space's count

  The routines live in one fragment file per routine group
  (file/<name>.pas), included below in image order; OS_PROC_SHUTWIRED's
  is os/proc_shutwired.pas.  MAP_CASE and UNMAP_CASE are OLD_DIR's, not
  included here.

  Build: dpc -I domain_os domain_os/file/file.pas.  Check:
  tools/pascal_check.sh.
}
module file_;

{ TODO(pascal) the three 4-byte data blocks and the A5 loads into them

  The OS_INIT_DATA, PROC2_CREATE_DAT and PROC2_DELETE_DAT blocks, all
  zero, hold no object of the source that this module can name; the
  routines of those code sections load A5 with their ends and never use
  it.  The same open point as acl/acl.pas's and xpd/xpd.pas's
  (cause Uncertain).  Until it is settled the module
  declares nothing for them, and dpc loads no A5 there. }

{ TODO(pascal) the .DATA block's unaddressed bytes and OS_DATA_SHUTWIRED

  Two stand-ins hold bytes no instruction addresses: unused_012 (6 bytes,
  +0x012..+0x017, with the alignment byte +0x011 before it) and
  unused_2be (2 bytes, +0x2BE).  An 8-byte alignment of
  objects of 8 bytes or more from the block's start (0 mod 8 on SAU2; a
  lead) explains the first: every table from +0x18 to +0xC8 starts at a
  multiple of 8.  It explains the second only if file_$default_size and
  file_$lot_seqn were one 8-byte object.  The map's OS_DATA_SHUTWIRED at
  +0x000 is a symbol at this block's first byte: either the name of
  FILE_'s first variable (the UID locks' holders) or the empty data
  segment of a marker module placed before FILE_'s, as the end marks
  OS_PROC_SHUTWIRED_END and OS_DATA_SHUTWIRED_END are another module's; the
  image cannot tell. }

{ TODO(pascal) FILE_'s frames against their locals

  Counting a module-local's reserved slot, each register-held local's
  slot, one 4-byte slot per `with' (a lead) and the temporaries of
  expressions passed by address, many of FILE_'s frames are exact, but some
  hold bytes no object explains: FILE_$LOCK_INIT, FILE_$PRIV_CREATE,
  FILE_$DELETE_OBJ (the stand-ins unused_28 and unused_2c),
  FILE_$GET_ATTRIBUTES (unused_b8), file_$audit_set_prot, FILE_$SET_DTM_F,
  FILE_$SET_DTU_F, file_$check_same_volume, FILE_$FW_PARTIAL,
  FILE_$FW_PAGES, file_$audit_lock, file_$delete_int, FILE_$PRIV_LOCK and
  its nested routines, FILE_$PRIV_UNLOCK, FILE_$LOCAL_READ_LOCK,
  FILE_$LOCAL_LOCK_VERIFY, FILE_$READ_LOCK_ENTRYI, FILE_$PRIV_UNLOCK_ALL,
  FILE_$GET_SEG_MAP, FILE_$EXPORT_LK and FILE_$FORK_LOCK; and dpc places
  some value parameters' copies and 8-byte objects otherwise. }

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
%include 'file/file_prot.ins.pas';
%include 'audit/audit.ins.pas';
%include 'os/os.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'route/route.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'bat/bat.ins.pas';
%include 'name/name.ins.pas';
%include 'hint/hint.ins.pas';
%include 'volx/volx.ins.pas';
%include 'dir/dir.ins.pas';
%include 'rem_file/rem_file.ins.pas';

type
  { The last four bytes of a lock object table entry, one 32-bit packed
    record.  priv_lock_alloc_entry fills it with the packed fields'
    forms: refcount a byte cleared; read_only, remote and flag0 merged
    from computed booleans; loc_rights, side and mode merged unmasked;
    pending set.  refcount is read widened and compared unsigned with 1;
    rights is stored a byte.  A dpc probe gives each of these forms at
    the image's offsets.  The 8-bit fields are file_$byte_t: dpc refuses
    a plain 0..255 there.  Bit 6 of +0x19 is never
    addressed by FILE_: unused_22. }
  file_$lot_state_t = packed record
    refcount: file_$byte_t;               { +0x18 }
    read_only: boolean;                   { +0x19 bit 7 }
    unused_22: boolean;                   { +0x19 bit 6 }
    loc_rights: 0..63;                    { +0x19 bits 5..0 }
    rights: file_$byte_t;                 { +0x1A }
    side: 0..1;                           { +0x1B bit 7 }
    mode: 0..15;                          { +0x1B bits 6..3 }
    remote: boolean;                      { +0x1B bit 2 }
    pending: boolean;                     { +0x1B bit 1 }
    flag0: boolean;                       { +0x1B bit 0 }
  end;

  { The entry's +0x1B byte as a one-byte set (ref 3.15.5, a size
    attribute on a set): member k is bit k, so member
    1 is the packed view's pending, 2 remote, 0 flag0, 3..6 mode and 7
    side.  priv_lock_remote_lock passes the pending bit by value, formed
    between the pushes: `1 in entry.flags_set', the set membership's
    form; a field of the packed record may not be passed as an argument
    (ref 3.10.3, p. 3-21). }
  file_$lot_flags_t = [byte] set of 0..7;

  { One entry of the lock object table, 0x1C bytes.  node (+0x04, the
    node_low and node_high fields, file/file.ins.pas file_$lot_node_t)
    is one 8-byte record: FILE_$LOCAL_READ_LOCK copies it whole into its
    lock record's holder, the record assignment's form, where it stores the
    fields one by one elsewhere.  The four bytes at +0x18 are a variant:
    view 1 the packed record state, which every other site uses (the
    unmasked merges of side and mode, the booleans' bit tests and stores);
    view 2 the same bytes as three plain bytes and the set flags_set at
    +0x1B, which priv_lock_remote_lock's argument uses.  A dpc probe gives
    node at 0x04, uid at 0x0C, state and flags_set at 0x18, 0x1B, the
    image's forms, and the size 0x1C. }
  file_$lot_entry_t = record
    context: integer32;                   { 0x00 }
    node: file_$lot_node_t;               { 0x04: node_low, node_high }
    uid: uid_$t;                          { 0x0C }
    next: integer;                        { 0x14 }
    sequence: integer;                    { 0x16 }
    case integer of
      1: (state: file_$lot_state_t);      { 0x18 }
      2: (refcount_b: file_$byte_t;       { 0x18 }
          flags1_b: file_$byte_t;         { 0x19 }
          rights_b: file_$byte_t;         { 0x1A }
          flags_set: file_$lot_flags_t);  { 0x1B: member 1 pending }
  end;

  { A word set of lock modes: the conflict and conversion tables' rows
    (+0x018, +0x0A0), tested with the mode as the bit number, the row
    held in a register: a set's member test. }
  file_$lock_mode_set_t = set of 0..15;

  { The location record's flags word at +0x1C as FILE_$PRIV_LOCK uses
    it, a 16-bit packed record: its first byte read whole and merged
    unmasked into the lock entry's loc_rights; bit 7 of the second (the
    remote bit) tested, set, cleared, and merged from a computed
    boolean, the packed field's store (a set member would be stored by
    branches); bit 6 (scratch) cleared.  The other routines' view,
    file/file.ins.pas file_$obj_loc_t's `flags: set of 0..15' (members
    7 and 6 the same bits), gives the same clear and test; this view is
    FILE_$PRIV_LOCK's own (its local's variant, below). }
  file_$loc_bits_t = packed record
    rights_bits: file_$byte_t;            { +0x1C }
    remote: boolean;                      { +0x1D bit 7 }
    scratch: boolean;                     { +0x1D bit 6 }
    unused_0: 0..63;                      { +0x1D bits 5..0 }
  end;

  { FILE_$PRIV_LOCK's location record in three views: the record
    (file/file.ins.pas file_$obj_loc_t) for the AST_ and REM_FILE_
    calls; its words at +0x10 as a hint (hint/hint.ins.pas
    hint_$addr_t: loc_info and node), copied whole to and from the hint
    vector and passed to HINT_$ADDI, its node to HINT_$LOOKUP_CACHE; and
    the flags word as file_$loc_bits_t.  A probe gives hint 0x10, bits
    0x1C, size 0x20. }
  file_$lock_desc_t = record
    case integer of
      1: (loc: file_$obj_loc_t);          { 0x00 }
      2: (unused_00: array[16#00..16#0F] of char;  { 0x00 }
          hint: hint_$addr_t;             { 0x10 }
          unused_18: integer32;           { 0x18 }
          bits: file_$loc_bits_t;         { 0x1C }
          unused_1e: integer);            { 0x1E }
  end;

  { FILE_$PRIV_LOCK's attribute record (0x90 bytes, AST_$GET_ATTRIBUTES'
    output) in two views: the record (file/file.ins.pas
    file_$attributes_t) for the calls, and the fields it reads: the
    first byte widened and tested; the object's type byte; the volume's
    flags word (also through the static link in priv_lock_alloc_entry);
    the 6-byte time at +0x2C passed to AST_$COND_FLUSH.  A probe gives
    obj_type 0x01, vol_flags 0x02, dtm 0x2C, size 0x90. }
  file_$lock_attrs_t = record
    case integer of
      1: (attrs: file_$attributes_t);     { 0x00 }
      2: (not_empty: file_$byte_t;        { 0x00 }
          obj_type: file_$byte_t;         { 0x01 }
          vol_flags: integer;             { 0x02 }
          unused_04: array[16#04..16#2B] of char;  { 0x04 }
          dtm: time_$clock_t);            { 0x2C }
  end;

  { The requester's SIDs, reached through the pointer FILE_$PRIV_LOCK's
    acl_ctx cell holds (acl/acl.ins.pas acl_$exsid_t,
    ACL_$RIGHTS_CHECK's `in acl_ctx'). }
  file_$exsid_ptr_t = ^acl_$exsid_t;

  { FILE_$PRIV_CREATE's size word: the size, with bit 27 set when the
    caller gave one: a packed boolean field set, bit 27 the first byte's bit
    3.  The other bits are not addressed alone. }
  file_$create_size_t = packed record
    case integer of
      1: (unused_31_28: 0..15;            { bits 31..28 }
          explicit: boolean);             { bit 27 }
      2: (all: integer32);
  end;

  { The word at +0x02 of FILE_$PRIV_CREATE's VTOCE image: the directory
    bit 12 stored from a computed boolean (vtoc/vtoc.ins.pas
    vtoce_$hdr_t's bit_12 form), and the parent's read-only bit 1 tested
    (vtoce_$hdr_t's read_only). }
  file_$vtoce_bits_t = packed record
    unused_15_13: 0..7;
    dir: boolean;                         { bit 12 }
    unused_11_2: 0..1023;
    read_only: boolean;                   { bit 1 }
    unused_0: boolean;
  end;

  { FILE_$PRIV_CREATE's view of the 0x90-byte VTOCE image it builds
    (every offset a store of the routine's; dtm, dtu and dtb clock
    records, each copied as a longword and a word; the owner bytes a
    character array, copied by bytes, rem_file/rem_file.ins.pas
    rem_file_$owner_info_t).  vtoc/vtoc.ins.pas vtoce_$t names the same
    bytes otherwise; this view is FILE_$PRIV_CREATE's own. }
  file_$new_vtoce_t = record
    flags1: file_$byte_t;                 { 0x00 }
    file_type: file_$byte_t;              { 0x01 }
    bits: file_$vtoce_bits_t;             { 0x02 }
    file_uid: uid_$t;                     { 0x04 }
    type_uid: uid_$t;                     { 0x0C }
    reserved_14: array[1..8] of char;     { 0x14 }
    dtm: time_$clock_t;                   { 0x1C }
    pad_22: integer;                      { 0x22 }
    dtu: time_$clock_t;                   { 0x24 }
    pad_2a: integer;                      { 0x2A }
    dta_high: time_$clockh_t;             { 0x2C }
    reserved_30: integer32;               { 0x30 }
    dtb: time_$clock_t;                   { 0x34 }
    pad_3a: integer;                      { 0x3A }
    parent_uid: uid_$t;                   { 0x3C }
    refcount: integer32;                  { 0x44 }
    acl_data: array[1..24] of char;       { 0x48 }
    initial_size: integer32;              { 0x60 }
    reserved_64: integer32;               { 0x64 }
    acl_ext: acl_proj_list_t;             { 0x68 }
    is_dir: integer;                      { 0x74 }
    reserved_76: array[1..18] of char;    { 0x76 }
    default_acl: uid_$t;                  { 0x88 }
  end;

  { FILE_$PRIV_CREATE's one 0x90-byte frame record with its lives: the
    parent's attributes from AST_$GET_ATTRIBUTES and
    REM_FILE_$CREATE_TYPE (file_$attributes_t), the VTOCE image for
    VTOC_$ALLOCATE (vtoce_$t) built through the view above, and 36
    longwords cleared by a `for' from 1 (the pointer one element on). }
  file_$create_obj_t = record
    case integer of
      1: (attrs: file_$attributes_t);
      2: (vtoce: vtoce_$t);
      3: (v: file_$new_vtoce_t);
      4: (longs: array[1..36] of integer32);
  end;

  { FILE_$ATTRIBUTES' and FILE_$ACT_ATTRIBUTES' 0x90-byte frame record:
    filled as an attribute record by AST_$GET_ATTRIBUTES and passed on
    as a VTOCE to VTOCE_$NEW_TO_OLD; FILE_$PRIV_CREATE's
    file_$create_obj_t's two first views. }
  file_$attr_buf_t = record
    case integer of
      1: (attrs: file_$attributes_t);
      2: (vtoce: vtoce_$t);
  end;

  { FILE_$PRIV_CREATE's two 0x20-byte location records, each passed as
    an object location (AST_$GET_ATTRIBUTES, REM_FILE_$CREATE_TYPE,
    AST_$LOAD_AOTE) and the second as VTOC_$ALLOCATE's request; the byte
    at +0x1C copied from one to the other: the request's volume index
    (vtoc_$req_tail_t's vol_idx), a byte of file_$obj_loc_t's flags set
    (members 8..15). }
  file_$create_loc_t = record
    case integer of
      1: (loc: file_$obj_loc_t);
      2: (req: vtoc_$lookup_req_t);
      3: (unused_00: array[1..28] of char;
          byte_1c: file_$byte_t);         { 0x1C }
  end;

  { The 0x3E-byte audit record file_$audit_set_prot builds in its frame
    and hands to AUDIT_$LOG_EVENT with its length: the protection record
    copied as 11 longwords, the file's UID at +0x2C, the second UID at
    +0x34, the protection kind's word at +0x3C.  A dpc probe gives these
    offsets and the size 0x3E. }
  file_$audit_set_prot_data_t = record
    acl_data: acl_$prot_data_t;           { 0x00 }
    file_uid: uid_$t;                     { 0x2C }
    prot_info: uid_$t;                    { 0x34 }
    prot_type: integer;                   { 0x3C }
  end;

  { The 10-byte audit record file_$audit_lock builds in its frame and
    hands to AUDIT_$LOG_EVENT with its length: the object's UID copied as
    two longwords at +0x0, the mode's word at +0x8.  A dpc probe gives
    the offsets and the size 0xA. }
  file_$audit_lock_data_t = record
    uid: uid_$t;                          { 0x0 }
    lock_mode: integer;                   { 0x8 }
  end;

  { The base UID: UID_$NIL with this node's ID in the low longword's
    20-bit node field (uid/uid.ins.pas's uid_$gen_low_t, the layout
    UID_$INIT stores the node into).  FILE_$LOCK_INIT stores the whole
    UID, then the node field in place. }
  file_$base_uid_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00..0x07 }
      2: (high: integer32;                { 0x00 }
          low: uid_$gen_low_t);           { 0x04 }
  end;

  { file_$uid_view_t is file/file.ins.pas's now, and
    file_$set_prot_rec_t file/file_prot.ins.pas's (included above),
    beside FILE_$SET_PROT_INT's heading. }


var
  { FILE_$UID_LOCK_EC, the FILE_WIRED module's (file/file_wired.pas):
    declared here, not in file/file.ins.pas, so that the insert file
    needs no ec/ec.ins.pas. }
  file_$uid_lock_ec: extern ec_$eventcount_t;

  { The block's two map symbols (defined below): declared here, not in
    file/file.ins.pas, as no other module names them. }
  file_$lot_hashtab: extern array[0..250] of integer;
  file_$lot_free: extern integer;

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
var
  file_$uid_lock_holders: array[0..16] of file_$byte_t;   { +0x000, zero }
  unused_012: array[1..6] of char;                        { +0x012, zero:
                                                            TODO }
  file_$lock_conflict_table: array[0..7] of file_$lock_mode_set_t :=
    [[0..6], [0..4, 6], [0, 1, 2, 6], [0, 1, 3, 4, 6], [0, 1, 3], [0],
     [0..3, 6], []];                                      { +0x018 }
  file_$lock_compat_table: array[0..11] of integer :=
    [0, 4, 6, 2, 6, 4, 2, 4, 2, 0, 1, 2];                 { +0x028 }
  file_$lock_mode_map: array[0..11] of integer :=
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 4];                 { +0x040 }
  file_$lock_mode_table: array[0..1] of array[0..11] of integer :=
    [[0, 3, 4, 5, 5, 3, 4, 4, 0, 0, 3, 5],
     [0, 1, 6, 2, 2, 1, 6, 6, 0, 0, 1, 2]];               { +0x058 }
  file_$lock_req_table: array[0..11] of pinteger :=
    [0, 1, 2, 4, 4, 1, 2, 2, 0, 0, 16#0A, 16#0B];         { +0x088 }
  file_$lock_cvt_table: array[0..11] of file_$lock_mode_set_t :=
    [[], [1, 2, 4, 10, 11], [1, 2, 4, 10, 11], [1, 2],
     [1, 2, 4, 10, 11], [4, 11], [1], [4, 11], [], [],
     [1, 2, 4, 10, 11], [1, 2, 4, 10, 11]];               { +0x0A0 }
  file_$base_uid: file_$base_uid_t;                       { +0x0B8, zero }
  file_$generated_uid: uid_$t;                            { +0x0C0, zero }

define
  file_$lot_hashtab;                                      { +0x0C8, zero }

var
  unused_2be: integer;                                    { +0x2BE, zero:
                                                            TODO }
  file_$default_size: integer32 := 16#1010100F;           { +0x2C0 }
  file_$lot_seqn: integer32 := 1;                         { +0x2C4 }
  file_$lock_illegal_mask: set of 0..15 := [3, 5, 6, 7];  { +0x2C8: a word set }
  file_$lot_pending: integer;                             { +0x2CA, zero }
  file_$lot_high: integer;                                { +0x2CC, zero }

define
  file_$lot_free;                                         { +0x2CE, zero }

var
  file_$lot_full: boolean;                                { +0x2D0, zero }

{ The overlay section FILE_$LOT_DATA (above), in the order of its
  offsets. }
var (file_$lot_data)
  file_$lock_entries: array[1..1792] of file_$lot_entry_t;    { +0x00000 }
  file_$lock_table: array[0..57] of array[1..150] of integer; { +0x0C400 }
  file_$lock_table2: array[0..57] of pinteger;                { +0x107F8 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  file_$lock_init;
  os_proc_shutwired;
  file_$check_prot;
  file_$set_attribute;
  file_$priv_create;
  file_$create;
  file_$create_it;
  file_$get_attr_info;
  file_$get_attributes;
  file_$attributes;
  file_$act_attributes;
  file_$delete_obj;
  file_$delete;
  file_$delete_force;
  file_$mk_permanent;
  file_$mk_temporary;
  file_$mk_immutable;
  file_$set_audited;
  file_$set_trouble;
  file_$set_mand_lock;
  file_$set_prot_int;
  file_$set_prot;
  file_$set_acl;
  file_$old_ap;
  file_$set_type;
  file_$set_dirptr;
  file_$set_dtm_f;
  file_$set_dtm;
  file_$set_dtu_f;
  file_$set_dtu;
  file_$set_devno;
  file_$set_mgr_attr;
  file_$set_refcnt;
  file_$neighbors;
  file_$purify;
  file_$fw_file;
  file_$fw_partial;
  file_$fw_pages;
  file_$lock_d;
  file_$change_lock_d;
  file_$lock;
  file_$priv_lock;
  file_$delete_when_unlocked;
  file_$delete_force_when_unlocked;
  file_$remove_when_unlocked;
  file_$unlock_d;
  file_$unlock;
  file_$priv_unlock;
  file_$import_lk;
  file_$read_lock_entryu;
  file_$read_lock_entryui;
  file_$local_read_lock;
  file_$locate;
  file_$locatei;
  file_$local_lock_verify;
  file_$read_lock_entry;
  file_$read_lock_entryi;
  file_$priv_unlock_all;
  file_$unlock_vol;
  file_$force_unlock;
  file_$unlock_proc;
  file_$set_len;
  file_$set_len_d;
  file_$truncate;
  file_$truncate_d;
  file_$get_seg_map;
  file_$export_lk;
  file_$fork_lock;
  file_$reserve;
  file_$unlock_all;
  file_$invalidate;

{ FILE_$LOCATEI, called by FILE_$READ_LOCK_ENTRYUI before its body.  Its
  heading is here, not in file/file.ins.pas: its location is
  hint/hint.ins.pas's hint_$addr_t, an insert included after
  file.ins.pas.  The default convention: the UID a value parameter; the
  location and the status written only: `out'.  An SVC entry too. }
procedure file_$locatei(file_uid: uid_$t; out location: hint_$addr_t;
                        out status_ret: status_$t); extern;

{ Module-local routines called before their bodies (each with its
  `body:' line). }

{ file_$delete_int: the UID's slot, the flags word and the result's
  slot (cleared first) and the status's; a boolean result, which
  FILE_$GET_ATTR_INFO tests.  result is passed on to AST_$TRUNCATE's
  `out result: boolean'. }
{ body: file/delete_int.pas }
function file_$delete_int(in file_uid: uid_$t; flags: integer;
                          out result: boolean;
                          out status_ret: status_$t): boolean;
  forward; internal;

{ file_$check_same_volume: the two UIDs value parameters; copy_location a
  boolean by value; the location (the 0x20-byte record copied into it) and
  the status written only: `out'.  A boolean result, which
  FILE_$SET_PROT_INT tests. }
{ body: file/check_same_volume.pas }
function file_$check_same_volume(file_uid1: uid_$t; file_uid2: uid_$t;
                                 copy_location: boolean;
                                 out location_out: file_$obj_loc_t;
                                 out status_ret: status_$t): boolean;
  forward; internal;

{ file_$verify_lock_holder: the lock record's slot read and passed on to
  `in' formals (FILE_$LOCAL_LOCK_VERIFY's request, REM_FILE_$LOCAL_VERIFY's
  lock_block, FILE_$PRIV_UNLOCK's file_uid): `in'; the status written
  only: `out'.  Callers: FILE_$READ_LOCK_ENTRYUI, FILE_$READ_LOCK_ENTRYI. }
{ body: file/verify_lock_holder.pas }
procedure file_$verify_lock_holder(in lock_info: file_$lock_info_t;
                                   out status_ret: status_$t);
  forward; internal;

{ ---- OS_INIT_PROC ---- }
%include 'file/lock_init.pas';              { FILE_$LOCK_INIT }

{ ---- .TEXT ---- }
%include 'os/proc_shutwired.pas';           { OS_PROC_SHUTWIRED (the os translation's fragment for this module) }
%include 'file/uid_lock_acquire.pas';       { file_$uid_lock_acquire }
%include 'file/uid_lock_release.pas';       { file_$uid_lock_release }
%include 'file/check_prot.pas';             { FILE_$CHECK_PROT }
%include 'file/set_attribute.pas';          { FILE_$SET_ATTRIBUTE }
%include 'file/priv_create.pas';            { FILE_$PRIV_CREATE }
%include 'file/create.pas';                 { FILE_$CREATE }
%include 'file/create_it.pas';              { FILE_$CREATE_IT }
%include 'file/get_attr_info.pas';          { FILE_$GET_ATTR_INFO }
%include 'file/get_attributes.pas';         { FILE_$GET_ATTRIBUTES }
%include 'file/attributes.pas';             { FILE_$ATTRIBUTES }
%include 'file/act_attributes.pas';         { FILE_$ACT_ATTRIBUTES }
%include 'file/delete_obj.pas';             { FILE_$DELETE_OBJ }
%include 'file/delete.pas';                 { FILE_$DELETE }
%include 'file/delete_force.pas';           { FILE_$DELETE_FORCE }
%include 'file/mk_permanent.pas';           { FILE_$MK_PERMANENT }
%include 'file/mk_temporary.pas';           { FILE_$MK_TEMPORARY }
%include 'file/mk_immutable.pas';           { FILE_$MK_IMMUTABLE }
%include 'file/set_audited.pas';            { FILE_$SET_AUDITED }
%include 'file/set_trouble.pas';            { FILE_$SET_TROUBLE }
%include 'file/set_mand_lock.pas';          { FILE_$SET_MAND_LOCK }
%include 'file/audit_set_prot.pas';         { file_$audit_set_prot }
%include 'file/set_prot_int.pas';           { FILE_$SET_PROT_INT }
%include 'file/set_prot.pas';               { FILE_$SET_PROT, its nested file_$get_default_prot }
%include 'file/set_acl.pas';                { FILE_$SET_ACL }
%include 'file/old_ap.pas';                 { FILE_$OLD_AP }
%include 'file/set_type.pas';               { FILE_$SET_TYPE }
%include 'file/set_dirptr.pas';             { FILE_$SET_DIRPTR }
%include 'file/set_dtm_f.pas';              { FILE_$SET_DTM_F }
%include 'file/set_dtm.pas';                { FILE_$SET_DTM }
%include 'file/set_dtu_f.pas';              { FILE_$SET_DTU_F }
%include 'file/set_dtu.pas';                { FILE_$SET_DTU }
%include 'file/set_devno.pas';              { FILE_$SET_DEVNO }
%include 'file/set_mgr_attr.pas';           { FILE_$SET_MGR_ATTR }
%include 'file/set_refcnt.pas';             { FILE_$SET_REFCNT }
%include 'file/check_same_volume.pas';      { file_$check_same_volume }
%include 'file/neighbors.pas';              { FILE_$NEIGHBORS }
%include 'file/purify.pas';                 { FILE_$PURIFY }
%include 'file/fw_file.pas';                { FILE_$FW_FILE }
%include 'file/fw_partial.pas';             { FILE_$FW_PARTIAL }
%include 'file/fw_pages.pas';               { FILE_$FW_PAGES }
%include 'file/audit_lock.pas';             { file_$audit_lock }
%include 'file/delete_int.pas';             { file_$delete_int }
%include 'file/lock_d.pas';                 { FILE_$LOCK_D }
%include 'file/change_lock_d.pas';          { FILE_$CHANGE_LOCK_D }
%include 'file/lock.pas';                   { FILE_$LOCK }
%include 'file/priv_lock.pas';              { FILE_$PRIV_LOCK, its six nested routines }
%include 'file/delete_when_unlocked.pas';   { FILE_$DELETE_WHEN_UNLOCKED }
%include 'file/delete_force_when_unlocked.pas'; { FILE_$DELETE_FORCE_WHEN_UNLOCKED }
%include 'file/remove_when_unlocked.pas';   { FILE_$REMOVE_WHEN_UNLOCKED }
%include 'file/unlock_d.pas';               { FILE_$UNLOCK_D }
%include 'file/unlock.pas';                 { FILE_$UNLOCK }
%include 'file/priv_unlock.pas';            { FILE_$PRIV_UNLOCK }
%include 'file/import_lk.pas';              { FILE_$IMPORT_LK }
%include 'file/read_lock_entryu.pas';       { FILE_$READ_LOCK_ENTRYU }
%include 'file/read_lock_entryui.pas';      { FILE_$READ_LOCK_ENTRYUI }
%include 'file/local_read_lock.pas';        { FILE_$LOCAL_READ_LOCK }
%include 'file/locate.pas';                 { FILE_$LOCATE }
%include 'file/locatei.pas';                { FILE_$LOCATEI }
%include 'file/verify_lock_holder.pas';     { file_$verify_lock_holder }
%include 'file/local_lock_verify.pas';      { FILE_$LOCAL_LOCK_VERIFY }
%include 'file/read_lock_entry.pas';        { FILE_$READ_LOCK_ENTRY }
%include 'file/read_lock_entryi.pas';       { FILE_$READ_LOCK_ENTRYI }
%include 'file/priv_unlock_all.pas';        { FILE_$PRIV_UNLOCK_ALL }
%include 'file/unlock_vol.pas';             { FILE_$UNLOCK_VOL }
%include 'file/force_unlock.pas';           { FILE_$FORCE_UNLOCK }
%include 'file/unlock_proc.pas';            { FILE_$UNLOCK_PROC }

{ ---- PROC2_CREATE_PRO ---- }
%include 'file/set_len.pas';                { FILE_$SET_LEN }
%include 'file/set_len_d.pas';              { FILE_$SET_LEN_D }
%include 'file/truncate.pas';               { FILE_$TRUNCATE }
%include 'file/truncate_d.pas';             { FILE_$TRUNCATE_D }
%include 'file/get_seg_map.pas';            { FILE_$GET_SEG_MAP }
%include 'file/export_lk.pas';              { FILE_$EXPORT_LK }
%include 'file/fork_lock.pas';              { FILE_$FORK_LOCK }
%include 'file/reserve.pas';                { FILE_$RESERVE }

{ ---- PROC2_DELETE_PRO ---- }
%include 'file/unlock_all.pas';             { FILE_$UNLOCK_ALL }
%include 'file/invalidate.pas';             { FILE_$INVALIDATE }
