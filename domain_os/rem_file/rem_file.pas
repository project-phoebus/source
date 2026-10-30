{ rem_file/rem_file.pas - the REM_FILE module, the remote file manager:
  the client stubs that send FILE_, AST_, ACL_, AREA_ and NAME_ requests
  to another node, the one transport they share, and the server that
  answers them.

  Image addresses:
    sau2  0x00E823FC  REM_FILE data (.DATA, 0xC bytes)
    sau2  0x00E2E380  REM_FILE_$DATA (its own data section, 0x7C bytes)

  One compilation unit, one code segment, one data segment, and a named
  data section of its own: the map's REM_FILE code segment in .TEXT
  (0x35C0 bytes, REM_FILE_$RN_DO_OP .. REM_FILE_$SERVER), its REM_FILE
  data segment in .DATA (0xC bytes, REM_FILE_$COMPLETION_TIME inside),
  and the section REM_FILE_$DATA, a load section with no module segment.

  The heading names no section: the block's objects are module variables
  (one is a map symbol), in .DATA; the code takes the default, .TEXT.

  The .DATA block, 0xC bytes:
    +0x00  rem_file_$stale_link_count  integer32, zero
    +0x04  rem_file_$busy_retry_count  integer32, zero
    +0x08  REM_FILE_$COMPLETION_TIME   pinteger, 16#14 (defined)
    +0x0A  (2 bytes: the block's rounding to 4)

  The section REM_FILE_$DATA, 0x7C bytes, in the image's wired data,
  with initial bytes: a named section with initialized variables (ref
  3.14 p. 3-52; 7.2.4, Method 4), `var (rem_file_$data)':

    +0x00  rem_file_$pkt_info      0x1E bytes, the client's packet-info
                                   template
    +0x1E  rem_file_$server_pkt_info 0x1E bytes: the same but 16#20 in
                                   its first word (REM_FILE_$SERVER)
    +0x3C  rem_file_$diskless_crash_msg 64 chars (REM_FILE_$SERVER)

  The map names only the section, so the first variable is
  rem_file_$pkt_info.

  Routines: the map symbols are globals, REM_FILE_$SEND_REQUEST
  module-local (`internal'), the eight REM_FILE_$SERVER helpers nested
  in it.  The routines live in one fragment file each
  (rem_file/<name>.pas), included below in image order.

  Build: dpc -I domain_os domain_os/rem_file/rem_file.pas.  Check:
  tools/pascal_check.sh.
}
module rem_file;

{ TODO(pascal) REM_FILE_'s frames against their locals

  Frame bytes no declared object explains, by routine:
  - rem_file_$send_request: 0x40 bytes above its cleanup record and 12
    bytes below it, held by the stand-ins unused_70 and unused_94
    (fim/fim.ins.pas's fim_$cleanup_rec_t is 0x18 bytes; an 88-byte
    cleanup record would fill them; which holds is not known), and 4
    bytes open, perhaps the slot of a register-held local;
  - REM_FILE_$RN_DO_OP: 18 bytes open: the register-held extra_ptr and
    bulk_ptr explain 8 if each keeps a slot;
  - REM_FILE_$CREATE_TYPE: the 0x28 bytes above its reply, which no
    instruction addresses, held by the stand-in unused_28 (every other
    client's reply is at the frame's top);
  - REM_FILE_$UNLOCK: 6 bytes open (the register-held dts_flags may keep
    2 of them).  The other client routines' frames are exact under an
    8-byte alignment (the 0xBE-byte reply in a 0xC0 place);
  - REM_FILE_$SERVER's nested helpers: server_drop_link: 0x48 bytes, 0x10 more
    bytes open, exactly server_get_entry_sids's saved_proj_list and
    proj_count places in a frame of the same size;
    server_truncate_delete: 8 bytes open; server_generate_uid: 4 and 8
    bytes open; server_set_prot_attrib: 4, 4 and 12 bytes open (its four
    register-held locals, if each keeps a slot);
  - REM_FILE_$SERVER: the 0x40 bytes below its receive record, which no
    instruction addresses, held by the stand-in unused_70
    (rem_file_$send_request's frame has the same 0x40 bytes at the same
    place); 20 bytes open: the register-held holds_lock, holds_netbuf,
    extra_len, peer_node and bulk if each keeps a slot; the lock
    record's 6 bytes over are its 8-alignment. }

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
%include 'ast/ast_acl.ins.pas';
%include 'file/file_prot.ins.pas';
%include 'audit/audit.ins.pas';
%include 'os/os.ins.pas';
%include 'fim/fim.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'ring/ring.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'xns/xns.ins.pas';
%include 'app/app.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'bat/bat.ins.pas';
%include 'name/name.ins.pas';
%include 'hint/hint.ins.pas';
%include 'volx/volx.ins.pas';
%include 'dir/dir.ins.pas';
%include 'rem_file/rem_file.ins.pas';
%include 'area/area.ins.pas';
%include 'dir/dir_server.ins.pas';

type
  { The packet-info template REM_FILE_$SEND_REQUEST and REM_FILE_$SERVER
    hand PKT_$SEND_INTERNET (`univ' pkt_info, pkt/pkt.ins.pas
    pkt_$info_t's first 0x1E bytes, its names), 0x1E bytes: the two lie
    0x1E apart in REM_FILE_$DATA, so the record stops before
    pkt_$info_t's pad_1e (asknode/asknode.pas asknode_$template_t's
    shape). }
  rem_file_$pkt_template_t = record
    flags: pinteger;                      { 0x00 }
    routing_type: integer;                { 0x02 }
    addr_type: integer;                   { 0x04 }
    protocol: pinteger;                   { 0x06 }
    retry_limit: pinteger;                { 0x08 }
    field_0a: pinteger;                   { 0x0A }
    field_0c: pinteger;                   { 0x0C }
    addr: array[1..16] of char;           { 0x0E }
  end;

  { A frame copy of the template with its flags word as a set as well:
    REM_FILE_$UNLOCK_ALL copies REM_FILE_$DATA's first template into its
    frame and sets member 7 of the flags, the form of a word set's
    member where the template's flags are a pinteger. }
  rem_file_$pkt_view_t = record
    case integer of
      1: (tmpl: rem_file_$pkt_template_t);  { 0x00 }
      2: (flags_set: set of 0..15);       { 0x00 }
  end;

  { (rem_file_$request_hdr_t, rem_file_$response_t and rem_file_$rn_op_
    buf_t, the request and reply heads, are rem_file/rem_file.ins.pas's:
    REM_FILE_$RN_DO_OP's heading takes them.) }

  { A request the client routines build in their frames, 0xB0 bytes:
    every one of them keeps it 0xB0 bytes below its reply (REM_FILE_
    $CREATE_TYPE with its reply lower, REM_FILE_$UNLOCK_ALL 0xB0 below
    its template), whatever length it sends (0xC .. 0xA2): one request
    type for the module, the variants by operation.  The header at 0x00
    (the message type, the constant byte 16#80, the opcode:
    rem_file/rem_file.ins.pas rem_file_$request_hdr_t) and the object's
    UID at 0x04 are common to all.  Probed with dpc. }
  { An old-format directory entry's UID and extra longword as one
    12-character array (dir/dir.ins.pas dir_$old_entry_t's bytes
    0x02..0x0D): REM_FILE_$SERVER's server_get_entry copies them from
    DIR_$GET_ENTRYU's entry into the reply one byte at a time, the copy
    of a 12-byte array of char (the form of dir/old_dir.pas
    dir_$old_entry_view_t's, rem_name_$entry_data_t, which this module
    does not include). }
  rem_file_$entry_data_t = array[1..12] of char;
  { DIR_$GET_ENTRYU's entry with that array as a view (server_get_entry's
    local).  The names are dir_$old_entry_t's. }
  rem_file_$entry_view_t = record
    case integer of
      1: (entry: dir_$old_entry_t);       { 0x00 }
      2: (unused_00: integer;             { 0x00 }
          data: rem_file_$entry_data_t);  { 0x02 }
  end;
  rem_file_$flags_t = set of 0..15;
  rem_file_$req_t = record
    hdr: rem_file_$request_hdr_t;         { 0x00 }
    uid: uid_$t;                          { 0x04 }
    case integer of
      { CREATE_TYPE (16#7E): its second phase }
      1: (session_uid: uid_$t;            { 0x0C }
          type_uid: uid_$t;               { 0x14 }
          parent_uid2: uid_$t;            { 0x1C }
          owner: rem_file_$owner_info_t;  { 0x24 }
          create_size: integer32;         { 0x54 }
          create_type: integer;           { 0x58 }
          create_flags: integer);         { 0x5A }
      { CREATE_TYPE_PRESR10 (16#26) }
      2: (presr10_type: integer;          { 0x0C }
          presr10_version: integer;       { 0x0E }
          presr10_super: boolean;         { 0x10 }
          unused_11: char;                { 0x11 }
          presr10_index: integer;         { 0x12 }
          presr10_session: uid_$t);       { 0x14 }
      { TRUNCATE (16#08) }
      3: (trunc_flags: boolean;           { 0x0C }
          unused_0d: char;                { 0x0D }
          trunc_size: integer32;          { 0x0E }
          trunc_version: integer;         { 0x12 }
          trunc_super: boolean);          { 0x14 }
      { SET_ATTRIBUTE (16#04) }
      4: (attr_id: integer;               { 0x0C }
          attr_value: file_$attr_value_t);  { 0x0E }
      { LOCK (16#0A) and its extended form (16#84) }
      5: (lock_key: integer32;            { 0x0C }
          lock_node: integer32;           { 0x10 }
          lock_type: integer;             { 0x14 }
          lock_mode: integer;             { 0x16 }
          case integer of
            1: (lock_version: integer;    { 0x18 }
                lock_super: boolean;      { 0x1A }
                unused_1b: char;          { 0x1B }
                unused_1c: integer;       { 0x1C }
                lock_one: integer);       { 0x1E }
            2: (lock_flags: rem_file_$flags_t;  { 0x18 }
                ext_one: integer;         { 0x1A }
                ext_loc: file_$obj_loc_t; { 0x1C }
                ext_exsid: acl_$exsid_t;  { 0x3C }
                ext_wait: integer));      { 0xA0 }
      { UNLOCK (16#0C) }
      6: (unlock_rem_key: integer32;      { 0x0C }
          unlock_rem_node: integer32;     { 0x10 }
          unlock_mode: integer;           { 0x14 }
          unused_16: integer;             { 0x16 }
          unlock_version: integer;        { 0x18 }
          unlock_super: boolean;          { 0x1A }
          unused_1b_u: char;              { 0x1B }
          unlock_key: integer;            { 0x1C }
          unused_1e: integer;             { 0x1E }
          unlock_release: boolean);       { 0x20 }
      { UNLOCK_ALL (16#12) }
      7: (all_version: integer;           { 0x0C }
          all_super: boolean);            { 0x0E }
      { LOCAL_VERIFY (16#1A) }
      8: (verify_lock: file_$lock_info_t);  { 0x0C }
      9: (bytes_0c: array[16#0C..16#AF] of char);  { 0x0C }
      { GET_SEG_MAP (16#1E): the segment index, the version word, true,
        the caller's flag, the start in 1K units and the constant
        16#10020 }
      10: (seg_index: pinteger;           { 0x0C }
           seg_version: integer;          { 0x0E }
           seg_force: boolean;            { 0x10 }
           unused_11_s: char;             { 0x11 }
           seg_type: boolean;             { 0x12 }
           unused_13_s: char;             { 0x13 }
           seg_offset: linteger;          { 0x14 }
           seg_magic: integer32);         { 0x18 }
      { NAME_GET_ENTRYU (16#1C), 0xA2 bytes: the name, its length, the
        version word, the super-user flag, a zero word, the caller's
        current SIDs and project list and two zero longwords }
      11: (ent_name: name_$name_t;        { 0x0C }
           ent_name_len: pinteger;        { 0x2C }
           ent_version: integer;          { 0x2E }
           ent_super: boolean;            { 0x30 }
           unused_31_e: char;             { 0x31 }
           ent_zero_32: integer;          { 0x32 }
           ent_re_sids: acl_sid_block_t;  { 0x34 }
           ent_proj: acl_$proj_uids_t;    { 0x58 }
           ent_proj_count: integer;       { 0x98 }
           ent_zero_9a: integer32;        { 0x9A }
           ent_zero_9e: integer32);       { 0x9E }
      { NEIGHBORS (16#10): the second UID, the version word, the
        super-user flag }
      12: (nb_uid2: uid_$t;               { 0x0C }
           nb_version: integer;           { 0x14 }
           nb_super: boolean);            { 0x16 }
      { PURIFY (16#14): the flags, the page, the version word, the
        super-user flag }
      13: (pur_flags: pinteger;           { 0x0C }
           pur_page: integer;             { 0x0E }
           pur_version: integer;          { 0x10 }
           pur_super: boolean);           { 0x12 }
      { SET_DEF_ACL (16#18): the ACL's type and UID, the version word,
        true }
      14: (def_acl_type: uid_$t;          { 0x0C }
           def_acl_uid: uid_$t;           { 0x14 }
           def_version: integer;          { 0x1C }
           def_force: boolean);           { 0x1E }
      { INVALIDATE (16#20): the start, the count, the flag }
      15: (inv_start: integer32;          { 0x0C }
           inv_count: integer32;          { 0x10 }
           inv_flag: boolean);            { 0x14 }
      { RESERVE (16#7C): the start, the count }
      16: (res_start: integer32;          { 0x0C }
           res_count: integer32);         { 0x10 }
      { NAME_ADD_HARD_LINKU (16#22): the name, its length, the object's
        UID, the version word, true }
      17: (ahl_name: name_$name_t;        { 0x0C }
           ahl_name_len: pinteger;        { 0x2C }
           ahl_file_uid: uid_$t;          { 0x2E }
           ahl_version: integer;          { 0x36 }
           ahl_force: boolean);           { 0x38 }
      { DROP_HARD_LINKU (16#28): the name, its length, the flag, the
        version word, true }
      18: (dhl_name: name_$name_t;        { 0x0C }
           dhl_name_len: pinteger;        { 0x2C }
           dhl_flag: integer;             { 0x2E }
           dhl_version: integer;          { 0x30 }
           dhl_force: boolean);           { 0x32 }
      { CREATE_AREA (16#86), DELETE_AREA (16#88) and GROW_AREA (16#8A),
        0x1C bytes each: the size (CREATE's and GROW's), the caller id
        (CREATE's and DELETE's), the remote volume word (DELETE's and
        GROW's) and the commit (CREATE's and GROW's); +0x04..+0x0B and
        +0x16 never stored.  Named after the AREA callers' arguments the
        headings carry, prefixed `area_'. }
      19: (area_size: integer32;          { 0x0C }
           area_caller: integer32;        { 0x10 }
           area_volx: pinteger;           { 0x14 }
           unused_16_a: integer;          { 0x16 }
           area_commit: integer32);       { 0x18 }
      { ACL_IMAGE (16#64), 0x14 bytes: the flags word 5 and the ACL type
        byte }
      20: (img_flags: integer;            { 0x0C }
           img_type: boolean);            { 0x0E }
      { ACL_CREATE's second request (16#68), 0x48 bytes: the flags word 5,
        the protection record, the UID the first request returned }
      21: (acl_flags: integer;            { 0x0C }
           unused_0e_c: integer;          { 0x0E }
           acl_header: acl_$prot_data_t;  { 0x10 }
           unused_3c_c: integer32;        { 0x3C }
           acl_session: uid_$t);          { 0x40 }
      { ACL_SETIDS (16#6A), 0x40 bytes: the flags word 5, the SID block,
        the project list }
      22: (ids_flags: integer;            { 0x0C }
           unused_0e_s: integer;          { 0x0E }
           ids_sids: acl_sid_block_t;     { 0x10 }
           ids_owner: acl_proj_list_t);   { 0x34 }
      { ACL_CHECK_RIGHTS (16#6C), 0x7C bytes, and SET_ACL (16#66), 0xAA
        bytes: the flags word 5, the second flags word, the SID block and
        the project row, then CHECK_RIGHTS' mask and three bytes or
        SET_ACL's ACL UID, protection record and extra flags word }
      23: (chk_flags: integer;            { 0x0C }
           chk_flags2: integer;           { 0x0E }
           chk_sids: acl_sid_block_t;     { 0x10 }
           chk_perm: acl_$proj_uids_t;    { 0x34 }
           case integer of
             1: (chk_mask: integer32;     { 0x74 }
                 chk_check: boolean;      { 0x78 }
                 chk_flag2: boolean;      { 0x79 }
                 chk_flag3: boolean);     { 0x7A }
             2: (chk_acl_uid: uid_$t;     { 0x74 }
                 chk_header: acl_$prot_data_t;  { 0x7C }
                 chk_extra_flags: integer));    { 0xA8 }
      { FILE_SET_PROT (16#80), 0xA8 bytes: the subsystem flag byte, the
        attribute type word, the value, the extended SID (named after the
        heading's arguments, prefixed `fsp_') }
      24: (fsp_subsys: boolean;           { 0x0C }
           unused_0d_p: char;             { 0x0D }
           fsp_type: integer;             { 0x0E }
           fsp_value: file_$set_prot_rec_t;
                                          { 0x10: FILE_$SET_PROT_INT's
                                            value record (file/file_prot.ins.pas),
                                            whose second view the client fills }
           fsp_exsid: acl_$exsid_t);      { 0x44 }
      { FILE_SET_ATTRIB (16#82), 0xAC bytes: the options word, the
        attribute id, the rights word, the value, the extended SID (named
        after the heading's arguments, prefixed `fsa_') }
      25: (fsa_options: integer;          { 0x0C }
           fsa_attr_id: integer;          { 0x0E }
           unused_10_f: integer;          { 0x10 }
           fsa_rights: pinteger;          { 0x12 }
           fsa_value: file_$attr_value_t; { 0x14 }
           fsa_exsid: acl_$exsid_t);      { 0x48 }
  end;

  { A reply as the client routines receive it, 0xBE bytes (the size they
    hand REM_FILE_$SEND_REQUEST; 0xC0 in each frame): the head
    (rem_file/rem_file.ins.pas rem_file_$response_t: the status at 0x04),
    then by operation: a UID (CREATE_TYPE's first phase, PRESR10's); an
    object's attributes, location and key (CREATE_TYPE's second phase
    and the extended LOCK: +0x0C 0x90 bytes, +0x9C 0x20, +0xBC a word),
    the location's address part at +0xAC rewritten from the caller's; a
    clock (TRUNCATE); a lock handle and word (LOCK); the unlock's clocks
    and two booleans; a lock record (LOCAL_READ_LOCK).  Probed with
    dpc. }
  rem_file_$reply_t = record
    hdr: rem_file_$response_t;            { 0x00 }
    case integer of
      1: (reply_uid: uid_$t);             { 0x08 }
      2: (unused_08: integer32;           { 0x08 }
          reply_attrs: file_$attributes_t;  { 0x0C }
          case integer of
            1: (reply_loc: file_$obj_loc_t;   { 0x9C }
                reply_key: integer);      { 0xBC }
            2: (unused_9c: array[16#9C..16#AB] of char;  { 0x9C }
                reply_loc_addr: pkt_$net_addr_t));  { 0xAC }
      3: (reply_clock: time_$clock_t);    { 0x08 }
      4: (lock_handle: integer32;         { 0x08 }
          lock_word: pinteger);           { 0x0C }
      5: (dtv: time_$clock_t;             { 0x08 }
          unlock_result: boolean;         { 0x0E }
          attrs_valid: boolean;           { 0x0F }
          dtu: time_$clock_t);            { 0x10 }
      6: (reply_lock: file_$lock_info_t); { 0x08 }
      { GET_SEG_MAP: the segment bits (ast/ast.ins.pas ast_$seg_map_t) }
      7: (seg_bits: ast_$seg_map_t);      { 0x08 }
      { NAME_GET_ENTRYU: the entry's type word, its UID and extra
        longword, as the client reads them; the same reply as
        REM_FILE_$SERVER's server_get_entry builds it: the name's length
        and the name the server maps back to the network's case, and the
        UID and extra longword copied as one 12-byte array.  The client
        reads only the type, UID and extra.  Prefixed `ent_'. }
      8: (ent_type: integer;              { 0x08 }
          ent_name_len: integer;          { 0x0A }
          ent_name: name_$name_t;         { 0x0C }
          case integer of
            1: (ent_uid: uid_$t;          { 0x2C }
                ent_extra: integer32);    { 0x34 }
            2: (ent_data: rem_file_$entry_data_t));  { 0x2C }
      { NEIGHBORS: the answer }
      9: (nb_result: boolean);            { 0x08 }
      { CREATE_AREA: the area's handle (the result) and the packet
        size }
      10: (ca_handle: integer;            { 0x08 }
           ca_pkt_size: pinteger);        { 0x0A }
      { ACL_IMAGE: the image's length and its protection record;
        ACL_SETIDS: the changed flag, the SID block, the project list }
      11: (unused_08_i: integer;          { 0x08 }
           case integer of
             1: (img_len: integer;        { 0x0A }
                 img_header: acl_$prot_data_t);  { 0x0C }
             2: (ids_modified: boolean;   { 0x0A }
                 unused_0b_s: char;       { 0x0B }
                 ids_sids: acl_sid_block_t;     { 0x0C }
                 ids_owner: acl_proj_list_t));  { 0x30 }
      { ACL_CREATE's second reply: the new ACL's UID; ACL_CHECK_RIGHTS':
        the result }
      12: (unused_08_c: integer32;        { 0x08 }
           case integer of
             1: (acl_new_uid: uid_$t);    { 0x0C }
             2: (chk_result: integer32)); { 0x0C }
      { FILE_SET_PROT's and FILE_SET_ATTRIB's: the object's modification
        time, one clock }
      13: (unused_08_m: array[16#08..16#3F] of char;  { 0x08 }
           mtime: time_$clock_t);         { 0x40 }
  end;

  { The caller's object-location record (file/file.ins.pas
    file_$obj_loc_t) with its address part, the 8 bytes at 0x10, as one
    object: REM_FILE_$CREATE_TYPE and _$LOCK copy it whole into their
    replies, the form of an 8-byte record's assignment.  A view; the
    names network and node are pkt/pkt.ins.pas pkt_$net_addr_t's. }
  rem_file_$loc_view_t = record
    case integer of
      1: (loc: file_$obj_loc_t);          { 0x00 }
      2: (unused_00: array[16#00..16#0F] of char;  { 0x00 }
          addr: pkt_$net_addr_t);         { 0x10 }
  end;

  { REM_FILE_$SERVER's request, 0x298 bytes in its frame, and its reply,
    0x120 bytes (the request is received into it whole, the reply sent
    from it).  The wire forms are the clients' (rem_file_$req_t,
    rem_file_$reply_t, above, the first variants), with the server's own
    views of the SET_ATTRIBUTE request (16#04) as server_set_attribute
    reads it: the attribute value at +0x0E as a UID view (dir/dir.ins.pas
    dir_$uid_view_t's w2 and low_set, the forms of
    dir/write_def_prot.pas), and as a protection record and ACL UID, the
    11 longwords stored at +0x0E and the UID at +0x3A, the value's
    protection attribute (16#14) form; prefixed `sa_'.  Probed with dpc. }
  rem_file_$server_req_t = record
    case integer of
      1: (req: rem_file_$req_t);          { 0x00 }
      2: (sa_hdr: rem_file_$request_hdr_t;  { 0x00 }
          sa_uid: uid_$t;                 { 0x04 }
          sa_attr_id: integer;            { 0x0C }
          case integer of
            1: (sa_value: file_$attr_value_t);  { 0x0E }
            2: (sa_view: dir_$uid_view_t);  { 0x0E }
            3: (sa_prot: acl_$prot_data_t;  { 0x0E }
                sa_acl_uid: uid_$t));     { 0x3A }
      3: (bytes: array[16#000..16#297] of char);  { 0x00 }
      { DROP_HARD_LINKU as server_drop_link reads it (the client's `dhl_'
        fields, variant 18 of rem_file_$req_t): the UID, the name and its
        length, the flags word passed by address to
        DIR_$OLD_DROP_HARD_LINKU's `in dir_$drop_flags_t', the locksmith
        byte.  The flags are a set here, an integer in the client's
        view. }
      4: (dl_hdr: rem_file_$request_hdr_t;  { 0x00 }
          dl_uid: uid_$t;                 { 0x04 }
          dl_name: name_$name_t;          { 0x0C }
          dl_name_len: pinteger;          { 0x2C }
          dl_flags: dir_$drop_flags_t;    { 0x2E }
          dl_version: integer;            { 0x30 }
          dl_as_locksmith: boolean);      { 0x32 }
      { REM_FILE_$SERVER's own reads: GET_SEG_MAP's count and map size as
        two words, both zero-extended, where the client sends the
        longword seg_magic, and the extended lock's flags as a word or-ed
        with 2 (the client's lock_flags set); prefixed `sv_'. }
      5: (sv_hdr: rem_file_$request_hdr_t;  { 0x00 }
          sv_uid: uid_$t;                 { 0x04 }
          unused_0c_v: array[16#0C..16#17] of char;  { 0x0C }
          case integer of
            1: (sv_seg_count: pinteger;   { 0x18 }
                sv_map_size: pinteger);   { 0x1A }
            2: (sv_lock_flags: integer)); { 0x18 }
      { The two halves REM_FILE_$SERVER hands on whole: the DIR_
        operations (16#2A..16#5C) as DIR_$SERVER takes them (dir/
        dir.ins.pas dir_$request_t: the netbuf fields it stores,
        add_link.target_ptr +0x92, resolve.path_ptr +0x8E and link_buf
        +0xAC, readu.buf_va +0x9A), and the ACL_ operations (16#64..16#77)
        as ACL_$SERVER takes them (acl/acl.ins.pas acl_$srv_req_t: buf
        +0x10, acl_data +0x3C). }
      6: (dir: dir_$request_t);           { 0x00 }
      7: (acl: acl_$srv_req_t);           { 0x00 }
  end;
  { The reply's views besides the clients': the DIR_ and ACL_ halves'
    replies (dir/dir.ins.pas dir_$reply_t, read for the bulk length:
    link_count +0x2E, size +0x1C, len +0x14; acl/acl.ins.pas
    acl_$srv_resp_t, ACL_$SERVER's `out resp'), and the words
    REM_FILE_$SERVER stores where the clients' variants have other
    fields: 1 at +0x08 for an extended lock, 1 at +0x0E for a plain one,
    the locked object's UID at +0x10 and CREATE_TYPE_PRESR10's index word
    there; prefixed `sv_'. }
  rem_file_$server_resp_t = record
    case integer of
      1: (reply: rem_file_$reply_t);      { 0x00 }
      2: (bytes: array[16#000..16#11F] of char);  { 0x00 }
      3: (dir: dir_$reply_t);             { 0x00 }
      4: (acl: acl_$srv_resp_t);          { 0x00 }
      5: (sv_hdr: rem_file_$response_t;   { 0x00 }
          sv_one_08: integer;             { 0x08 }
          unused_0a_v: integer;           { 0x0A }
          unused_0c_v: integer;           { 0x0C }
          sv_one_0e: integer;             { 0x0E }
          case integer of
            1: (sv_uid_10: uid_$t);       { 0x10 }
            2: (sv_index_10: integer));   { 0x10 }
  end;

  { REM_FILE_$SERVER's NETLOG word pair, 4 bytes: the operation's log
    code in the first byte, the receive record's queue count in the next
    four bits, merged unmasked, the requesting node in the low 20 bits,
    merged unmasked, and the two words NETLOG_$LOG_IT takes by value. }
  rem_file_$log_info_t = record
    case integer of
      1: (bits: packed record
            log_op: 0..255;               { bits 0..7 }
            qcount: 0..15;                { bits 8..11 }
            node: 0..16#FFFFF;            { bits 12..31 }
          end);
      2: (w0: integer;                    { 0x00 }
          w1: integer);                   { 0x02 }
  end;

const
  { The request header's constant byte and the version word most
    requests carry (REM_FILE_$TRUNCATE and the others store them). }
  rem_file_req_magic = 16#80;
  rem_file_req_version = 3;
  { (The operation codes are rem_file/rem_file.ins.pas's: ACL_$SERVER
    dispatches on the ACL_ ones too.) }
  { The flags word the ACL_ requests carry instead of the version word
    (REM_FILE_$ACL_IMAGE, _$ACL_CREATE, _$ACL_SETIDS, _$ACL_CHECK_RIGHTS,
    _$SET_ACL). }
  rem_file_acl_req_flags = 5;
  { The attribute ids FILE_$SET_PROT sends for its protection types
    (file/set_prot.pas: type 0 16#10, 1 16#11, 2 16#12, 3 16#15, 4 16#13,
    5 16#14, and 6, the ACL's UID, 3), which REM_FILE_$SERVER's
    server_set_prot_attrib maps back through its jump table (the targets
    of 3 and 16#10..16#15). }
  rem_file_prot_attr_acl = 16#03;
  rem_file_prot_attr_type0 = 16#10;
  rem_file_prot_attr_type1 = 16#11;
  rem_file_prot_attr_type2 = 16#12;
  rem_file_prot_attr_type4 = 16#13;
  rem_file_prot_attr_type5 = 16#14;
  rem_file_prot_attr_type3 = 16#15;
  { REM_FILE_$SERVER's dispatch beyond the clients' opcodes: its socket;
    the opcode a request of an unknown version is answered as; the two
    ranges it hands to DIR_$SERVER and ACL_$SERVER; (the four DIR_
    operations whose text or buffer travels as bulk data, 16#3C, 16#3E,
    16#42 and 16#58, are dir/dir.ins.pas's dir_op_add_linku, _read_linku,
    _dir_readu and _resolve); and the three codes
    only the log's table names (16#06, 16#0E, 16#62; the request
    REM_FILE_$SERVER truncates the object for when its reply cannot be
    sent is 16#06). }
  rem_file_server_socket = 2;
  rem_file_op_bad_version = 16#02;
  { The reply to it, and to any request REM_FILE_$SERVER does not know
    (its `otherwise' arm): request code plus 1 (rem_file_$response_t);
    REM_FILE_$RESERVE tests for it.  (name new) }
  rem_file_op_bad_version_reply = 16#03;
  rem_file_op_dir_first = 16#2A;
  rem_file_op_dir_last = 16#5C;
  rem_file_op_acl_first = 16#64;
  rem_file_op_acl_last = 16#77;
  rem_file_op_code_06 = 16#06;
  rem_file_op_code_0e = 16#0E;
  rem_file_op_code_62 = 16#62;

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above). }
var
  rem_file_$completion_time: extern pinteger;

var
  rem_file_$stale_link_count: integer32;          { +0x00, zero }
  rem_file_$busy_retry_count: integer32;          { +0x04, zero }

define
  rem_file_$completion_time := 16#14;             { +0x08 }

{ The section REM_FILE_$DATA (above), in the order of its offsets. }
var (rem_file_$data)
  rem_file_$pkt_info: rem_file_$pkt_template_t :=
    [flags := 16#10, routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long,
     protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
     field_0c := 16#FFFF];                        { +0x00; the address
                                                    zero }
  rem_file_$server_pkt_info: rem_file_$pkt_template_t :=
    [flags := 16#20, routing_type := pkt_$routing_inet,
     addr_type := pkt_$addr_long,
     protocol := 16#8031, retry_limit := 16#FFFF, field_0a := 0,
     field_0c := 16#FFFF];                        { +0x1E; the address
                                                    zero }
  rem_file_$diskless_crash_msg: array[1..64] of char :=
    '*** diskless partner node has crashed and rebooted - so must we%';
                                                  { +0x3C }

{ AST_$GET_ACL_ATTRIBUTES' heading is ast/ast_acl.ins.pas's (included
  above). }

{ FILE_$SET_PROT_INT's heading is file/file_prot.ins.pas's (included
  above), with its value record. }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  rem_file_$rn_do_op;
  rem_file_$create_type;
  rem_file_$create_type_presr10;
  rem_file_$truncate;
  rem_file_$set_attribute;
  rem_file_$lock;
  rem_file_$unlock_all;
  rem_file_$unlock;
  rem_file_$local_verify;
  rem_file_$local_read_lock;
  rem_file_$get_seg_map;
  rem_file_$name_get_entryu;
  rem_file_$neighbors;
  rem_file_$purify;
  rem_file_$set_def_acl;
  rem_file_$test;
  rem_file_$invalidate;
  rem_file_$reserve;
  rem_file_$name_add_hard_linku;
  rem_file_$drop_hard_linku;
  rem_file_$create_area;
  rem_file_$delete_area;
  rem_file_$grow_area;
  rem_file_$acl_image;
  rem_file_$acl_create;
  rem_file_$acl_setids;
  rem_file_$acl_check_rights;
  rem_file_$set_acl;
  rem_file_$file_set_prot;
  rem_file_$file_set_attrib;
  rem_file_$server;

{ ---- .TEXT ---- }
%include 'rem_file/send_request.pas';        { rem_file_$send_request }
%include 'rem_file/rn_do_op.pas';            { REM_FILE_$RN_DO_OP }
%include 'rem_file/create_type.pas';         { REM_FILE_$CREATE_TYPE }
%include 'rem_file/create_type_presr10.pas'; { REM_FILE_$CREATE_TYPE_PRESR10 }
%include 'rem_file/truncate.pas';            { REM_FILE_$TRUNCATE }
%include 'rem_file/set_attribute.pas';       { REM_FILE_$SET_ATTRIBUTE }
%include 'rem_file/lock.pas';                { REM_FILE_$LOCK }
%include 'rem_file/unlock_all.pas';          { REM_FILE_$UNLOCK_ALL }
%include 'rem_file/unlock.pas';              { REM_FILE_$UNLOCK }
%include 'rem_file/local_verify.pas';        { REM_FILE_$LOCAL_VERIFY }
%include 'rem_file/local_read_lock.pas';     { REM_FILE_$LOCAL_READ_LOCK }
%include 'rem_file/get_seg_map.pas';         { REM_FILE_$GET_SEG_MAP }
%include 'rem_file/name_get_entryu.pas';     { REM_FILE_$NAME_GET_ENTRYU }
%include 'rem_file/neighbors.pas';           { REM_FILE_$NEIGHBORS }
%include 'rem_file/purify.pas';              { REM_FILE_$PURIFY }
%include 'rem_file/set_def_acl.pas';         { REM_FILE_$SET_DEF_ACL }
%include 'rem_file/test.pas';                { REM_FILE_$TEST }
%include 'rem_file/invalidate.pas';          { REM_FILE_$INVALIDATE }
%include 'rem_file/reserve.pas';             { REM_FILE_$RESERVE }
%include 'rem_file/name_add_hard_linku.pas'; { REM_FILE_$NAME_ADD_HARD_LINKU }
%include 'rem_file/drop_hard_linku.pas';     { REM_FILE_$DROP_HARD_LINKU }
%include 'rem_file/create_area.pas';         { REM_FILE_$CREATE_AREA }
%include 'rem_file/delete_area.pas';         { REM_FILE_$DELETE_AREA }
%include 'rem_file/grow_area.pas';           { REM_FILE_$GROW_AREA }
%include 'rem_file/acl_image.pas';           { REM_FILE_$ACL_IMAGE }
%include 'rem_file/acl_create.pas';          { REM_FILE_$ACL_CREATE }
%include 'rem_file/acl_setids.pas';          { REM_FILE_$ACL_SETIDS }
%include 'rem_file/acl_check_rights.pas';    { REM_FILE_$ACL_CHECK_RIGHTS }
%include 'rem_file/set_acl.pas';             { REM_FILE_$SET_ACL }
%include 'rem_file/file_set_prot.pas';       { REM_FILE_$FILE_SET_PROT }
%include 'rem_file/file_set_attrib.pas';     { REM_FILE_$FILE_SET_ATTRIB }
%include 'rem_file/server.pas';              { REM_FILE_$SERVER, with its
                                               eight nested helpers }
