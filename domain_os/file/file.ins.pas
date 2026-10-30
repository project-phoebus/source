{ file/file.ins.pas - FILE_ (file locks and object locations), for the
  Domain Pascal tree.

  No customer insert file of the SR10.2 install declares these kernel
  entry points or the object-location record, so each declaration is
  read off the image.  Include base/base.ins.pas before it.
}

type
  { The object-location record, 0x20 bytes.  AST_$GET_ATTRIBUTES reads
    the UID at +0x08 and overwrites the whole record.  The two bytes at
    0x1C (the rights bits), 0x1D (flags: bit 7 remote, bit 6 a
    scratch flag) are one word set here: LOG_$INIT clears bit 6 of 0x1D
    the way member 6 of a word set at 0x1C is removed; a byte field cannot
    hold a set in an unpacked record (a set takes whole words, ref 3.9.3),
    and a boolean is not cleared that way.  So members 6 and 7 are flags'
    bits 6 and 7, members 8..15 the rights bits. }
  file_$obj_loc_t = record
    reserved_00: integer;                 { 0x00 }
    volume: integer;                      { 0x02 }
    block_hint: integer32;                { 0x04 }
    uid: uid_$t;                          { 0x08 }
    loc_info: integer32;                  { 0x10 }
    node: linteger;                       { 0x14: a linteger: it
                                            is merged unmasked into a
                                            20-bit field (AST_$ACTIVATE_
                                            AOTE_CANNED,
                                            MST_$LOOKUP_OBJECT), the
                                            form of a linteger (dpc
                                            masks an integer32 first); its
                                            other uses are moves and
                                            `=' / `<>' compares }
    reserved_18: integer32;               { 0x18 }
    flags: set of 0..15;                  { 0x1C: the rights bits
                                            (0x1C) and flags (0x1D);
                                            member 6 the scratch bit,
                                            member 7 the remote bit }
    reserved_1e: integer;                 { 0x1E }
  end;

{ FILE_$LOCK - lock an object for the calling address space. }
procedure file_$lock(in file_uid: uid_$t; in lock_index: integer;
                     in lock_mode: integer; in rights: boolean;
                     var lock_info: integer32; out status: status_$t);
  extern;

{ FILE_$UNLOCK - release the calling address space's lock on an object. }
function file_$unlock(in file_uid: uid_$t; in lock_mode: integer;
                      out status: status_$t): boolean;
  extern;


type
  { A byte read as an unsigned 8-bit integer (ref 3.15.5), suma's
    suma_$byte_t's form: PACCT_$START zero-extends the attribute record's
    type byte before testing it. }
  file_$byte_t = [byte] 0..255;

  { The attribute record FILE_$GET_ATTR_INFO fills, as its callers give
    it: 0x80 bytes in their frames; the size they ask for is 0x7A.  The
    bytes read: the object's type at +0x01 (PACCT_$START), its length at
    +0x14, a device word at +0x32 (PACCT_$LOG).  The field names are
    file_type, file_len and devno. }
  { The two lengths at +0x3C of the 0x90-byte attribute record, copied
    whole as an 8-byte record to +0x1C of the 0x7A-byte one (by
    FILE_$GET_ATTR_INFO): vtoc/vtoc.ins.pas's vtoce_$lengths_t, the same
    bytes of a VTOCE, declared again here because file.ins.pas is
    included before vtoc.ins.pas. }
  file_$lengths_t = record
    current_length: integer32;            { 0x00 }
    blocks_used: integer32;               { 0x04 }
  end;

  { The 12 bytes at +0x68 of the 0x90-byte attribute record, copied
    whole by longwords to +0x6E of the 0x7A-byte one (by
    FILE_$GET_ATTR_INFO): one type for both fields, so that the
    assignment is legal.  As vtoc/vtoc.ins.pas's vtoce_$t unknown_68. }
  file_$longs3_t = array[1..3] of integer32;

  { The word at +0x64 of the 0x90-byte attribute record: a byte, four
    booleans and a nibble (vtoc/vtoc.ins.pas's vtoce_$ext_t, its names,
    the same bytes of a VTOCE).  FILE_$GET_ATTR_INFO copies the byte and
    reads bits 7, 5 and 4 of the second: the packed record's bits 8, 10
    and 11. }
  file_$attr_ext_t = packed record
    acl_flags: file_$byte_t;              { byte 0x64 }
    ext_7: boolean;                       { 0x65 bit 7 }
    ext_6: boolean;
    ext_5: boolean;                       { 0x65 bit 5 }
    ext_4: boolean;                       { 0x65 bit 4 }
    ext_3_0: 0..15;
  end;

  { The first longword of the 0x7A-byte attribute record as 32 bits:
    FILE_$GET_ATTR_INFO stores the longword, then three of its bits one
    by one, bits 1 and 0 of its third byte and bit 7 of its fourth:
    packed bits 22, 23 and 24 (a boolean's value
    form).  They are the attribute record's ext_7, ext_5 and ext_4,
    whose names they take. }
  file_$attr_bits_t = packed record
    unused_0: 0..65535;                   { bits 0..15 }
    unused_16: 0..63;                     { bits 16..21 }
    ext_7: boolean;                       { bit 22: byte 2 bit 1 }
    ext_5: boolean;                       { bit 23: byte 2 bit 0 }
    ext_4: boolean;                       { bit 24: byte 3 bit 7 }
    unused_25: 0..127;                    { bits 25..31 }
  end;

  { FILE_$GET_ATTR_INFO's stores give every field of view 2: the masked
    longword at +0x00, 24 bytes at +0x04, 16 at +0x3E and 28 at +0x4E
    copied by bytes (arrays of char), the 8-byte lengths at +0x1C, three
    6-byte clocks at +0x24, +0x2C and +0x36, the words at +0x32 (variant 1's
    devno) and +0x3C, the byte at +0x6A and 12 bytes at +0x6E by longwords
    (an array of integer32).  +0x2A, +0x34 and +0x6B..+0x6D are never
    written.  The names are the 0x90-byte record's fields they come from
    (file_$attributes_t's view 2). }
  file_$attr_info_t = record
    case integer of
      1: (unused_00: char;                { 0x00 }
          file_type: file_$byte_t;        { 0x01 }
          unused_02: array[16#02..16#13] of char;  { 0x02 }
          file_len: integer32;            { 0x14 }
          unused_18: array[16#18..16#31] of char;  { 0x18 }
          devno: pinteger;                { 0x32 }
          unused_34: array[16#34..16#7F] of char);  { 0x34 }
      2: (word_00: linteger;              { 0x00 }
          id_04: array[1..24] of char;    { 0x04 }
          lengths: file_$lengths_t;       { 0x1C }
          dtu: time_$clock_t;             { 0x24 }
          pad_2a: integer;                { 0x2A }
          clock_2c: time_$clock_t;        { 0x2C }
          pad_32: pinteger;               { 0x32: variant 1's devno }
          pad_34: integer;                { 0x34 }
          dta: time_$clock_t;             { 0x36 }
          link_count: pinteger;           { 0x3C }
          id_3e: array[1..16] of char;    { 0x3E }
          acl_ids: array[1..28] of char;  { 0x4E }
          acl_flags: file_$byte_t;        { 0x6A }
          pad_6b: char;                   { 0x6B }
          pad_6c: integer;                { 0x6C }
          unknown_6e: file_$longs3_t);  { 0x6E }
      3: (bits: file_$attr_bits_t);       { 0x00 }
  end;

{ FILE_$PRIV_LOCK - take, change or record a lock on an object. }
procedure file_$priv_lock(in file_uid: uid_$t; asid: integer;
                          side: pinteger; lock_mode: pinteger;
                          local_only: boolean; flags: integer;
                          key: integer; rem_key: integer32;
                          rem_node: integer32; rem_extra: integer32;
                          in acl_ctx: univ integer32; rem_wait: integer;
                          in out slot_io: linteger;
                          out rights_out: integer;
                          out status: status_$t);
  options(extern, val_param);

{ FILE_$PRIV_UNLOCK - release a lock on an object, or every lock this
  address space holds on it. }
function file_$priv_unlock(in file_uid: uid_$t; lock_slot: integer32;
                           lock_mode: integer; asid: integer;
                           by_key: boolean; key: integer;
                           rem_key: integer32; rem_node: integer32;
                           out dtv_out: time_$clock_t;
                           out status: status_$t): boolean;
  options(extern, val_param);

{ FILE_$GET_ATTR_INFO - an object's attributes in the 0x7A-byte form. }
procedure file_$get_attr_info(in file_uid: uid_$t; in req: integer;
                              in size: integer;
                              in out loc: file_$obj_loc_t;
                              out info: file_$attr_info_t;
                              out status: status_$t); extern;

{ FILE_$SET_LEN - set an object's length. }
procedure file_$set_len(in file_uid: uid_$t; in new_length: integer32;
                        out status: status_$t); extern;

const
  { status_$no_rights, 16#000F0010 ("no rights", stcode.db.10.2):
    PACCT_$START's status for an attribute record whose type is not 0. }
  status_$no_rights = 16#000F0010;


{ FILE_$DELETE - delete an object. }
function file_$delete(in file_uid: uid_$t; out status: status_$t): boolean;
  extern;


{ FILE_$CREATE - create an untyped object in a directory. }
procedure file_$create(in dir_uid: uid_$t; var file_uid_ret: uid_$t;
                       out status_ret: status_$t);
  extern;


type
  { The 0x90-byte attribute record FILE_$GET_ATTRIBUTES fills:
    audit_$open_log passes one with its size and reads the file's length
    at +0x14. }
  { View 2, the fields FILE_$GET_ATTR_INFO reads: the longword at +0x00;
    24 bytes at +0x04, 28 at +0x48 and 16 at +0x78 copied by bytes
    (arrays of char); 6-byte clocks at +0x1C, +0x24 and +0x34; the
    8-byte lengths at +0x3C; the word at +0x64 (file_$attr_ext_t); 12
    bytes at +0x68 by longwords; the words at +0x74 and +0x76.  The
    record is the first 0x90 bytes of a VTOCE (vtoc/vtoc.ins.pas
    vtoce_$t; FILE_$ATTRIBUTES passes it on to VTOCE_$NEW_TO_OLD): the
    names are vtoce_$t's where its offsets and sizes agree (dtu, dta,
    lengths, acl_checksum, ext, unknown_68, link_count), and devno.
    vtoce_$t has a UID and a word at +0x24 and +0x28, and three UIDs and
    a byte array at +0x48: the copies here read a 6-byte clock and 28
    bytes of char, so this view is its own. }
  file_$attributes_t = record
    case integer of
      1: (unused_00: array[16#00..16#13] of char;  { 0x00 }
          length: integer32;              { 0x14 }
          unused_18: array[16#18..16#8F] of char);  { 0x18 }
      2: (word_00: linteger;              { 0x00 }
          id_04: array[1..24] of char;    { 0x04 }
          dtu: time_$clock_t;             { 0x1C }
          pad_22: integer;                { 0x22 }
          clock_24: time_$clock_t;        { 0x24 }
          pad_2a: array[1..10] of char;   { 0x2A }
          dta: time_$clock_t;             { 0x34 }
          pad_3a: integer;                { 0x3A }
          lengths: file_$lengths_t;       { 0x3C }
          acl_checksum: integer32;        { 0x44 }
          acl_ids: array[1..28] of char;  { 0x48 }
          ext: file_$attr_ext_t;          { 0x64 }
          pad_66: integer;                { 0x66 }
          unknown_68: file_$longs3_t;   { 0x68 }
          link_count: pinteger;           { 0x74 }
          devno: pinteger;                { 0x76 }
          id_78: array[1..16] of char;    { 0x78 }
          pad_88: array[1..8] of char);   { 0x88 }
      { The object's parent directory at +0x3C: the record is the
        AOTE's from +0x0C, and +0x3C is the AOTE's dirptr (attribute 5,
        FILE_$SET_DIRPTR's).  dir_$do_op_dir_readu reads it for "..".
        View 2's lengths, the same 8 bytes, are VTOCE_$'s reading of
        them; the views agree on nothing else. }
      3: (unused_v3_00: array[16#00..16#3B] of char;  { 0x00 }
          dirptr: uid_$t;                 { 0x3C }
          unused_v3_44: array[16#44..16#8F] of char);  { 0x44 }
      { The plain remote lock's result as REM_FILE_$LOCK writes it into
        FILE_$PRIV_LOCK's record: the reply's lock handle at +0x2C and
        its lock word at +0x30.  The names are the reply fields'. }
      4: (unused_v4_00: array[16#00..16#2B] of char;  { 0x00 }
          lock_handle: integer32;         { 0x2C }
          lock_word: pinteger;            { 0x30 }
          unused_v4_32: array[16#32..16#8F] of char);  { 0x32 }
      { The first byte as a number: REM_FILE_$SERVER's
        server_truncate_delete tests it after AST_$GET_ATTRIBUTES: a
        [byte] subrange widened with zeros. }
      5: (byte_00: [byte] 0..255;         { 0x00 }
          unused_v5_01: char;             { 0x01 }
          unused_v5_02: array[16#02..16#8F] of char);  { 0x02 }
  end;

{ FILE_$GET_ATTRIBUTES - an object's attributes in the 0x90-byte form. }
procedure file_$get_attributes(in file_uid: uid_$t; in req: integer;
                               in size: integer;
                               in out loc: file_$obj_loc_t;
                               out attrs: file_$attributes_t;
                               out status: status_$t); extern;

{ FILE_$SET_TYPE - set an object's type UID. }
procedure file_$set_type(in file_uid: uid_$t; type_uid: uid_$t;
                         out status: status_$t); extern;

{ FILE_$FW_FILE - force-write an object's modified pages. }
procedure file_$fw_file(in file_uid: uid_$t; out status: status_$t);
  extern;

{ FILE_$TRUNCATE - truncate an object. }
procedure file_$truncate(in file_uid: uid_$t; in new_size: integer32;
                         out status: status_$t); extern;


const
  { 16#000F0016, "volume has been mounted read-only", and 16#000F0001,
    "object not found" (stcode.db.10.2, OS / file server):
    vtoc_$fm_traverse stores the first and VTOCE_$LOOKUP_FM tests it;
    AST_'s vtoc_$search_volumes stores the second. }
  status_$file_volume_has_been_mounted_read_only = 16#000F0016;
  file_$object_not_found = 16#000F0001;


{ FILE_$SET_DIRPTR - set an object's parent directory pointer. }
procedure file_$set_dirptr(in uid: uid_$t; parent_uid: uid_$t;
                           out status_ret: status_$t);
  extern;


{ FILE_$PRIV_CREATE - create an object in a directory, locally or on the
  directory's node. }
function file_$priv_create(file_type: integer; in type_uid: uid_$t;
                           in dir_uid: uid_$t; var file_uid_ret: uid_$t;
                           initial_size: integer32; flags: integer;
                           owner_info: univ_ptr;
                           out status_ret: status_$t): boolean;
  options(extern, val_param);

{ FILE_$MK_IMMUTABLE - make an object immutable. }
procedure file_$mk_immutable(in file_uid: uid_$t; out status_ret: status_$t);
  extern;


const
  { 16#000F0003, "bad reply received from remote node" (stcode.db.10.2,
    OS / file server): ACL_$SERVER stores it for an opcode it does not
    serve. }
  file_$bad_reply_received_from_remote_node = 16#000F0003;

{ The headings of FILE_'s own globals not declared above, in map order,
  and the constants and types they need.  FILE_$SET_PROT's and
  FILE_$OLD_AP's headings are in acl/acl.ins.pas, not here: they take
  ACL_'s protection record, and this file's includers do not all include
  acl/acl.ins.pas; see file/README.md, "Insert files". }

const
  { The FILE_ statuses os_proc_shutwired gives for ACL_'s
    (stcode.db.10.2, OS / file server; os/proc_shutwired.pas, the os
    translation's fragment for this module).  ACL_'s
    status_$acl_on_different_volume (16#230007), which the routine also
    tests, is acl/acl.ins.pas's. }
  status_$insufficient_rights = 16#000F0011;
  file_$wrong_type = 16#000F0012;
  file_$objects_on_different_volumes = 16#000F0013;


{ FILE_$LOCK_INIT - set up the lock tables at boot. }
procedure file_$lock_init; extern;

{ FILE_$CHECK_PROT - check the caller's rights on an object, from its lock
  if it holds one. }
procedure file_$check_prot(in file_uid: uid_$t; access_mask: pinteger;
                           slot_num: linteger; ignore_super: boolean;
                           option_flags: integer; out rights_out: integer;
                           out status: status_$t);
  options(extern, val_param);

type
  { An attribute's new value, as FILE_$SET_ATTRIBUTE passes it on to
    AST_$SET_ATTRIBUTE, AST_$SET_ATTR and REM_FILE_$FILE_SET_ATTRIB: 0x34
    bytes, the 13 longwords REM_FILE_$FILE_SET_ATTRIB copies into its
    request.  FILE_$SET_ATTRIBUTE's callers build it in their frames
    (FILE_$MK_IMMUTABLE a boolean at +0, FILE_$SET_DIRPTR a UID,
    FILE_$SET_REFCNT a word): a variant record whose views the callers'
    fragments give. }
  file_$attr_value_t = record
    case integer of
      0: (raw: array[1..52] of char);  { 0x00 }
      1: (uid: uid_$t);                   { 0x00: FILE_$PRIV_CREATE's
                                            type UID }
      2: (flag: boolean);                 { 0x00: FILE_$PRIV_CREATE's
                                            flag }
      3: (audit: set of 0..15);           { 0x00: FILE_$SET_AUDITED's
                                            word: members 0 and 1 }
      4: (clock: time_$clock_t);          { 0x00: FILE_$SET_DTM_F's
                                            and FILE_$SET_DTU_F's time }
      5: (word_val: integer);             { 0x00: FILE_$SET_DEVNO's
                                            device word;
                                            FILE_$SET_REFCNT's count }
      6: (long_val: integer32);           { 0x00: priv_lock_check_
                                            conflicts' holder node }
  end;

{ FILE_$SET_ATTRIBUTE - set one attribute of an object, locally or on its
  home node. }
procedure file_$set_attribute(in file_uid: uid_$t; attr_id: integer;
                              in value: file_$attr_value_t;
                              rights: pinteger; options: integer;
                              out status_ret: status_$t);
  options(extern, val_param);

const
  { 16#000F000B, "operation cannot be done from here", and 16#000F0014,
    "invalid argument" (stcode.db.10.2, OS / file server):
    FILE_$PRIV_CREATE stores the first for a remote create with a
    caller's UID, the second for a pre-SR10 node and types 4 and 5. }
  file_$op_cannot_perform_here = 16#000F000B;
  file_$invalid_arg = 16#000F0014;

  { FILE_$SET_PROT's protection kinds, 0..6, its `case type_val': each
    names the attribute it sets, 16#10, 16#11, 16#12, 16#15, 16#13, 16#14
    and 3 (REM_FILE_$SERVER's server_set_prot_attrib maps them back,
    rem_file/server_set_prot_attrib.pas).  Callers: FILE_$SET_ACL
    passes 4, DIR_$SET_PROTECTION admits 4, 5 and 6, OLD_DIR passes 6,
    FILE_$OLD_AP tests 6.  file_$prot_acl is DIR_'s name for 6; the
    others are new, after the attributes (ast/ast.pas's ast_attr_owner1
    .. ast_attr_set_rights). }
  file_$prot_owner1 = 0;                { }
  file_$prot_owner2 = 1;                { }
  file_$prot_owner3 = 2;                { }
  file_$prot_rights = 3;                { }
  file_$prot_acl_image = 4;             { }
  file_$prot_merge_acl = 5;             { }
  file_$prot_acl = 6;

  { 16#000F0002, "object is remote", and 16#000F0015, "incompatible
    request" (stcode.db.10.2, OS / file server): FILE_$SET_PROT_INT
    accepts the first from file_$check_same_volume and stores the second
    for AST_'s "incompatible request". }
  file_$object_is_remote = 16#000F0002;
  file_$incompatible_request = 16#000F0015;

  { 16#000F0006, "object is in use", and 16#000F0007, "illegal lock
    request" (stcode.db.10.2, OS / file server): file_$delete_int stores
    the first for a locked object without the force bit,
    FILE_$CHANGE_LOCK_D the second for a mode in
    file_$lock_illegal_mask. }
  file_$object_in_use = 16#000F0006;
  file_$illegal_lock_request = 16#000F0007;

  { 16#000F0004, "communications problem with remote node", 16#000F0005,
    "object is not locked by this process", and 16#000F0009, "local lock
    table is full" (stcode.db.10.2, OS / file server): FILE_$PRIV_LOCK
    tests the first after a remote lock and the second after
    FILE_$READ_LOCK_ENTRYUI, and stores the third when the table is full
    (also priv_lock_alloc_entry). }
  file_$comms_problem_with_remote_node = 16#000F0004;
  file_$object_not_locked_by_this_process = 16#000F0005;
  file_$local_lock_table_full = 16#000F0009;

  { 16#000F000C, "no more lock table entries" (stcode.db.10.2, OS / file
    server); the name misdescribes it ("not locked by
    this process (alt)"): FILE_$READ_LOCK_ENTRYI seeds its status with
    it at each pass. }
  file_$obj_not_locked_by_this_process = 16#000F000C;

{ FILE_$CREATE_IT - create an object of a given type, types 0, 4 and 5
  only. }
function file_$create_it(in file_type: integer; in type_uid: uid_$t;
                         in dir_uid: uid_$t; in size: integer32;
                         var file_uid_ret: uid_$t;
                         out status_ret: status_$t): boolean;
  extern;

{ FILE_$DELETE_OBJ - delete an object, forced or not, through the
  common delete. }
procedure file_$delete_obj(in file_uid: uid_$t; force: boolean;
                           out result: boolean;
                           out status_ret: status_$t);
  options(extern, val_param);

{ FILE_$DELETE_FORCE - delete an object (the same flags as FILE_$DELETE). }
function file_$delete_force(in file_uid: uid_$t;
                            out status_ret: status_$t): boolean;
  extern;

{ FILE_$MK_PERMANENT - make an object permanent: nothing to do, ok.
  FILE_$MK_TEMPORARY - make an object temporary: nothing to do, ok. }
procedure file_$mk_permanent(in file_uid: uid_$t; out status_ret: status_$t);
  extern;
procedure file_$mk_temporary(in file_uid: uid_$t; out status_ret: status_$t);
  extern;

{ FILE_$SET_AUDITED - set an object's audit flags, for an audit
  administrator.
  FILE_$SET_TROUBLE - mark an object as in trouble.
  FILE_$SET_MAND_LOCK - set or clear an object's mandatory-lock flag. }
procedure file_$set_audited(in file_uid: uid_$t; in audit_flag: boolean;
                            in audit_flag2: boolean;
                            out status_ret: status_$t);
  extern;
procedure file_$set_trouble(in file_uid: uid_$t; in unused: integer32;
                            out status_ret: status_$t);
  extern;
procedure file_$set_mand_lock(in file_uid: uid_$t; in flag: boolean;
                              out status_ret: status_$t);
  extern;

{ FILE_$SET_ACL - set an object's protection from an ACL UID. }
procedure file_$set_acl(in file_uid: uid_$t; acl_uid: uid_$t;
                        out status_ret: status_$t); extern;

{ FILE_$SET_DTM_F - set an object's time of last modification. }
procedure file_$set_dtm_f(in file_uid: uid_$t; in flags: boolean;
                          in time_value: time_$clock_t;
                          out status_ret: status_$t); extern;

{ FILE_$SET_DTM - set an object's time of last modification, whole. }
procedure file_$set_dtm(in file_uid: uid_$t; in time_value: time_$clockh_t;
                        out status_ret: status_$t); extern;

{ FILE_$SET_DTU_F - set an object's time of last use. }
procedure file_$set_dtu_f(in file_uid: uid_$t; in time_value: time_$clock_t;
                          out status_ret: status_$t); extern;

{ FILE_$SET_DTU - set an object's time of last use from a high part. }
procedure file_$set_dtu(in file_uid: uid_$t; in time_value: time_$clockh_t;
                        out status_ret: status_$t); extern;

{ FILE_$SET_DEVNO - set an object's device number. }
procedure file_$set_devno(in file_uid: uid_$t; in devno: integer;
                          out status_ret: status_$t); extern;

{ FILE_$SET_MGR_ATTR - set an object's type manager attribute. }
procedure file_$set_mgr_attr(in file_uid: uid_$t; in mgr_attr: uid_$t;
                             in version: integer;
                             out status_ret: status_$t); extern;

{ FILE_$SET_REFCNT - set an object's reference count, deleting it at 0. }
procedure file_$set_refcnt(in file_uid: uid_$t; refcnt: linteger;
                           out status_ret: status_$t); extern;


{ FILE_$NEIGHBORS - whether two objects are neighbors (on one volume). }
function file_$neighbors(file_uid1: uid_$t; file_uid2: uid_$t;
                         out status_ret: status_$t): boolean; extern;

{ FILE_$PURIFY - write an object's modified pages back. }
procedure file_$purify(in file_uid: uid_$t; out status_ret: status_$t);
  extern;

{ FILE_$FW_PARTIAL - force-write a byte range of an object. }
procedure file_$fw_partial(in file_uid: uid_$t; in start_offset: linteger;
                           in length: integer32;
                           out status_ret: status_$t); extern;

type
  { The page list FILE_$FW_PAGES takes, 1-based longwords, its length a
    pinteger count; linteger as the batch it is copied into, which is
    compared unsigned.  The bound is the count's range. }
  file_$page_list_t = array[1..65535] of linteger;

{ FILE_$FW_PAGES - force-write a list of an object's pages. }
procedure file_$fw_pages(in file_uid: uid_$t;
                         in page_list: file_$page_list_t;
                         in page_count: pinteger;
                         out status_ret: status_$t); extern;

{ FILE_$LOCK_D - lock an object for the calling address space, keeping
  the caller's per-process slot.
  FILE_$CHANGE_LOCK_D - change the mode of an object's lock held by the
  calling address space. }
procedure file_$lock_d(in file_uid: uid_$t; in lock_index: integer;
                       in lock_mode: integer; in rights: boolean;
                       in out slot_io: integer32;
                       out status_ret: status_$t); extern;
procedure file_$change_lock_d(in file_uid: uid_$t; in lock_index: integer;
                              in lock_mode: integer;
                              in out slot_io: integer32;
                              out status_ret: status_$t); extern;

{ FILE_$DELETE_WHEN_UNLOCKED - delete an object (FILE_$DELETE's code).
  FILE_$DELETE_FORCE_WHEN_UNLOCKED - delete an object (FILE_$DELETE's
  code again).
  FILE_$REMOVE_WHEN_UNLOCKED - delete an object and hand back the
  delete's result byte. }
function file_$delete_when_unlocked(in file_uid: uid_$t;
                                    out status_ret: status_$t): boolean;
  extern;
function file_$delete_force_when_unlocked(in file_uid: uid_$t;
                                          out status_ret: status_$t):
  boolean; extern;
procedure file_$remove_when_unlocked(in file_uid: uid_$t;
                                     out result: boolean;
                                     out status_ret: status_$t); extern;

{ FILE_$UNLOCK_D - release a lock by its slot for the calling address
  space. }
function file_$unlock_d(in file_uid: uid_$t; in lock_index: integer32;
                        in lock_mode: integer;
                        out status_ret: status_$t): boolean; extern;

type
  { The record FILE_$READ_LOCK_ENTRYUI fills, as FILE_$PRIV_LOCK gives
    it: 0x28 bytes in its frame.  Settled below, after the two types it
    needs. }

  { Two longwords of a lock object table entry (+0x04, +0x08: node_low
    and node_high), which FILE_$LOCAL_READ_LOCK copies whole into the
    lock record's holder (a record assignment): one
    8-byte record type for both (file/file.pas file_$lot_entry_t's
    node). }
  file_$lot_node_t = record
    node_low: integer32;                  { 0x00 }
    node_high: integer32;                 { 0x04 }
  end;

  { The first 26 bytes of the lock record, as FILE_$READ_LOCK_ENTRYU
    hands them to its caller: copied byte by byte, a character array's
    copy. }
  file_$lock_user_t = array[1..26] of char;

  { The lock record: 0x22 bytes, the size of FILE_$READ_LOCK_ENTRYUI's
    copy to its caller, eight longwords and a word, and of
    REM_FILE_$LOCAL_READ_LOCK's.  FILE_$LOCAL_READ_LOCK fills it: the UID
    (+0x00, a record copy), context (+0x08), side and mode (+0x10, +0x12,
    the entry's packed fields widened), sequence (+0x14), then
    owner_node (+0x0C), holder (+0x16, the node pair or NODE_$ME and the
    port word) and remote_info (+0x1E) by the entry's remote bit.  Its
    second view is the 26 bytes FILE_$READ_LOCK_ENTRYU passes on.  Its
    users priv_lock.pas, priv_unlock.pas and rem_file/rem_file.ins.pas
    only pass it.  The callers' frames give it 0x28 bytes: an object of
    8 bytes or more 8-aligned, 0x22 rounded to 0x28.  A dpc
    probe gives context 0x08, owner_node 0x0C, side 0x10, mode 0x12,
    sequence 0x14, holder 0x16, remote_info 0x1E, the size 0x22. }
  file_$lock_info_t = record
    case integer of
      1: (file_uid: uid_$t;               { 0x00 }
          context: integer32;             { 0x08 }
          owner_node: integer32;          { 0x0C }
          side: integer;                  { 0x10 }
          mode: integer;                  { 0x12 }
          sequence: integer;              { 0x14 }
          holder: file_$lot_node_t;       { 0x16: holder_node, holder_port }
          remote_info: integer32);        { 0x1E }
      2: (user: file_$lock_user_t);       { 0x00, 26 bytes }
  end;

{ FILE_$IMPORT_LK - check a lock slot the caller names against an object. }
procedure file_$import_lk(in file_uid: uid_$t; in index_in: linteger;
                          out index_out: linteger;
                          out status_ret: status_$t); extern;

{ FILE_$READ_LOCK_ENTRYU - the lock record of an object, for a user. }
procedure file_$read_lock_entryu(in file_uid: uid_$t;
                                 out info_out: file_$lock_user_t;
                                 out status_ret: status_$t); extern;

{ FILE_$READ_LOCK_ENTRYUI - the lock record of an object, wherever its
  lock is held. }
procedure file_$read_lock_entryui(in file_uid: uid_$t;
                                  out info: file_$lock_info_t;
                                  out status_ret: status_$t); extern;

{ FILE_$LOCAL_READ_LOCK - read the local lock table's record of an
  object's lock. }
procedure file_$local_read_lock(in file_uid: uid_$t;
                                out info: file_$lock_info_t;
                                out status_ret: status_$t); extern;

{ FILE_$LOCATE - the node an object lives on. }
procedure file_$locate(file_uid: uid_$t; out location_out: integer32;
                       out status_ret: status_$t); extern;

{ FILE_$LOCAL_LOCK_VERIFY - whether this node's lock table holds a lock
  that a lock record describes. }
procedure file_$local_lock_verify(in request: file_$lock_info_t;
                                  out status_ret: status_$t); extern;

{ FILE_$READ_LOCK_ENTRY - the next lock of a volume or address space, as
  the caller's 26 bytes. }
procedure file_$read_lock_entry(file_uid: uid_$t; in out index: pinteger;
                                out info_out: file_$lock_user_t;
                                out status_ret: status_$t); extern;

{ FILE_$READ_LOCK_ENTRYI - the next lock of a volume or of an address
  space, as a lock record. }
procedure file_$read_lock_entryi(file_uid: uid_$t; in out index: pinteger;
                                 out info_out: file_$lock_info_t;
                                 out status_ret: status_$t); extern;

{ FILE_$PRIV_UNLOCK_ALL - release every lock of one address space, or of
  all of them. }
procedure file_$priv_unlock_all(in asid: integer); extern;

{ FILE_$UNLOCK_VOL - release every lock on a volume's objects. }
procedure file_$unlock_vol(vol_uid: uid_$t; out status_ret: status_$t);
  extern;

{ FILE_$FORCE_UNLOCK - release a remote node's lock on a local object. }
procedure file_$force_unlock(file_uid: uid_$t; out status_ret: status_$t);
  extern;

{ FILE_$UNLOCK_PROC - release a process's locks on an object. }
procedure file_$unlock_proc(in proc_uid: uid_$t; in file_uid: uid_$t;
                            in lock_mode: integer; in param_4: integer32;
                            out status_ret: status_$t);
  extern;

{ FILE_$SET_LEN_D - set an object's length, with a lock context. }
procedure file_$set_len_d(in file_uid: uid_$t; in new_length: integer32;
                          in domain_ctx: linteger;
                          out status_ret: status_$t);
  extern;

{ FILE_$TRUNCATE_D - truncate an object, with a lock context. }
procedure file_$truncate_d(in file_uid: uid_$t; in new_size: integer32;
                           in domain_ctx: linteger;
                           out status_ret: status_$t);
  extern;

type
  { FILE_$GET_SEG_MAP's 32-bit segment bitmap: cleared, and or-ed with
    a one-member set, member k bit k. }
  file_$seg_bits_t = set of 0..31;

{ FILE_$GET_SEG_MAP - which of an object's segments are mapped. }
procedure file_$get_seg_map(file_uid: uid_$t; in start_off: integer32;
                            in flags_in: boolean;
                            out bitmap_out: file_$seg_bits_t;
                            out status_ret: status_$t);
  extern;

{ FILE_$EXPORT_LK - hand one of this process's locks to another process. }
procedure file_$export_lk(in file_uid: uid_$t; in lock_index: linteger;
                          in target_proc: uid_$t;
                          out index_out: integer32;
                          out status_ret: status_$t);
  extern;

{ FILE_$FORK_LOCK - give a forked process its parent's locks. }
procedure file_$fork_lock(in new_asid: integer; out status_ret: status_$t);
  extern;

{ FILE_$RESERVE - reserve disk space for a range of an object. }
procedure file_$reserve(file_uid: uid_$t; start_byte: integer32;
                        byte_count: integer32; out status_ret: status_$t);
  extern;

{ FILE_$UNLOCK_ALL - release every lock of the current process. }
procedure file_$unlock_all; extern;

{ FILE_$INVALIDATE - discard an object's cached pages in a range. }
procedure file_$invalidate(file_uid: uid_$t; start_page: linteger;
                           page_count: integer32; flags: boolean;
                           out status_ret: status_$t);
  extern;


{ 16#000F000A, "remote lock table is full" (stcode.db.10.2, the FILE_
  manager's; the name is the text's): REM_FILE_$SERVER reports a local
  FILE_$PRIV_LOCK's file_$local_lock_table_full to the requester as it. }
const
  file_$remote_lock_table_full = 16#000F000A;

type
  { A UID's words and halves, as the protection routines read them
    (acl/acl.pas acl_$uid_view_t's form and names): the low half's high
    word masked and shifted for the ACL kind (FILE_$SET_PROT;
    FILE_$SET_ACL on its copy); the low half as a set, members 24..27
    removed by masking its first byte (FILE_$SET_PROT; vtoc/vtoc.ins.pas
    vtoc_$uid_view_t's form); the first byte as a number
    (FILE_$SET_PROT_INT); b1, the second byte as a number, compared with
    DISKLESS_$UID's (FILE_$LOCATEI), in view 3 (an odd offset of a
    [byte] subrange). }
  file_$uid_view_t = record
    case integer of
      1: (uid: uid_$t);
      2: (w0: integer;                    { 0x00 }
          w1: integer;                    { 0x02 }
          w2: pinteger;                   { 0x04 }
          w3: integer);                   { 0x06 }
      3: (b0: file_$byte_t;               { 0x00 }
          b1: file_$byte_t);              { 0x01 }
      4: (high_set: set of 0..31;         { 0x00 }
          low_set: set of 0..31);         { 0x04 }
  end;
