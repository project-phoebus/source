{ rem_file/rem_file.ins.pas - REM_FILE_ (the remote file manager's client
  side), for the Domain Pascal tree.

  Holds only what the Pascal files use.  Include base/base.ins.pas and
  acl/acl.ins.pas before it.  The headings are compiled routines of the
  REM_FILE module (rem_file/rem_file.pas).

  The `addr_info' every client takes is the first
  longword of the caller's location (a hint's, or the location record's
  loc_info): the body only passes its slot on to the module-local
  request sender.
}

{ REM_FILE_$ACL_SETIDS - have a remote node bring an ACL's SIDs up to
  date. }
procedure rem_file_$acl_setids(in addr_info: integer32;
                               in acl_uid: uid_$t;
                               in out sid_data: acl_sid_block_t;
                               in out owner_data: acl_proj_list_t;
                               out modified_flag_out: boolean;
                               out status: status_$t); extern;

{ REM_FILE_$ACL_CHECK_RIGHTS - evaluate a caller's rights to an object on
  the object's home node. }
procedure rem_file_$acl_check_rights(var addr_info: integer32;
                                     in sid_data: acl_sid_block_t;
                                     in perm_data: acl_$proj_uids_t;
                                     in file_uid: uid_$t;
                                     check_flag: boolean;
                                     access_mask: integer32;
                                     flags: integer;
                                     flag2: boolean;
                                     flag3: boolean;
                                     out result_out: integer32;
                                     out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$SET_ACL - set an object's ACL on the object's home node. }
procedure rem_file_$set_acl(var addr_info: integer32;
                            in file_uid: uid_$t;
                            in acl_uid: uid_$t;
                            in acl_header: acl_$prot_data_t;
                            in sid_data: acl_sid_block_t;
                            in perm_data: acl_$proj_uids_t;
                            flags: integer;
                            extra_flags: integer;
                            out status: status_$t);
  options(extern, val_param);

type
  { The 0x400-byte ACL image the remote ACL requests carry: the length
    the request sender is given for it by REM_FILE_$ACL_IMAGE and
    REM_FILE_$ACL_CREATE, an ACL cache slot's size. }
  rem_file_$acl_buf_t = array[1..1024] of char;

{ REM_FILE_$ACL_IMAGE - fetch an object's ACL image from its home node. }
procedure rem_file_$acl_image(var addr_info: integer32;
                              in file_uid: uid_$t;
                              acl_type: boolean;
                              var acl_image_out: univ rem_file_$acl_buf_t;
                              out acl_len_out: integer;
                              out acl_header_out: acl_$prot_data_t;
                              out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$ACL_CREATE - create an ACL object on a remote node. }
procedure rem_file_$acl_create(in addr_info: integer32;
                               in acl_data: univ rem_file_$acl_buf_t;
                               in acl_header: acl_$prot_data_t;
                               in parent_uid: uid_$t;
                               out acl_uid_out: uid_$t;
                               out status: status_$t); extern;

{ REM_FILE_$CREATE_AREA - create an area on a remote (diskless partner)
  node. }
function rem_file_$create_area(in node: uid_$t; total_size: integer32;
                               total_commit: integer32;
                               caller_id: integer32; shared: boolean;
                               out local_volx: integer;
                               out status: status_$t): integer;
  options(extern, val_param);

{ REM_FILE_$DELETE_AREA - delete an area on a remote node. }
procedure rem_file_$delete_area(in node: uid_$t; remote_volx: pinteger;
                                caller_id: integer32;
                                out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$GROW_AREA - resize an area on a remote node. }
procedure rem_file_$grow_area(in node: uid_$t; remote_volx: pinteger;
                              size: linteger; commit: linteger;
                              out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$UNLOCK_ALL - tell every node to drop this node's locks. }
procedure rem_file_$unlock_all; extern;

{ REM_FILE_$FILE_SET_ATTRIB - set an object's attribute on the object's
  home node. }
procedure rem_file_$file_set_attrib(var addr_info: integer32;
                                    in file_uid: uid_$t;
                                    in value: file_$attr_value_t;
                                    attr_id: integer;
                                    in exsid: acl_$exsid_t;
                                    rights: pinteger; options: integer;
                                    out mtime_out: time_$clock_t;
                                    out status: status_$t);
  options(extern, val_param);

type
  { The owner information a new object is created with, 0x30 bytes: the
    creator's SIDs (0x24) and project list (0xC), as ACL_$GET_RE_ALL_SIDS
    writes them into FILE_$PRIV_CREATE's frame, and REM_FILE_$CREATE_TYPE
    copies them whole, 12 longwords.  FILE_$PRIV_CREATE copies the first
    24 bytes by bytes: a character array's assignment (dbuf/dbuf.ins.pas
    dbuf_$ident_t's form), so a second view.  Declared here, after
    acl/acl.ins.pas, which its fields need. }
  rem_file_$owner_info_t = record
    case integer of
      1: (sids: acl_sid_block_t;          { 0x00 }
          projs: acl_proj_list_t);        { 0x24 }
      2: (owner_bytes: array[1..24] of char);   { 0x00 }
  end;
  rem_file_$owner_info_ptr_t = ^rem_file_$owner_info_t;

{ REM_FILE_$CREATE_TYPE - create a typed object on the node that holds its
  parent. }
procedure rem_file_$create_type(in loc: file_$obj_loc_t;
                                file_type: integer;
                                in type_uid: uid_$t;
                                size: integer32; flags: integer;
                                in owner: rem_file_$owner_info_t;
                                out attrs: file_$attributes_t;
                                out new_loc: file_$obj_loc_t;
                                out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$CREATE_TYPE_PRESR10 - create an object on a pre-SR10 node. }
procedure rem_file_$create_type_presr10(in loc: file_$obj_loc_t;
                                        file_type: integer;
                                        is_dir: integer;
                                        out file_uid: uid_$t;
                                        out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$FILE_SET_PROT - set an object's protection on the object's
  home node. }
procedure rem_file_$file_set_prot(var addr_info: integer32;
                                  in file_uid: uid_$t;
                                  in value: file_$attr_value_t;
                                  attr_type: integer;
                                  in exsid: acl_$exsid_t;
                                  subsys_flag: boolean;
                                  out mtime_out: time_$clock_t;
                                  out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$NEIGHBORS - ask a node whether two objects lie on one volume. }
function rem_file_$neighbors(in addr_info: integer32; in uid1: uid_$t;
                             in uid2: uid_$t;
                             out status: status_$t): boolean; extern;

{ REM_FILE_$LOCK - lock an object on its home node. }
procedure rem_file_$lock(in out loc: file_$obj_loc_t; lock_mode: integer;
                         lock_type: integer; flags: integer;
                         wait_flag: integer; extended: boolean;
                         lock_key: integer32; var lock_key_out: integer;
                         out packet_id_out: integer;
                         var lock_result: file_$attributes_t;
                         out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$UNLOCK - release a lock held on an object's home node. }
function rem_file_$unlock(in location: file_$obj_loc_t;
                          unlock_mode: integer; rem_key: integer32;
                          lock_key: integer; rem_node: integer32;
                          release_flag: boolean;
                          out status: status_$t): boolean;
  options(extern, val_param);

{ REM_FILE_$LOCAL_READ_LOCK - read an object's lock record from another
  node. }
procedure rem_file_$local_read_lock(in addr_info: integer32;
                                    in file_uid: uid_$t;
                                    out lock_entry: file_$lock_info_t;
                                    out status: status_$t);
  extern;

{ REM_FILE_$LOCAL_VERIFY - ask a lock's holder node whether it still holds
  the lock. }
procedure rem_file_$local_verify(in addr_info: integer32;
                                 in lock_block: file_$lock_info_t;
                                 out status: status_$t);
  extern;


{ A request or reply buffer handed on by address, as REM_FILE_$RN_DO_OP
  takes DIR_$DO_OP's; the formals are `univ'. }
type
  rem_file_$op_buf_t = array[1..1024] of char;

{ The request and reply heads of the REM_FILE_ protocol and DIR_$DO_OP's
  request record as REM_FILE_$RN_DO_OP reads it.  Only base, uid and acl
  types: every includer of this file includes acl/acl.ins.pas before it.

  rem_file_$request_hdr_t, 4 bytes: the message type word
  REM_FILE_$SEND_REQUEST stamps (1), the constant byte 16#80 every
  builder stores, and the operation code, read zero-extended.

  rem_file_$response_t, 8 bytes: the word REM_FILE_$SEND_REQUEST
  compares with -1 (a busy server), the opcode, the server's status
  (REM_FILE_$RN_DO_OP tests its low word).

  rem_file_$rn_op_buf_t, 0x122 bytes: DIR_$DO_OP's request record, the
  SID blocks filled in place by ACL_$GET_RE_ALL_SIDS and
  ACL_$GET_PROJ_LIST, the subsystem bit (member 2 of the word at 0x20),
  and the per-opcode tail from 0x8E: the list's data address and length
  (pinteger), reply address (0xAC) and inline area (0xB0, its end 0x122
  the cap); the entry's destination offset and length (signed) and data
  address; the directory read's reply limit (compared unsigned:
  linteger) and address.  The addresses are integer32, converted where
  they are used (pkt/pkt.ins.pas, which not every includer has, holds
  the byte pointer type).  The second variant, bytes from 0, is the
  record as REM_FILE_$RN_DO_OP indexes it with the entry's offset.
  Probed with dpc: every offset above, size 0x122. }
type
  rem_file_$byte_t = [byte] 0..255;
  rem_file_$request_hdr_t = record
    msg_type: integer;                    { 0x00 }
    magic: rem_file_$byte_t;              { 0x02 }
    opcode: rem_file_$byte_t;             { 0x03 }
  end;
  rem_file_$response_t = record
    pkt_flag: integer;                    { 0x00 }
    magic: rem_file_$byte_t;              { 0x02 }
    opcode: rem_file_$byte_t;             { 0x03 }
    status: status_$t;                    { 0x04 }
  end;
  rem_file_$rn_op_buf_t = record
    case integer of
      1: (hdr: rem_file_$request_hdr_t;   { 0x00 }
          op_data: array[1..16] of char;  { 0x04 }
          subsys_ids: acl_prot_info_t;    { 0x14 }
          flags_20: set of 0..15;         { 0x20 }
          unused_22: array[1..6] of char; { 0x22 }
          sids: acl_sid_block_t;          { 0x28 }
          proj_list: acl_$proj_uids_t;    { 0x4C }
          proj_count: integer;            { 0x8C }
          case integer of
            1: (list_data_va: integer32;  { 0x8E }
                list_data_len: pinteger;  { 0x92 }
                unused_94: array[1..24] of char;
                                          { 0x94 }
                list_reply_va: integer32; { 0xAC }
                list_inline_data: array[1..114] of char);
                                          { 0xB0 }
            2: (entry_dest_off: integer;  { 0x8E }
                entry_data_len: integer;  { 0x90 }
                entry_data_va: integer32);{ 0x92 }
            3: (unused_8e: array[1..8] of char;
                                          { 0x8E }
                read_dir_reply_max: linteger;
                                          { 0x96 }
                read_dir_reply_va: integer32));
                                          { 0x9A }
      2: (bytes: array[0..289] of char);
                                          { 0x00 }
  end;

{ REM_FILE_$RN_DO_OP - send a directory operation to the node that holds
  the directory. }
procedure rem_file_$rn_do_op(var addr_info: integer32;
                             var op_buf: univ rem_file_$rn_op_buf_t;
                             base_len: integer; response_size: integer;
                             var response: univ rem_file_$response_t;
                             out received_len: integer);
  options(extern, val_param);

{ REM_FILE_$SET_DEF_ACL - set a directory's default ACL on its home node. }
procedure rem_file_$set_def_acl(in addr_info: integer32;
                                in dir_uid: uid_$t; in acl_type: uid_$t;
                                in acl_uid: uid_$t;
                                out status: status_$t); extern;

{ REM_FILE_$NAME_ADD_HARD_LINKU - add a hard link to a directory on
  another node. }
procedure rem_file_$name_add_hard_linku(var addr_info: integer32;
                                        in dir_uid: uid_$t;
                                        in name: univ name_$name_t;
                                        name_len: pinteger;
                                        in file_uid: uid_$t;
                                        out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$DROP_HARD_LINKU - drop a hard link from a directory on another
  node. }
procedure rem_file_$drop_hard_linku(var addr_info: integer32;
                                    in dir_uid: uid_$t;
                                    in name: univ name_$name_t;
                                    name_len: pinteger; flag: integer;
                                    out status: status_$t);
  options(extern, val_param);

var
  { REM_FILE_$SOCK_LOCK (map symbol in NETWORK's block, +0x240): an
    exclusion lock, 0x12 bytes to the next object; NETWORK_$REQUEST_SERVER
    initializes it (ML_$EXCLUSION_INIT).  network/network.pas's block
    defines it.  Every includer of this file includes ml/ml.ins.pas
    before it. }
  rem_file_$sock_lock: extern ml_$exclusion_t;

{ The REM_FILE_ request operation codes: each client's opcode store and
  REM_FILE_$SERVER's dispatch, and the ACL_ ones (16#64 .. 16#6C)
  ACL_$SERVER's `case' (acl/server.pas).  An insert's constants so that
  acl/acl.pas, which includes this file, names them too. }
const
  rem_file_op_test = 16#00;
  rem_file_op_set_attribute = 16#04;
  rem_file_op_truncate = 16#08;
  rem_file_op_lock = 16#0A;
  rem_file_op_unlock = 16#0C;
  rem_file_op_neighbors = 16#10;
  rem_file_op_unlock_all = 16#12;
  rem_file_op_purify = 16#14;
  rem_file_op_local_read_lock = 16#16;
  rem_file_op_set_def_acl = 16#18;
  rem_file_op_local_verify = 16#1A;
  rem_file_op_name_get_entryu = 16#1C;
  rem_file_op_get_seg_map = 16#1E;
  rem_file_op_invalidate = 16#20;
  rem_file_op_name_add_hard_linku = 16#22;
  rem_file_op_generate_uid = 16#24;
  rem_file_op_create_type_presr10 = 16#26;
  rem_file_op_drop_hard_linku = 16#28;
  rem_file_op_acl_image = 16#64;
  rem_file_op_set_acl = 16#66;
  rem_file_op_acl_create = 16#68;
  rem_file_op_acl_setids = 16#6A;
  rem_file_op_acl_check_rights = 16#6C;
  rem_file_op_reserve = 16#7C;
  rem_file_op_create_type = 16#7E;
  rem_file_op_file_set_prot = 16#80;
  rem_file_op_file_set_attrib = 16#82;
  rem_file_op_lock_ext = 16#84;
  rem_file_op_create_area = 16#86;
  rem_file_op_delete_area = 16#88;
  rem_file_op_grow_area = 16#8A;

{ REM_FILE_$SERVER - serve one remote file request. }
procedure rem_file_$server; extern;


{ REM_FILE_$TRUNCATE - truncate an object on its home node. }
procedure rem_file_$truncate(var addr_info: integer32; in uid: uid_$t;
                             new_size: integer32; flags: boolean;
                             out dtm_out: time_$clock_t;
                             out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$SET_ATTRIBUTE - set one attribute of an object on its home
  node. }
procedure rem_file_$set_attribute(var addr_info: integer32;
                                  in file_uid: uid_$t; attr_id: integer;
                                  in value: file_$attr_value_t;
                                  out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$GET_SEG_MAP - read an object's segment map from its home node. }
procedure rem_file_$get_seg_map(var addr_info: integer32;
                                in file_uid: uid_$t;
                                start_offset: linteger;
                                end_offset: linteger; type_flag: boolean;
                                out seg_map_out: ast_$seg_map_t;
                                out status: status_$t);
  options(extern, val_param);

type
  { The entry REM_FILE_$NAME_GET_ENTRYU hands back, 0xE bytes: the type
    word, the UID at +0x02, the extra longword at +0x0A (cleared or
    copied).  Its OLD_DIR caller passes dir/dir.ins.pas's
    dir_$old_entry_t, the same shape, to the `univ' formal: this file's
    includers need not include dir/dir.ins.pas. }
  rem_file_$name_get_entryu_result_t = record
    entry_type: integer;                  { 0x00 }
    entry_uid: uid_$t;                    { 0x02 }
    extra_info: integer32;                { 0x0A }
  end;

{ REM_FILE_$NAME_GET_ENTRYU - look a name up in a directory on another
  node. }
procedure rem_file_$name_get_entryu(var addr_info: integer32;
                                    in dir_uid: uid_$t;
                                    in name: univ name_$name_t;
                                    name_len: pinteger;
                                    out entry:
                                      univ rem_file_$name_get_entryu_result_t;
                                    out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$PURIFY - have an object's pages written out on its home node. }
procedure rem_file_$purify(var addr_info: integer32; in file_uid: uid_$t;
                           var flags: pinteger; page_index: integer;
                           out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$TEST - send a test request to a node. }
procedure rem_file_$test(in addr_info: integer32; out status: status_$t);
  extern;

{ REM_FILE_$INVALIDATE - invalidate a range of an object's pages on its
  home node. }
procedure rem_file_$invalidate(var addr_info: integer32;
                               in file_uid: uid_$t; start: integer32;
                               count: integer32; flag: boolean;
                               out status: status_$t);
  options(extern, val_param);

{ REM_FILE_$RESERVE - reserve disk space for an object on its home node. }
procedure rem_file_$reserve(var addr_info: integer32; in file_uid: uid_$t;
                            start: integer32; count: integer32;
                            out status: status_$t);
  options(extern, val_param);
