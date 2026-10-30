{ acl/acl.ins.pas - ACL_ (access control lists), for the Domain Pascal
  tree.

  What the Pascal files use.  Include base/base.ins.pas before it.
}

{ ACL_$CLEAR_SUPER - leave super-user mode altogether. }
procedure acl_$clear_super; extern;

{ }

type
  { A process's SID block, 0x24 bytes: four UIDs and a longword.
    ACL_$GET_RE_ALL_SIDS copies nine longwords into it; PACCT_$LOG
    copies one into its record as a whole. }
  acl_sid_block_t = record
    user_sid: uid_$t;                     { 0x00 }
    group_sid: uid_$t;                    { 0x08 }
    org_sid: uid_$t;                      { 0x10 }
    login_sid: uid_$t;                    { 0x18 }
    pad: integer32;                       { 0x20 }
  end;

  { A process's project list, 12 bytes: three longwords, copied as three
    longword moves (ACL_$ALLOC_ASID). }
  acl_proj_list_t = record
    field_00: integer32;                  { 0x00 }
    field_04: integer32;                  { 0x04 }
    field_08: integer32;                  { 0x08 }
  end;

  { The 12-byte block ACL_$GET_RE_ALL_SIDS writes through its third and
    fourth arguments, three longwords; PACCT_$LOG copies the third's into
    its record as a whole.  It is acl_proj_list_t, not a record of its
    own: the two blocks are the process's saved project list and project
    list, ACL_$GET_RE_ALL_SIDS copying acl_$saved_proj[pid] and
    acl_$proj_lists[pid] into them, and an assignment needs the one
    type.  PACCT's uses copy the record whole (pacct/log.pas,
    pacct.ins.pas ac_prot). }
  acl_prot_info_t = acl_proj_list_t;

  { A process's eight project UIDs, 0x40 bytes: ACL_$ALLOC_ASID copies
    one row whole, ACL_$RIGHTS passes one by address to the module-local
    acl_$eval_rights, and ACL_$CHECK_RIGHTS and ACL_$RIGHTS_CHECK pass
    the exsid record's: one named type for both, so acl_$exsid_t's field
    below is of it (its users, pacct/start.pas and pacct/stop.pas, read
    the sids only). }
  acl_$proj_uids_t = array[1..8] of uid_$t;

  { The extended SID record ACL_$GET_EXSID fills, 0x64 bytes: the SID
    block and eight project UIDs.  PACCT_$START and PACCT_$STOP compare
    its login, group and user SIDs. }
  acl_$exsid_t = record
    sids: acl_sid_block_t;                { 0x00 }
    proj_uids: acl_$proj_uids_t;          { 0x24 }
  end;

{ ACL_$GET_EXSID - the current process's extended SID. }
procedure acl_$get_exsid(out exsid: acl_$exsid_t; out status: status_$t);
  extern;

{ ACL_$GET_RE_ALL_SIDS - the current process's original and current SIDs
  and its two project lists. }
procedure acl_$get_re_all_sids(out acl_data: acl_sid_block_t;
                               out re_sids: acl_sid_block_t;
                               out prot_info: acl_prot_info_t;
                               out subsys_ids: acl_prot_info_t;
                               out status: status_$t); extern;

{ ACL_$ENTER_SUPER - enter super-user mode.
  ACL_$EXIT_SUPER - leave super-user mode. }
procedure acl_$enter_super; extern;
procedure acl_$exit_super; extern;

const
  { status_$insufficient_rights_to_perform_operation, 16#00230002
    ("insufficient rights to perform operation", stcode.db.10.2):
    PACCT_$START stores it, PACCT_$STOP into its own status. }
  status_$insufficient_rights_to_perform_operation = 16#00230002;

{ }

const
  { The two other ACL statuses NAME_CONVERT_ACL_STATUS compares with
    (misc/name_convert_acl_status.pas): stcode.db.10.2 "no right to
    perform operation" and "wrong type - operation illegal on system
    objects". }
  status_$no_right_to_perform_operation = 16#00230001;
  status_$acl_wrong_type = 16#00230004;
  { 16#230007, stcode.db.10.2 "ACL is on different volume than object":
    OS_PROC_SHUTWIRED compares with it (os/proc_shutwired.pas); }
  status_$acl_on_different_volume = 16#00230007;

{ }

{ ACL_$CHECK_DEBUG_RIGHTS - whether a process may debug another. }
function acl_$check_debug_rights(in pid1: pinteger; in pid2: pinteger): boolean;
  extern;

{ }

{ ACL_$GET_PID_SID - a process's current SID block. }
procedure acl_$get_pid_sid(pid: integer; out sid_ret: acl_sid_block_t;
                           out status_ret: status_$t);
  options(extern, val_param);

{ ACL_$GET_RE_SIDS - the current process's original and current SIDs. }
procedure acl_$get_re_sids(out original_sids: acl_sid_block_t;
                           out current_sids: acl_sid_block_t;
                           out status_ret: status_$t); extern;

{ ACL_$RIGHTS - the rights the current process has to an object. }
function acl_$rights(uid: uid_$t; in ignore_super: boolean;
                     in required_mask: integer32; in option_flags: integer;
                     out status: status_$t): integer32; extern;

{ ACL_$IS_SUSER - whether the current process is a super-user. }
function acl_$is_suser: boolean; extern;

{ }

var
  { ACL_$FILE_ACL and ACL_$FILEIN_ACL (map symbols in the read-only UID
    table UID_LIST): the ACL type UIDs NAME_$CR_FILE passes to ACL_$COPY
    by address. }
  acl_$file_acl: extern uid_$t;
  { ACL_$DIR_ACL (UID_LIST): acl_$convert_rights compares the caller's
    type UID with it. }
  acl_$dir_acl: extern uid_$t;
  acl_$filein_acl: extern uid_$t;

{ ACL_$COPY - give an object the protection of a source ACL. }
procedure acl_$copy(in source_acl_uid: uid_$t; in dest_uid: uid_$t;
                    in source_type: uid_$t; in dest_type: uid_$t;
                    out status_ret: status_$t);
  extern;

{ }

const
  { stcode.db.10.2's names: CRASH_SYSTEM's argument in ACL_$EXIT_SUPER (a
    constant cell), and acl_$setids' and ACL_$ENTER_SUBS' stores. }
  status_$acl_exit_super_unbalanced = 16#00230003;
  status_$acl_no_right_to_set_subsystem_data = 16#00230010;
  { "ACL is full - no more entries may be added" (stcode.db.10.2):
    acl_$prim_create_internal stores it. }
  status_$acl_is_full = 16#00230013;
  { "ACL object not found" (stcode.db.10.2): acl_$load_acl_image stores
    it. }
  status_$acl_object_not_found = 16#0023000D;

type
  { The rights byte of a protection record (owner_rights ..
    subsys_rights): a set of eight rights, a word as a type (ref 3.9.3);
    the record's fields are `[byte] set of 0..7', one byte each (below).
    Its members are tested in memory: bit 4, "the entry's rights are
    kept" (ACL_$MIN_RIGHTS); bit 5, "a set-ID SID" (acl_$setids). }
  acl_$rights_t = set of 0..7;

  { A rights word: ACL_$MIN_RIGHTS' result (masked to its low four bits),
    a byte rights set widened into it, and the cached image entries'
    rights word removed from it. }
  acl_$rights_word_t = set of 0..15;


  { The 44-byte protection record: three SIDs, five rights bytes, three
    bytes nothing reads, three extension longwords.  ACL_$MIN_RIGHTS
    reads owner_rights .. world_rights of its attribute record,
    acl_$setids the three SIDs and the extension longwords. }
  { The five rights bytes are `[byte] set of 0..7' fields of the
    unpacked record, and the three bytes after them three chars.  As a
    plain `set of 0..7' each took a word (ref 3.9.3, p. 3-16: "the
    minimum storage size for a set is one word"), so group_rights fell
    at 0x1A and the record was 0x32 bytes, not 44.  A size attribute
    gives a set the storage it names (ref 3.15.5, p. 3-61: "a size
    attribute can specify a number of bits greater than the minimum for
    integer, boolean, and set data types"; Table 3-7 lists no minimum
    for sets, and a set of 0..7 needs 8 bits), and a one-byte object may
    sit at an odd offset in an unpacked record (ref 3.10.5.5, p. 3-26:
    only objects longer than a byte are word aligned), as the [byte]
    subranges and chars here do: owner_rights 0x18 .. subsys_rights
    0x1C, reserved_1d .. _1f 0x1D..0x1F, owner_ext 0x20, 0x2C bytes.
    The fields are not fields of a packed record, so they may be passed
    as arguments (ref 3.10.3 forbids that only for packed records), as
    prim_create_internal does, the image evaluating the argument between
    the pushes (acl/prim_create_internal.pas).  dpc refuses the size
    attribute on a set under --check-only, so these offsets follow from
    the reference's rules and the image's displacements; a probe of the
    same record with `[byte] 0..255' fields in their place gives them. }
  acl_$prot_data_t = record
    owner: uid_$t;                        { 0x00 }
    group: uid_$t;                        { 0x08 }
    org: uid_$t;                          { 0x10 }
    owner_rights: [byte] set of 0..7;     { 0x18 }
    group_rights: [byte] set of 0..7;     { 0x19 }
    org_rights: [byte] set of 0..7;       { 0x1A }
    world_rights: [byte] set of 0..7;     { 0x1B }
    subsys_rights: [byte] set of 0..7;    { 0x1C }
    reserved_1d: char;                    { 0x1D }
    reserved_1e: char;                    { 0x1E }
    reserved_1f: char;                    { 0x1F }
    owner_ext: array[1..3] of integer32;  { 0x20 }
  end;

  { An object attribute byte read as a number (acl_$setids). }
  acl_$attr_byte_t = [byte] 0..255;

  { A rights byte read as a number, the type a `[byte] set of 0..7'
    rights field is transferred to (ref p. 4-197: a type transfer needs
    equal sizes, one byte here); the assignment then widens it with
    zeros, into acl_$eval_rights' longword and into the cache directory's
    word (acl_$load_acl_image). }
  acl_$rights_byte_t = [byte] 0..255;

  { AST_$GET_ACL_ATTRIBUTES' 0x38-byte record, which the ACL_
    module-local acl_$get_obj_acl_attrs fills: four bytes of the
    object's attributes, its default-ACL UID, its protection record.
    Declared here, not in ast/ast.ins.pas, because its last field is
    ACL's record.  obj_type is tested as a number (acl_$setids, above),
    obj_flags' bit 0 is the "local" test (acl_$setids); the two bytes
    between are read by nothing ACL_ does but acl_$get_obj_acl_attrs'
    sub-type (below). }
  { obj_flags, a `set of 0..7' at 0x03, would take a word of the
    unpacked record at 0x04 (ref 3.9.3), moving default_acl to 0x06 and
    prot to 0x0E and making the record 0x40 bytes rather than 0x38.  It
    is a `[byte] set of 0..7' field (ref 3.15.5, as the protection
    record's rights, above), one byte at the odd offset 0x03 (ref
    3.10.5.5), its bit 0 the image's bit test at +3; attr_02 a char at
    0x02. }
  { A second view, the first four bytes as one longword:
    AST_$GET_ACL_ATTRIBUTES copies them from the AOTE's attribute
    record.  The first view's fields and offsets are unchanged. }
  ast_$acl_attr_t = record
    case integer of
      1: (obj_type: acl_$attr_byte_t;           { 0x00 }
          sub_type: acl_$attr_byte_t;           { 0x01: the sub-type, read as a
                                            number and stored
                                            (acl_$get_obj_acl_attrs) }
          attr_02: char;                        { 0x02 }
          obj_flags: [byte] set of 0..7;        { 0x03 }
          default_acl: uid_$t;                  { 0x04 }
          prot: acl_$prot_data_t);            { 0x0C }
      2: (hdr: integer32);                { 0x00 }
  end;


var
  { The UID_LIST cells (the map's read-only UID table) that ACL_ reads by
    address, under the map's ACL_ names (the map also names four of them
    RGYC_$P_SYS_USER_UID, RGYC_$G_SYS_PROJ_UID, RGYC_$G_LOCKSMITH_UID
    and RGYC_$O_SYS_ORG_UID): ACL_$FREE_ASID, ACL_$INIT.  ACL_$NIL is
    16#00000100.00000000 in the image. }
  acl_$nil: extern uid_$t;
  acl_$sys_user_uid: extern uid_$t;
  acl_$sys_proj_uid: extern uid_$t;
  { ACL_$LOGIN_UID (the map's RGYC_$G_LOGIN_UID as well):
    acl_$check_suser_pid compares the process's login SID with it. }
  acl_$login_uid: extern uid_$t;
  acl_$locksmith_uid: extern uid_$t;
  acl_$sys_org_uid: extern uid_$t;
  { ACL_$FNDWRX (16#0001800F.00000000 in the image), the file default ACL
    that acl_$expand_default_acl puts for ACL_$NIL. }
  acl_$fndwrx: extern uid_$t;
  { ACL_$DNDCAL (16#0002A07F.00000000 in the image), the directory default
    ACL acl_$get_obj_acl_attrs puts for ACL_$NIL. }
  acl_$dndcal: extern uid_$t;
  { The ACL type UIDs ACL_$COPY compares its source and destination types
    with: the map's ACL_$DIRIN_ACL, _$FILE_SUBS_ACL, _$FILE_MERGE_ACL and
    _$DIR_MERGE_ACL (UID_LIST). }
  acl_$dirin_acl: extern uid_$t;
  acl_$dir_merge_acl: extern uid_$t;
  acl_$file_merge_acl: extern uid_$t;
  acl_$file_subs_acl: extern uid_$t;

  { ACL_$SUPER_COUNT (map symbol in the ACL_ .DATA block, +0xB78): the
    super-mode count of each process, a word, from pid 1 (acl/acl.pas).
    ACL_$ENTER_SUPER increments element pid at +0xB76 + 2 * pid off A5;
    REM_FILE reaches it by the symbol. }
  acl_$super_count: extern array[1..64] of integer;

{ ACL_$INIT - initialize the ACL manager. }
procedure acl_$init; extern;

{ ACL_$MIN_RIGHTS - the rights every user has to an object. }
function acl_$min_rights(uid: uid_$t): acl_$rights_word_t; extern;

{ ACL_$CHECK_RIGHTS - an object's rights for a given SID context.
  ACL_$RIGHTS_CHECK - an object's rights for a given SID context, in or
  out of a subsystem. }
function acl_$check_rights(in acl_ctx: acl_$exsid_t; file_uid: uid_$t;
                           in required_mask: integer32;
                           in option_flags: integer;
                           out status: status_$t): integer32; extern;
function acl_$rights_check(in acl_ctx: acl_$exsid_t; file_uid: uid_$t;
                           in required_mask: integer32;
                           in option_flags: integer;
                           in check_flag: boolean;
                           out status: status_$t): integer32; extern;

{ ACL_$ENTER_SUBS - enter the protected subsystem an object names. }
function acl_$enter_subs(uid: uid_$t; out status_ret: status_$t): boolean;
  extern;

{ ACL_$UP - enter a protected subsystem for rights checking.
  ACL_$DOWN - leave a protected subsystem for rights checking. }
procedure acl_$up; extern;
procedure acl_$down; extern;

{ ACL_$IN_SUBSYS - whether the current process is in a protected
  subsystem. }
function acl_$in_subsys: boolean; extern;

{ ACL_$ALLOC_ASID - give a new address space the current process's SIDs. }
procedure acl_$alloc_asid(asid: integer; out status_ret: status_$t);
  options(extern, val_param);

{ ACL_$GET_SID - the current process's original SID block. }
procedure acl_$get_sid(out sid_ret: acl_sid_block_t;
                       out status_ret: status_$t); extern;

{ ACL_$FREE_ASID - reset an address space's ACL state to the defaults. }
procedure acl_$free_asid(asid: integer; out status_ret: status_$t);
  options(extern, val_param);

{ }

{ ACL_$DEF_ACLDATA - the default ACL data: a protection record and the nil
  ACL UID. }
procedure acl_$def_acldata(out prot: acl_$prot_data_t;
                           out def_acl_uid: uid_$t); extern;

{ ACL_$CONVERT_FUNKY_ACL - turn a "funky" ACL UID into ACL data. }
procedure acl_$convert_funky_acl(in acl_uid: uid_$t;
                                 var prot: acl_$prot_data_t;
                                 var norm_uid: uid_$t;
                                 out acl_type_uid: uid_$t;
                                 out status: status_$t); extern;

{ }

{ ACL_$SET_ACL_CHECK - may the caller put this ACL on this object, and is
  it a set-id operation. }
function acl_$set_acl_check(obj_uid: uid_$t;
                            in new_prot: acl_$prot_data_t;
                            in acl_uid: uid_$t;
                            in op_type: integer;
                            out setid_ret: boolean;
                            out status_ret: status_$t): boolean; extern;

{ ACL_$DEFAULT_ACL - the default ACL UID for an object type. }
function acl_$default_acl(in acl_type: integer): uid_$t; extern;

{ }

const
  { "image buffer too small or incorrect size" (stcode.db.10.2):
    ACL_$PRIM_CREATE and acl_$image_internal store it. }
  status_$image_buffer_too_small = 16#0023000C;

type
  { (ACL_$PRIM_CREATE and ACL_$IMAGE take an ACL image of this type,
    acl_$cache_slot_t's second variant.) }
  { One entry of a cached ACL image, 0x20 bytes: the entries from +0x34
    of a slot, in steps of 0x20 (ACL_$MIN_RIGHTS).  The rights word at
    +0x1A is the field the routines read. }
  acl_$cache_entry_t = record
    case integer of
      1: (ids: array[1..24] of char;      { 0x00 }
          reserved_18: integer;           { 0x18 }
          rights: acl_$rights_word_t;     { 0x1A }
          entry_1c: array[1..2] of integer);
                                          { 0x1C }
      { The three SIDs and the rights as a longword: acl_$convert_image
        copies the SIDs as one 24-byte object, stores the converted
        rights widened, and tests its bits on the low byte. }
      2: (person: uid_$t;                 { 0x00 }
          group: uid_$t;                  { 0x08 }
          org: uid_$t;                    { 0x10 }
          rights_l: linteger);            { 0x18 }
  end;

  { One cache slot, an ACL image of 0x400 bytes: the entry count at
    +0x0E (ACL_$MIN_RIGHTS), the required-subsystem UID at +0x12
    (acl_$setids), the entries from +0x34.  The UIDs and the longwords
    at 2 mod 4 are word aligned (`[aligned(1)]', ref 3.10.6); 30 entries
    end at +0x3F4, and the 12 bytes after them are the slot's rest
. }
  acl_$cache_slot_t = record
    version: integer;                     { 0x00 }
    type_uid: [aligned(1)] uid_$t;        { 0x02 }
    reserved_0a: [aligned(1)] integer32;  { 0x0A }
    entry_count: integer;                 { 0x0E }
    reserved_10: integer;                 { 0x10 }
    required_uid: [aligned(1)] uid_$t;    { 0x12 }
    subsys_uid: [aligned(1)] uid_$t;      { 0x1A }
    reserved_22: [aligned(1)] integer32;  { 0x22 }
    reserved_26: integer;                 { 0x26 }
    world_entry_present: boolean;         { 0x28 }
    unused_29: char;                      { 0x29 }
    case integer of
      1: (reserved_2a: array[1..5] of integer;
                                          { 0x2A }
          entries: array[1..30] of acl_$cache_entry_t;
                                          { 0x34 }
          tail_3f4: array[1..12] of char);
                                          { 0x3F4 }
      { Twelve words from +0x2A, as acl_$image_internal clears them for its
        default image, running past reserved_2a into the first entry
        (acl_$v5_build_t's words_2a, for acl_$convert_image's image). }
      2: (words_2a: array[1..12] of integer);
                                          { 0x2A }
  end;
  { A pointer to a slot (ACL_$SERVER's request records hold two such
    pointers, and its heading is here). }
  acl_$cache_slot_ptr_t = ^acl_$cache_slot_t;

{ ACL_$PRIM_CREATE - create an ACL object from a version-5 ACL image. }
procedure acl_$prim_create(var acl_data: univ acl_$cache_slot_t;
                           in data_len: integer; in dir_uid: uid_$t;
                           in prot: acl_$prot_data_t;
                           var file_uid_ret: uid_$t;
                           out status_ret: status_$t); extern;

{ ACL_$IMAGE - an ACL object's version-5 image, under the ACL lock. }
procedure acl_$image(in source_uid: uid_$t; in buffer_len: integer;
                     in flag: boolean; var image: univ acl_$cache_slot_t;
                     out len_out: integer; var data_out: acl_$prot_data_t;
                     out status_ret: status_$t); extern;

{ The project-list routines.

  The statuses, with the texts of stcode.db.10.2: 16#230011 "project
  list is full - no more entries may be added", ACL_$ADD_PROJ's;
  16#230012 "project list is too big - it cannot be added to object",
  ACL_$SET_PROJ_LIST's. }
const
  status_$project_list_is_full = 16#00230011;
  status_$acl_proj_list_too_big = 16#00230012;

{ ACL_$ADD_PROJ - add a project to the current process's project list.
  ACL_$DELETE_PROJ - delete a project from the current process's list. }
procedure acl_$add_proj(in proj_acl: uid_$t; out status_ret: status_$t);
  extern;
procedure acl_$delete_proj(in proj_acl: uid_$t; out status_ret: status_$t);
  extern;

{ ACL_$GET_PROJ_LIST - the current process's project list. }
procedure acl_$get_proj_list(out proj_acls: acl_$proj_uids_t;
                             in max_count: integer;
                             out count_ret: integer;
                             out status_ret: status_$t); extern;

{ ACL_$SET_PROJ_LIST - set the current process's project list. }
procedure acl_$set_proj_list(in proj_acls: acl_$proj_uids_t;
                             in count: integer;
                             out status_ret: status_$t); extern;

{ ACL_$SET_RE_ALL_SIDS - set the current process's original and current
  SIDs and project lists. }
procedure acl_$set_re_all_sids(in new_original_sids: acl_sid_block_t;
                               in new_current_sids: acl_sid_block_t;
                               in new_saved_proj: acl_proj_list_t;
                               in new_current_proj: acl_proj_list_t;
                               out status_ret: status_$t); extern;

{ ACL_$SET_RES_ALL_SIDS - set the current process's original, current and
  saved SIDs and project lists. }
procedure acl_$set_res_all_sids(in new_original_sids: acl_sid_block_t;
                                in new_current_sids: acl_sid_block_t;
                                in new_saved_sids: acl_sid_block_t;
                                in new_saved_proj: acl_proj_list_t;
                                in new_current_proj: acl_proj_list_t;
                                out status_ret: status_$t); extern;

{ }

{ ACL_$GET_RES_ALL_SIDS - the current process's original, current and
  saved SIDs and its two project lists. }
procedure acl_$get_res_all_sids(out original_sids: acl_sid_block_t;
                                out current_sids: acl_sid_block_t;
                                out saved_sids: acl_sid_block_t;
                                out saved_proj: acl_proj_list_t;
                                out current_proj: acl_proj_list_t;
                                out status_ret: status_$t); extern;

{ ACL_$GET_RES_SIDS - the current process's original, current and saved
  SIDs. }
procedure acl_$get_res_sids(out original_sids: acl_sid_block_t;
                            out current_sids: acl_sid_block_t;
                            out saved_sids: acl_sid_block_t;
                            out status_ret: status_$t); extern;

{ ACL_$CHECK_FAULT_RIGHTS - whether a process may handle another's faults. }
function acl_$check_fault_rights(in pid1: pinteger; in pid2: pinteger):
  boolean; extern;

{ ACL_$SET_DEF_ACL_CHECK - may this ACL be a directory's default ACL? }
function acl_$set_def_acl_check(dir_uid: uid_$t;
                                in prot_data: acl_$prot_data_t;
                                in acl_uid: uid_$t;
                                in unused_4: integer;
                                in acl_type: uid_$t;
                                out status_ret: status_$t): boolean;
  extern;

{ ACL_$CONVERT_TO_9ACL - an ACL object for an ACL's 9-entry image. }
procedure acl_$convert_to_9acl(in prot: acl_$prot_data_t;
                               in source_uid: uid_$t;
                               in dir_uid: uid_$t;
                               in default_prot: uid_$t;
                               var result_uid: uid_$t;
                               out status_ret: status_$t); extern;

{ ACL_$CONVERT_TO_10ACL - an SR10 ACL object for an old ACL. }
procedure acl_$convert_to_10acl(in source_acl: uid_$t;
                                in dir_uid: uid_$t;
                                var result_uid: uid_$t;
                                var acl_data: acl_$prot_data_t;
                                out status_ret: status_$t); extern;

{ ACL_$CONVERT_FROM_9ACL - an ACL object's image, and its UID marked. }
procedure acl_$convert_from_9acl(in source_acl: uid_$t;
                                 in acl_type: uid_$t;
                                 var prot_buf_out: acl_$prot_data_t;
                                 out prot_uid_out: uid_$t;
                                 out status_ret: status_$t); extern;

{ ACL_$INHERIT_SUBSYS - set the current process's subsystem bit. }
procedure acl_$inherit_subsys(in flag: boolean; out status: status_$t);
  extern;

{ ACL_$SET_LOCAL_LOCKSMITH - set the local locksmith value. }
procedure acl_$set_local_locksmith(in value: integer; out status: status_$t);
  extern;

{ ACL_$GET_LOCAL_LOCKSMITH - the local locksmith value. }
function acl_$get_local_locksmith: integer; extern;

{ ACL_$OVERRIDE_LOCAL_LOCKSMITH - set or clear the caller's locksmith
  override bit. }
procedure acl_$override_local_locksmith(enable: boolean;
                                        out status: status_$t);
  options(extern, val_param);

{ ACL_$USED_SUSER - whether the current process has used its super-user
  rights. }
function acl_$used_suser: boolean; extern;

{ }

type
  { The remote-file server's request as ACL_$SERVER reads it:
    REM_FILE_$SERVER's 0x298-byte request (prefixed where two views
    would clash).  The common header, then one view per opcode from
    +0x0C; each offset is the one ACL_$SERVER addresses
    (acl/server.pas).  The single bytes are numbers or booleans as the
    code uses them: the opcode zero-extended for the jump table; the
    flags read as bytes by value.  The view of +0x10 as 48 characters is
    ACL_SETIDS's reply copy, a character array's assignment ("byte
    copies"). }
  acl_$srv_req_t = record
    version: integer;                     { 0x00 }
    unused_02: char;                      { 0x02 }
    opcode: acl_$attr_byte_t;             { 0x03 }
    uid: uid_$t;                          { 0x04: the object }
    case integer of
      1: (mode: integer;                  { 0x0C: ACL_IMAGE }
          flag: boolean;                  { 0x0E }
          unused_0f: char;                { 0x0F }
          buf: acl_$cache_slot_ptr_t);    { 0x10 }
      2: (c_unused_0c: integer32;         { 0x0C: ACL_CREATE }
          create_prot: acl_$prot_data_t;  { 0x10 }
          acl_data: acl_$cache_slot_ptr_t;
                                          { 0x3C }
          create_acl_uid: uid_$t);        { 0x40 }
      3: (r_unused_0c: integer;           { 0x0C: ACL_CHECK_RIGHTS }
          option_flags: integer;          { 0x0E }
          rights_sids: acl_sid_block_t;   { 0x10 }
          rights_proj: acl_$proj_uids_t;  { 0x34 }
          required_mask: integer32;       { 0x74 }
          ignore_super: boolean;          { 0x78 }
          in_super: boolean;              { 0x79 }
          in_subsys: boolean);            { 0x7A }
      4: (s_unused_0c: integer32;         { 0x0C: ACL_SETIDS }
          setids_sids: acl_sid_block_t;   { 0x10 }
          owner_ext: acl_proj_list_t);    { 0x34 }
      5: (a_unused_0c: integer;           { 0x0C: SET_ACL }
          proj_count: integer;            { 0x0E }
          new_sids: acl_sid_block_t;      { 0x10 }
          new_proj: acl_$proj_uids_t;     { 0x34 }
          set_acl_uid: uid_$t;            { 0x74 }
          set_prot: acl_$prot_data_t;     { 0x7C }
          op_type: integer);              { 0xA8 }
      6: (b_unused_0c: integer32;         { 0x0C }
          sids_bytes: array[1..48] of char);
                                          { 0x10 }
  end;

  { The reply ACL_$SERVER builds: the common header, then one view per
    opcode from +0x0A. }
  acl_$srv_resp_t = record
    one: integer;                         { 0x00: always 1 }
    flags: acl_$attr_byte_t;              { 0x02: 16#80 }
    opcode: acl_$attr_byte_t;             { 0x03: the request's + 1, or 3 }
    status: status_$t;                    { 0x04 }
    unused_08: integer;                   { 0x08 }
    case integer of
      1: (image_len: integer;             { 0x0A: ACL_IMAGE }
          image_prot: acl_$prot_data_t);  { 0x0C }
      2: (changed: boolean;               { 0x0A: ACL_SETIDS }
          unused_0b: char;                { 0x0B }
          sids_bytes: array[1..48] of char);
                                          { 0x0C }
      3: (c_unused_0a: integer;           { 0x0A: ACL_CREATE }
          created_uid: uid_$t);           { 0x0C }
      4: (r_unused_0a: integer;           { 0x0A: ACL_CHECK_RIGHTS }
          rights: integer32);             { 0x0C }
  end;

{ ACL_$SERVER - the ACL half of the remote-file server. }
procedure acl_$server(var req: acl_$srv_req_t; out resp: acl_$srv_resp_t;
                      out reply_len: pinteger);
  extern;

{ FILE_'s and DIR's routines whose headings take ACL_'s protection
  record, acl_$prot_data_t (above).  Declared here, the record's insert
  file, because their own insert files cannot hold them:
  file/file.ins.pas and dir/dir.ins.pas are included by modules that do
  not include this file (asknode, flop, volx; file.ins.pas by many
  more), and a heading needs its types before it.  One copy each, with
  the modes of the routines' bodies (FILE_ and DIR, the translations'
  fragments).  Every caller passes variables by address (the default
  convention), so the code at their call sites does not change with the
  modes. }

{ FILE_$SET_PROT (compiled, global, FILE_): the default convention.
  The modes from the body (file/set_prot.pas): file_uid, acl_data and
  def_acl only read and passed on to `in' formals (FILE_$SET_PROT_INT's,
  file_$audit_set_prot's): `in'; prot_type read: `in'; status_ret
  written first on every path: `out'.  Callers: ACL_$COPY
  (acl/copy.pas), FILE_$SET_ACL (file/set_acl.pas), DIR's
  dir_$add_bak_default_prot (the kind a word cell, 5), dir_$do_op_set_prot,
  DIR_$SET_PROTECTION, dir_$do_op_set_acl, OLD_DIR's DIR_$OLD_ADD_BAKU
  (twice, the kind a word cell, 6): five addresses each. }
procedure file_$set_prot(in file_uid: uid_$t; in prot_type: integer;
                         in acl_data: acl_$prot_data_t;
                         in def_acl: uid_$t; out status_ret: status_$t);
  extern;

{ FILE_$OLD_AP (compiled, global, FILE_): the default convention.  The
  modes from the body (file/old_ap.pas): file_uid passed on to
  FILE_$SET_PROT_INT's `in': `in'; prot_type read twice: `in'; acl_data
  and def_acl only copied: `in'; status_ret passed on to
  FILE_$SET_PROT_INT's `out': `out'.  Caller: ACL_$COPY. }
procedure file_$old_ap(in file_uid: uid_$t; in prot_type: integer;
                       in acl_data: acl_$prot_data_t; in def_acl: uid_$t;
                       out status_ret: status_$t); extern;

{ DIR_$GET_DEF_PROTECTION (compiled, global, DIR): the default
  convention (ACL_$CONVERT_FUNKY_ACL and others push five addresses; the
  SVC table).  The modes from the body (dir/get_def_protection.pas): the
  directory UID's slot held, copied and passed on to `in' formals:
  `in'; the type UID's likewise: `in'; the protection record's written
  or passed on to ACL_$CONVERT_FROM_9ACL's `var': `var'; the UID's
  written or passed on to its `out': `out'; the status written or first
  passed to `out' formals (DIR_$OLD_GET_DEFAULT_ACL's,
  dir/old_get_default_acl.pas): `out'. }
procedure dir_$get_def_protection(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  var prot_buf: acl_$prot_data_t;
                                  out prot_uid: uid_$t;
                                  out status_ret: status_$t); extern;

{ DIR_$SET_DEF_PROTECTION (compiled, global, DIR): the default
  convention (ACL_$COPY pushes five addresses; the SVC table).  The
  modes from the body (dir/set_def_protection.pas): dir_uid, acl_type,
  prot and def_acl copied into the request and passed on to
  ACL_$CONVERT_TO_9ACL's and DIR_$OLD_SET_DEFAULT_ACL's `in' formals:
  `in'; status_ret written or first passed to ACL_$CONVERT_TO_9ACL's
  `out': `out'. }
procedure dir_$set_def_protection(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  in prot: acl_$prot_data_t;
                                  in def_acl: uid_$t;
                                  out status_ret: status_$t); extern;

{ DIR_$SET_PROTECTION (compiled, global, DIR): the default convention
  (ACL_$COPY pushes five addresses, the type a word cell; the SVC
  table).  The modes from the body (dir/set_protection.pas): uid copied
  into the request and passed on to ACL_$CONVERT_TO_9ACL's,
  FILE_$PRIV_LOCK's, FILE_$SET_PROT's and FILE_$PRIV_UNLOCK's `in'
  formals: `in'; prot copied and passed on to ACL_$CONVERT_TO_9ACL's and
  FILE_$SET_PROT's `in': `in'; def_acl copied and passed on to
  ACL_$CONVERT_TO_9ACL's `in': `in'; prot_type read only: `in';
  status_ret written or first passed to `out' formals: `out'. }
procedure dir_$set_protection(in uid: uid_$t; in prot: acl_$prot_data_t;
                              in def_acl: uid_$t; in prot_type: integer;
                              out status_ret: status_$t); extern;

{ 16#0023001C, "attempt to issue unimplemented ACL call" (stcode.db.10.2,
  OS / ACL manager): FILE_$SET_ACL stores it for an ACL UID of kind 0;
  dir_$do_op_set_acl likewise. }
const
  status_$acl_unimplemented_call = 16#0023001C;
