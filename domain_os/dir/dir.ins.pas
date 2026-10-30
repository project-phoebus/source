{ dir/dir.ins.pas - DIR_ (directories), for the Domain Pascal tree.

  The headings, types and globals of the DIR, OLD_DIR and DIR_SERVER
  modules that the Pascal files use.  No customer insert file declares
  these kernel entry points (Apollo's name.ins.pas has the user-level
  naming routines).  Include base/base.ins.pas before it.
}

{ DIR_$ADDU - add a name for an object to a directory. }
procedure dir_$addu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                    in name_len: integer; in file_uid: uid_$t;
                    out status_ret: status_$t);
  extern;

{ DIR_$SET_DAD - set a directory's parent pointer. }
procedure dir_$set_dad(in dir_uid: uid_$t; in parent_uid: uid_$t;
                       out status_ret: status_$t);
  extern;

{ DIR_$DROPU - drop a name from a directory. }
procedure dir_$dropu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                     in name_len: integer; out file_uid: uid_$t;
                     out status_ret: status_$t);
  extern;

{ DIR_$ADD_MOUNT - enter a mount in a directory's mount table.
  DIR_$DROP_MOUNT - remove a mount from a directory's mount table. }
procedure dir_$add_mount(in dir_uid: uid_$t; in mount_uid: uid_$t;
                         out status_ret: status_$t); extern;
procedure dir_$drop_mount(in mount_point_uid: uid_$t; in dir_uid: uid_$t;
                          in lv_num: integer32; out status_ret: status_$t);
  extern;

{ }

{ DIR_$INIT - build the directory lock and handle tables at boot. }
procedure dir_$init; extern;

type
  { The 14-byte entry DIR_$GET_ENTRYU hands back: the type word at 0x00,
    which name_$resolve_internal dispatches on (0, 1, 3), the UID at
    0x02, and a longword at 0x0A no Pascal reads (entry_type, as `type'
    is a reserved word). }
  dir_$old_entry_t = record
    entry_type: integer;                  { 0x00 }
    uid: uid_$t;                          { 0x02 }
    extra: integer32;                     { 0x0A }
  end;

{ DIR_$GET_ENTRYU - look an entry up by name in a directory. }
procedure dir_$get_entryu(dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          out entry: dir_$old_entry_t;
                          out status_ret: status_$t);
  extern;

{ DIR_$SET_ACL - set an object's ACL through its directory's server. }
procedure dir_$set_acl(in uid: uid_$t; in acl: uid_$t;
                       out status_ret: status_$t);
  extern;

{ DIR_$CLEANUP - release every directory handle the current process holds. }
procedure dir_$cleanup; extern;

{ DIR_$FIND_NET - the extra longword of a directory's entry for a node. }
function dir_$find_net(in dir_uid: uid_$t; in index: linteger): integer32;
  extern;

{ MAP_CASE - map a Unix-style pathname to its Domain/OS case-mapped form.
  UNMAP_CASE - map a Domain/OS case-mapped pathname back to its Unix form. }
procedure map_case(in name: univ name_$long_pname_t; in name_len: integer;
                   out output: univ name_$long_pname_t;
                   in max_out_len: integer; out out_len: integer;
                   out truncated: boolean);
  extern;
procedure unmap_case(in name: univ name_$long_pname_t; in name_len: integer;
                     out output: univ name_$long_pname_t;
                     in max_out_len: integer; out out_len: integer;
                     out truncated: boolean);
  extern;


{ }

{ DIR_$OLD_INIT - mark the processes as holding no old-format directory
  lock. }
procedure dir_$old_init; extern;


{ DIR_$DO_OP's operation codes, the request header's op byte each
  DIR_$<op>U wrapper stores and DIR_$DO_OP's `case' dispatches on
  (16#2A..16#5C; REM_FILE_$SERVER hands the same range to
  DIR_$SERVER).  dir_op_code_30 has no known name (DIR_$DO_OP's arm for
  it deletes an entry, with all three of dir_$do_op_delete's flags true;
  no wrapper in this image sends it). }
const
  dir_op_addu = 16#2A;
  dir_op_add_hard_linku = 16#2C;
  dir_op_drop_hard_linku = 16#2E;
  dir_op_code_30 = 16#30;
  dir_op_cnameu = 16#32;
  dir_op_add_baku = 16#34;
  dir_op_delete_fileu = 16#36;
  dir_op_create_diru = 16#38;
  dir_op_drop_diru = 16#3A;
  dir_op_add_linku = 16#3C;
  dir_op_read_linku = 16#3E;
  dir_op_drop_linku = 16#40;
  dir_op_dir_readu = 16#42;
  dir_op_get_entryu_op = 16#44;
  dir_op_find_uid = 16#46;
  dir_op_fix_dir = 16#48;
  dir_op_set_acl = 16#4A;
  dir_op_set_default_acl = 16#4C;
  dir_op_get_default_acl = 16#4E;
  dir_op_validate_root_entry = 16#50;
  dir_op_set_protection = 16#52;
  dir_op_set_def_protection = 16#54;
  dir_op_get_def_protection = 16#56;
  dir_op_resolve = 16#58;
  dir_op_add_mount = 16#5A;
  dir_op_drop_mount = 16#5C;

{ }

type
  { A byte read as an unsigned number (zero-extended): the request's
    operation code, a UID's first byte. }
  dir_$byte_t = [byte] 0..255;

  { A pointer to a text that a request carries by address (the link
    target of op 16#3C, the pathname of op 16#58): DIR_$DO_OP passes the
    pointer's value as the text's address. }
  dir_$text_ptr_t = ^name_$long_pname_t;

  { A UID and its first byte: DIR_$DO_OP tests the first byte of the
    reply's UID and of its own copy of the request's.  And its second
    word, unsigned, the start of dir_$get_entry_cached's hash (added to
    and reduced modulo 111 on its zero extension). }
  dir_$uid_view_t = record
    case integer of
      1: (uid: uid_$t);                   { 0x00 }
      2: (b0: dir_$byte_t);               { 0x00 }
      3: (w0: integer;                    { 0x00 }
          w1: pinteger;                   { 0x02 }
          w2: pinteger);                  { 0x04 }
      4: (high: linteger;                 { 0x00 }
          low: linteger);                 { 0x04 }
      5: (high_set: set of 0..31;         { 0x00 }
          low_set: set of 0..31);         { 0x04 }
  end;
  { The fourth variant, the two halves as unsigned longwords:
    dir_$do_op_validate_root_entry masks the low halves to 20 bits and
    compares the high halves unsigned.  The third variant's w2, the low
    half's high word, holds an ACL UID's type bits: dir_$write_def_prot,
    dir_$do_op_set_prot and DIR_$SET_PROTECTION extract them, the form
    acl/acl.pas acl_$uid_view_t's w2 (pinteger) has at
    ACL_$CONVERT_FUNKY_ACL.  The fifth variant, the two halves as sets:
    dir_$write_def_prot clears the low half's member 24,
    acl_$uid_view_t's high_set/low_set form.  The names are acl.pas's. }

  { A position in a pathname as dir_$do_op_resolve uses its resolution's
    current and last component starts (the state's param5 and param7):
    an index of the pathname with a word index register, where its scan
    index, a pinteger, is zero-extended to a longword one, and compared
    unsigned at 16 bits with the pathname's length, a pinteger: a
    non-negative subrange whose range times 1 fits a signed word.  The
    upper bound is not known (any of 1..32767 gives these forms). }
  dir_$path_index_t = 0..32767;

  { The 24 bytes a resolution carries from the request to the reply,
    which DIR_$DO_OP copies byte by byte: an array of char, and the
    fields the handler's other arguments name.  param5..param8 are
    dir_$do_op_resolve's cont, size, last_start and last_size: param5
    and param7 positions (dir_$path_index_t), param6 and param8 lengths,
    compared unsigned with 16#FF: pinteger; and the first UID as
    dir_$uid_view_t (start_view), which that routine hands to
    dir_$do_op_get_entryu's view. }
  dir_$resolve_state_t = record
    case integer of
      1: (start_uid: uid_$t;              { 0x00 }
          resolved_uid: uid_$t;           { 0x08 }
          param5: dir_$path_index_t;      { 0x10 }
          param6: pinteger;               { 0x12 }
          param7: dir_$path_index_t;      { 0x14 }
          param8: pinteger);              { 0x16 }
      2: (bytes: array[1..24] of char);   { 0x00 }
      3: (start_view: dir_$uid_view_t);   { 0x00 }
  end;

  { The operation bodies, from the request's +0x8E (DIR_$DO_OP's arms
    read them, each field's use in the arm's comment in dir/do_op.pas).
    The offsets are relative to the body. }
  dir_$req_name_t = record                { ops 16#30, 38, 3A, 40, 44, 50 }
    path_len: integer;                    { 0x00 (+0x8E) }
    name: name_$long_name_t;              { 0x02 (+0x90) }
  end;
  dir_$req_add_entry_t = record           { op 16#2A }
    path_len: integer;                    { 0x00 (+0x8E) }
    file_uid: uid_$t;                     { 0x02 (+0x90) }
    flags: integer32;                     { 0x0A (+0x98) }
    name: name_$long_name_t;              { 0x0E (+0x9C) }
  end;
  dir_$req_uid_name_t = record            { ops 16#2C, 34 }
    path_len: integer;                    { 0x00 (+0x8E) }
    target_uid: uid_$t;                   { 0x02 (+0x90) }
    name: name_$long_name_t;              { 0x0A (+0x98) }
  end;
  { The drop flags of operation 16#2E, a word set: DIR_$DROP_HARD_LINKU
    copies its caller's word into the request, DIR_$DO_OP's arm tests
    member 0, and DIR_$OLD_DROP_HARD_LINKU tests member 0 of the
    caller's word; a named type, so that the headings can take it. }
  dir_$drop_flags_t = set of 0..15;
  dir_$req_word_name_t = record           { op 16#2E }
    path_len: integer;                    { 0x00 (+0x8E) }
    flags: dir_$drop_flags_t;             { 0x02 (+0x90) }
    name: name_$long_name_t;              { 0x04 (+0x92) }
  end;
  dir_$req_cname_t = record               { op 16#32 }
    old_len: integer;                     { 0x00 (+0x8E) }
    new_len: integer;                     { 0x02 (+0x90) }
    name: name_$long_name_t;              { 0x04 (+0x92) }
  end;
  dir_$req_delete_file_t = record         { op 16#36 }
    path_len: integer;                    { 0x00 (+0x8E) }
    flag0: boolean;                       { 0x02 (+0x90) }
    flag1: boolean;                       { 0x03 (+0x91) }
    name: name_$long_name_t;              { 0x04 (+0x92) }
  end;
  dir_$req_add_link_t = record            { ops 16#3C, 3E }
    path_len: integer;                    { 0x00 (+0x8E) }
    target_len: integer;                  { 0x02 (+0x90) }
    target_ptr: dir_$text_ptr_t;          { 0x04 (+0x92) }
    name: name_$long_name_t;              { 0x08 (+0x96) }
  end;
  dir_$req_readu_t = record               { op 16#42 }
    continuation: integer32;              { 0x00 (+0x8E) }
    max_entries: integer32;               { 0x04 (+0x92) }
    max_size: linteger;                   { 0x08 (+0x96) }
    buf_va: univ_ptr;                     { 0x0C (+0x9A) }
    name_len: integer;                    { 0x10 (+0x9E) }
    name: name_$long_name_t;              { 0x12 (+0xA0) }
  end;
  dir_$req_find_uid_t = record            { op 16#46 }
    target_uid: uid_$t;                   { 0x00 (+0x8E) }
    flag: boolean;                        { 0x08 (+0x96) }
  end;
  dir_$req_uid_pair_t = record            { op 16#4C }
    acl_type_uid: uid_$t;                 { 0x00 (+0x8E) }
    acl_uid: uid_$t;                      { 0x08 (+0x96) }
  end;
  dir_$req_set_prot_t = record            { op 16#52 }
    prot: array[1..11] of integer32;      { 0x00 (+0x8E) }
    acl_uid: uid_$t;                      { 0x2C (+0xBA) }
    prot_type: integer;                   { 0x34 (+0xC2) }
  end;
  dir_$req_set_def_prot_t = record        { op 16#54 }
    acl_type_uid: uid_$t;                 { 0x00 (+0x8E) }
    prot: array[1..11] of integer32;      { 0x08 (+0x96) }
    acl_uid: uid_$t;                      { 0x34 (+0xC2) }
  end;
  { The last field is the caller's link-text buffer, not flags:
    DIR_$RESOLVE stores its by-address argument there, and
    dir_$do_op_resolve passes it on by value as dir_$do_op_read_linku's
    buffer, which receives the link text through it. }
  dir_$req_resolve_t = record             { op 16#58 }
    path_ptr: dir_$text_ptr_t;            { 0x00 (+0x8E) }
    path_len: integer;                    { 0x04 (+0x92) }
    state: dir_$resolve_state_t;          { 0x06 (+0x94) }
    link_buf: dir_$text_ptr_t;            { 0x1E (+0xAC) }
  end;
  dir_$req_mount_t = record               { ops 16#5A, 5C }
    mount_uid: uid_$t;                    { 0x00 (+0x8E) }
    node_id: integer32;                   { 0x08 (+0x96) }
  end;

  { A request to DIR_$DO_OP: the operation code at +0x03 and the
    directory's UID at +0x04, the words DIR_$DO_OP writes for a remote
    node at +0x0C and +0x10, the operation's version at +0x0E (passed by
    value to two handlers), the reply version at +0x12 (stored and
    compared), the caller's directory-lock flags at +0x20 (dir/dir.pas
    dir_$proc_flags_t's shape), REM_FILE_'s request header between them
    (REM_FILE_$RN_DO_OP fills +0x14.. and +0x28..), and the operation's
    body from +0x8E, raw (DIR_$DO_OP finds op 16#32's second name at a
    computed offset in it) or as one of the bodies above.  The callers'
    own request records are of their operations' sizes (DIR_$ADD_MOUNT's
    is 0x9A bytes), so DIR_$DO_OP takes this record `univ'. }
  dir_$request_t = record
    unused_00: array[1..3] of char;       { 0x00 }
    op: dir_$byte_t;                      { 0x03 }
    uid: uid_$t;                          { 0x04 }
    remote: integer;                      { 0x0C }
    version: integer;                     { 0x0E }
    unused_10: integer;                   { 0x10 }
    reply_version: integer;               { 0x12 }
    unused_14: array[1..12] of char;      { 0x14 }
    proc_flags: set of 0..15;             { 0x20 }
    unused_22: array[1..108] of char;     { 0x22 }
    case integer of
      1: (raw: array[0..515] of char);    { 0x8E }
      2: (name_body: dir_$req_name_t);    { 0x8E }
      3: (add_entry: dir_$req_add_entry_t);
      4: (uid_name: dir_$req_uid_name_t);
      5: (word_name: dir_$req_word_name_t);
      6: (cname: dir_$req_cname_t);
      7: (delete_file: dir_$req_delete_file_t);
      8: (add_link: dir_$req_add_link_t);
      9: (readu: dir_$req_readu_t);
      10: (find_uid: dir_$req_find_uid_t);
      11: (uid_body: uid_$t);
      12: (uid_pair: dir_$req_uid_pair_t);
      13: (set_prot: dir_$req_set_prot_t);
      14: (set_def_prot: dir_$req_set_def_prot_t);
      15: (resolve: dir_$req_resolve_t);
      16: (mount: dir_$req_mount_t);
  end;

  { DIR_$DO_OP's reply: the status at +0x04 (every handler's status
    argument), the remote reply's version words at +0x08 and +0x0A
    (tested for a remote reply, written for a local one), a word set at
    +0x12 (cleared; member 0 set for a remote reply), and the
    operation's results from +0x14, in the shapes the handlers' result
    arguments give:
      1: a UID (ops 16#2E, 30, 34, 36, 38, 40, 4E);
      2: a word, a UID and a longword (16#44; 16#3E the first two); the
         UID's first byte and low half tested for a remote reply, the
         longword passed on;
      3: a resolution (16#58): two booleans at +0x14 and +0x15, the 24
         bytes from the request at +0x16, the link count at +0x2E, a
         longword at +0x30 (passed on);
      4: a directory read (16#42): the continuation at +0x14 (from the
         request), then three longwords;
      5: a protection (16#56): 44 bytes at +0x14 and a UID at +0x40;
      6: a found entry (16#46): a length word at +0x14, a longword at
         +0x16, the name at +0x1A.
    `univ' in DIR_$DO_OP's heading, as the request. }
  dir_$reply_t = record
    unused_00: integer32;                 { 0x00 }
    status: status_$t;                    { 0x04 }
    version: integer;                     { 0x08 }
    reply_version: integer;               { 0x0A }
    unused_0c: array[1..6] of char;       { 0x0C }
    flags: set of 0..15;                  { 0x12 }
    case integer of
      1: (uid: uid_$t);                   { 0x14 }
      2: (len: integer;                   { 0x14 }
          entry: dir_$uid_view_t;         { 0x16 }
          extra: integer32);              { 0x1E }
      3: (more: boolean;                  { 0x14 }
          loop: boolean;                  { 0x15 }
          state: dir_$resolve_state_t;    { 0x16 }
          link_count: integer;            { 0x2E }
          redirect: integer32);           { 0x30 }
      4: (continuation: integer32;        { 0x14 }
          count: integer32;               { 0x18 }
          size: integer32;                { 0x1C }
          last_offset: integer32);        { 0x20 }
      5: (prot: array[1..11] of integer32;
                                          { 0x14 }
          def_acl: uid_$t);               { 0x40 }
      6: (name_len: integer;              { 0x14 }
          find_extra: integer32;          { 0x16 }
          name: array[1..32] of char);    { 0x1A }
      7: (uid_view: dir_$uid_view_t);     { 0x14 }
  end;
  { The seventh variant, the reply's UID as dir_$uid_view_t:
    dir_$do_op_get_default_acl sets a member of its low half's set. }

{ DIR_$DO_OP - carry out a directory operation, here or on the node that
  holds the directory. }
procedure dir_$do_op(var request: univ dir_$request_t; req_size: integer;
                     resp_size: integer; var response: univ dir_$reply_t;
                     var received_len: integer);
  options(extern, val_param);


{ }

type
  { The 0x8E-byte header every DIR request begins with, dir_$request_t's
    fields from +0x00 to +0x8D (their offsets and names), as a record of
    its own: the DIR_$<op> wrappers build requests of their operations'
    sizes, a header and one body each, with the reply right after
    (DIR_$RESOLVE's, DIR_$GET_ENTRYU's nested routine's), so the
    original's requests were records of different sizes, not one
    variant record. }
  dir_$req_hdr_t = record
    unused_00: array[1..3] of char;       { 0x00 }
    op: dir_$byte_t;                      { 0x03 }
    uid: uid_$t;                          { 0x04 }
    remote: integer;                      { 0x0C }
    version: integer;                     { 0x0E }
    unused_10: integer;                   { 0x10 }
    reply_version: integer;               { 0x12 }
    unused_14: array[1..12] of char;      { 0x14 }
    proc_flags: set of 0..15;             { 0x20 }
    unused_22: array[1..108] of char;     { 0x22 }
  end;

  { The 0x14-byte header of a DIR reply, dir_$reply_t's fields from
    +0x00 to +0x13 (their offsets and names), for the wrappers' replies
    of their operations' sizes (DIR_$RESOLVE's 0x34, DIR_$GET_ENTRYU's
    nested routine's 0x22). }
  dir_$reply_hdr_t = record
    unused_00: integer32;                 { 0x00 }
    status: status_$t;                    { 0x04 }
    version: integer;                     { 0x08 }
    reply_version: integer;               { 0x0A }
    unused_0c: array[1..6] of char;       { 0x0C }
    flags: set of 0..15;                  { 0x12 }
  end;

{ DIR_$RESOLVE - resolve a pathname through DIR_$DO_OP. }
procedure dir_$resolve(in path: univ name_$long_pname_t; in path_len: pinteger;
                       in out dir_uid: uid_$t; in out resolved_uid: uid_$t;
                       in out param5: dir_$path_index_t;
                       in out param6: pinteger;
                       in out param7: dir_$path_index_t;
                       in out param8: pinteger;
                       var link_buf: univ name_$long_pname_t;
                       out link_count: integer; out status_ret: status_$t);
  extern;

{ DIR_$OLD_GET_ENTRYU - look a name up in an old-format directory. }
procedure dir_$old_get_entryu(dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              out entry: dir_$old_entry_t;
                              out status_ret: status_$t);
  extern;

{ }

{ DIR_$READ_LINKU - read a soft link's text. }
procedure dir_$read_linku(in dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          in buf_len: integer;
                          var target: univ name_$long_pname_t;
                          out target_len: integer;
                          out target_uid: uid_$t;
                          out status_ret: status_$t);
  extern;

{ DIR_$OLD_READ_LINKU - read a soft link of an old-format directory. }
procedure dir_$old_read_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              out target: univ name_$long_pname_t;
                              out target_len: integer;
                              out target_uid: uid_$t;
                              out status_ret: status_$t);
  extern;

{ }

type
  { DIR_READU's continuation, the longword dir_$do_op_dir_readu reads
    and writes through its `cont' argument: compared and stored whole;
    its high word the entry's index, its low word the page plus 1. }
  dir_$readu_cont_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (entry_idx: integer;             { 0x00 }
          page: pinteger);                { 0x02 }
      3: (sub: pinteger;                  { 0x00 }
          index: pinteger);               { 0x02 }
  end;
  { The third view is the old format's position: the slot within an
    overflow block, 0 for the page's own slots, then the slot or block
    number, both compared unsigned: pinteger. }

  { The caller's reply buffer as words, from 0: an entry's address is
    the buffer's plus twice the word index. }
  dir_$readu_buf_t = array[0..32767] of integer;
  dir_$readu_buf_ptr_t = ^dir_$readu_buf_t;

{ DIR_$OLD_DIR_READU - read an old-format directory's entries. }
procedure dir_$old_dir_readu(in dir_uid: uid_$t;
                             var continuation: univ dir_$readu_cont_t;
                             in max_entries: integer32;
                             in buf_size: integer32;
                             out buf: univ dir_$readu_buf_t;
                             out count_ret: linteger;
                             out status_ret: status_$t);
  extern;

{ DIR_$FIND_UID - find the name of a directory's entry for a UID. }
procedure dir_$find_uid(in dir_uid: uid_$t; in target_uid: uid_$t;
                        in name_buf_len: integer;
                        out name_buf: univ name_$long_name_t;
                        out name_len_ret: integer;
                        var status_ret: status_$t);
  extern;

{ DIR_$OLD_FIND_UID - the name an old-format directory gives a UID.
  DIR_$OLD_FIND_NET - the extra longword of the old-format directory entry
  for a node. }
procedure dir_$old_find_uid(in dir_uid: uid_$t; in target_uid: uid_$t;
                            out name_buf: univ name_$long_name_t;
                            out name_len_ret: integer;
                            out status_ret: status_$t);
  extern;
function dir_$old_find_net(in dir_uid: uid_$t; in node: linteger):
  integer32; extern;

{ DIR_$OLD_ADDU - add an object entry to an old-format directory.
  DIR_$OLD_ROOT_ADDU - add an entry to the old-format root directory. }
procedure dir_$old_addu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                        in name_len: integer; in file_uid: uid_$t;
                        out status_ret: status_$t);
  extern;
procedure dir_$old_root_addu(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: integer; in file_uid: uid_$t;
                             in extra: integer32;
                             out status_ret: status_$t);
  extern;

{ DIR_$VALIDATE_ROOT_ENTRY - check one root entry against the replicated
  root, through DIR_$DO_OP, or in the old format. }
procedure dir_$validate_root_entry(in name: univ name_$long_name_t;
                                   in name_len: pinteger;
                                   out status_ret: status_$t);
  extern;

{ DIR_$OLD_VALIDATE_ROOT_ENTRY - check an old-format root entry against
  the replicated root's. }
procedure dir_$old_validate_root_entry(in name: univ name_$long_name_t;
                                       in name_len: pinteger;
                                       out status_ret: status_$t);
  extern;

{ DIR_$ADD_HARD_LINKU - add a hard link, a second name for an object, to a
  directory.
  DIR_$ADD_LINKU - add a soft link, a name whose entry holds a pathname,
  to a directory.
  DIR_$ADD_BAKU - enter an object under a name, keeping the name's old
  object as "<name>.bak". }
procedure dir_$add_hard_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              in target_uid: uid_$t;
                              out status_ret: status_$t);
  extern;
procedure dir_$add_linku(in dir_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: pinteger;
                         in target: univ name_$long_pname_t;
                         in target_len: pinteger;
                         out status_ret: status_$t);
  extern;
procedure dir_$add_baku(in dir_uid: uid_$t;
                        in name: univ name_$long_name_t;
                        in name_len: pinteger;
                        in backup_uid: uid_$t;
                        out status_ret: status_$t);
  extern;

{ DIR_$OLD_ADD_HARD_LINKU - add a hard link to an old-format directory. }
procedure dir_$old_add_hard_linku(in dir_uid: uid_$t;
                                  in name: univ name_$long_name_t;
                                  in name_len: pinteger;
                                  in target_uid: uid_$t;
                                  out status_ret: status_$t);
  extern;
{ name_$complen_max and name_$name_t, Apollo's base.ins.pas
  declarations of the pre-SR10 entry name, are base/base.ins.pas's. }

{ DIR_$OLD_ADD_BAKU - keep an old-format directory's entry as `.bak' and
  enter a new object under its name. }
procedure dir_$old_add_baku(in dir_uid: uid_$t;
                            in leaf: univ name_$name_t;
                            in leaf_len: integer;
                            in backup_uid: uid_$t;
                            out status_ret: status_$t);
  extern;
{ DIR_$OLD_ADD_LINKU - add a soft link to an old-format directory. }
procedure dir_$old_add_linku(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: pinteger;
                             in target: univ name_$long_pname_t;
                             in target_len: pinteger;
                             out status_ret: status_$t);
  extern;

{ DIR_$DELETE_FILEU - delete an object named in a directory.
  DIR_$DROP_HARD_LINKU - drop a name (a hard link) from a directory.
  DIR_$DROP_LINKU - drop a soft link from a directory. }
procedure dir_$delete_fileu(in dir_uid: uid_$t;
                            in name: univ name_$long_name_t;
                            in name_len: pinteger;
                            out status_ret: status_$t;
                            in check_del_right: boolean;
                            in no_lock: boolean);
  extern;
procedure dir_$drop_hard_linku(in dir_uid: uid_$t;
                               in name: univ name_$long_name_t;
                               in name_len: pinteger;
                               in flags: dir_$drop_flags_t;
                               out status_ret: status_$t);
  extern;
procedure dir_$drop_linku(in dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          out target_uid: uid_$t;
                          out status_ret: status_$t);
  extern;

{ DIR_$OLD_DROP_HARD_LINKU - remove an entry from an old-format directory.
  DIR_$OLD_DELETE_FILEU - delete a file from an old-format directory.
  DIR_$OLD_DROP_LINKU - remove a soft link from an old-format directory. }
procedure dir_$old_drop_hard_linku(in dir_uid: uid_$t;
                                   in name: univ name_$long_name_t;
                                   in name_len: pinteger;
                                   in flags: dir_$drop_flags_t;
                                   out status_ret: status_$t);
  extern;
procedure dir_$old_delete_fileu(in dir_uid: uid_$t;
                                in name: univ name_$long_name_t;
                                in name_len: pinteger;
                                out status_ret: status_$t;
                                in check_del_right: boolean;
                                in no_lock: boolean);
  extern;
procedure dir_$old_drop_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              var target_uid: uid_$t;
                              var status_ret: status_$t);
  extern;

{ DIR_$CNAMEU - rename an entry of a directory. }
procedure dir_$cnameu(in dir_uid: uid_$t;
                      in old_name: univ name_$long_name_t;
                      in old_name_len: pinteger;
                      in new_name: univ name_$long_name_t;
                      in new_name_len: pinteger;
                      out status_ret: status_$t);
  extern;

{ DIR_$OLD_CNAMEU - rename an entry of an old-format directory. }
procedure dir_$old_cnameu(in dir_uid: uid_$t;
                          in old_name: univ name_$long_name_t;
                          in old_name_len: pinteger;
                          in new_name: univ name_$long_name_t;
                          in new_name_len: pinteger;
                          out status_ret: status_$t);
  extern;

{ DIR_$OLD_GET_DEFAULT_ACL - an old-format directory's default ACL. }
procedure dir_$old_get_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                                   out acl_ret: uid_$t;
                                   out status_ret: status_$t);
  extern;

{ DIR_$OLD_SET_DEFAULT_ACL - set an old-format directory's default ACL. }
procedure dir_$old_set_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                                   in acl_uid: uid_$t;
                                   out status_ret: status_$t);
  extern;

{ DIR_$OLD_DROP_DIRU - remove a subdirectory from an old-format directory. }
procedure dir_$old_drop_diru(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: pinteger;
                             out status_ret: status_$t);
  extern;

{ DIR_$CREATE_DIRU - create a directory named in a directory. }
procedure dir_$create_diru(in parent_uid: uid_$t;
                           in name: univ name_$long_name_t;
                           in name_len: pinteger;
                           var new_dir_uid: uid_$t;
                           out status_ret: status_$t);
  extern;

{ DIR_$DROP_DIRU - delete a directory named in a directory. }
procedure dir_$drop_diru(in parent_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: pinteger;
                         out status_ret: status_$t);
  extern;

{ DIR_$ROOT_ADDU - add an entry to a directory with the caller's flags. }
procedure dir_$root_addu(in dir_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: integer; in file_uid: uid_$t;
                         in flags: integer32; out status_ret: status_$t);
  extern;

{ DIR_$OLD_CREATE_DIRU - create a subdirectory in an old-format directory. }
procedure dir_$old_create_diru(in dir_uid: uid_$t;
                               in name: univ name_$long_name_t;
                               in name_len: pinteger;
                               var new_dir_uid: uid_$t;
                               out status_ret: status_$t);
  extern;

{ DIR_$SET_DEFAULT_ACL - set one of a directory's default ACLs through its
  server. }
procedure dir_$set_default_acl(dir_uid: uid_$t; in acl_type: uid_$t;
                               acl_uid: uid_$t;
                               out status_ret: status_$t);
  extern;

{ DIR_$GET_DEFAULT_ACL - a directory's default ACL of a kind. }
procedure dir_$get_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                               out acl_ret: uid_$t;
                               out status_ret: status_$t);
  extern;

{ DIR_$OLD_CLEANUP - release the current process's old-format directory
  lock, if it holds one. }
procedure dir_$old_cleanup; extern;

{ DIR_$FIX_DIR - have a directory rebuilt (operation 16#48). }
procedure dir_$fix_dir(in dir_uid: uid_$t; out status_ret: status_$t);
  extern;

{ DIR_$OLD_FIX_DIR - rebuild an old-format directory. }
procedure dir_$old_fix_dir(dir_uid: uid_$t; out status_ret: status_$t);
  extern;

{ DIR_$OLD_SET_DAD - set an old-format directory's parent. }
procedure dir_$old_set_dad(in dir_uid: uid_$t; in dad_uid: uid_$t;
                           out status_ret: status_$t);
  extern;

{ }
type
  { One entry of a DIR_READU reply in the current format, as
    dir_$do_op_dir_readu writes it into the caller's buffer (OLD_DIR's
    DIR_$OLD_FIX_DIR reads such an entry back from DIR_$OLD_DIR_READU):
    Apollo's name_$canonical_dir_entry_t (the SR10.2 customer
    name.ins.pas, "the returned dir entry format": entnxt, enttype,
    reserved1..3, enthandle, entlen, entname, the same offsets), with
    the kernel's object UID in reserved1..2 and its extra longword in
    reserved3: the entry's size (entnxt), the type 1, the UID, the
    extra, the continuation, the name's length and the name from +0x16.
    Apollo's names, the UID's and the extra's (entuid, entextra) ours;
    Apollo's record is [aligned(2)], which these offsets do not need. }
  dir_$readu_entry_t = record
    entnxt: pinteger;                     { 0x00 }
    enttype: pinteger;                    { 0x02 }
    entuid: uid_$t;                       { 0x04 }
    entextra: integer32;                  { 0x0C }
    enthandle: integer32;                 { 0x10 }
    entlen: pinteger;                     { 0x14 }
    entname: name_$long_name_t;           { 0x16 }
  end;
  dir_$readu_entry_ptr_t = ^dir_$readu_entry_t;

  { An old-format directory's info block as DIR_$OLD_READ_INFOBLK and
    DIR_$OLD_WRITE_INFOBLK copy it, 40 bytes (the page's +0x382,
    dir/old_dir.pas dir_$old_dir_t's info): the text, or, as
    DIR_$OLD_SET_DEFAULT_ACL keeps it, the default directory and file
    ACLs' UIDs at +0x00 and +0x08 (dir_$old_dir_t's second view).  Its
    callers' locals are 0x28 bytes (DIR_$OLD_FIX_DIR's,
    DIR_$OLD_SET_DEFAULT_ACL's). }
  dir_$old_info_t = record
    case integer of
      1: (text: array[1..40] of char);    { 0x00 }
      2: (dir_acl: uid_$t;                { 0x00 }
          file_acl: uid_$t);              { 0x08 }
  end;

{ DIR_$OLD_READ_INFOBLK - read an old-format directory's info block.
  DIR_$OLD_WRITE_INFOBLK - write an old-format directory's info block. }
procedure dir_$old_read_infoblk(in dir_uid: uid_$t;
                                out buf: univ dir_$old_info_t;
                                in max_len: integer;
                                out len_out: integer;
                                out status_ret: status_$t);
  extern;
procedure dir_$old_write_infoblk(in dir_uid: uid_$t;
                                 in buf: univ dir_$old_info_t;
                                 in len: integer;
                                 out status_ret: status_$t);
  extern;

{ DIR_$OLD_DROPU - remove an entry from an old-format directory, handing
  back the object's UID. }
procedure dir_$old_dropu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                         in name_len: pinteger; out file_uid: uid_$t;
                         out status_ret: status_$t);
  extern;

{ One record of DIR_$OP_TAB, 8 bytes, and the table, DIR's defined
  global (map symbol DIR_$OP_TAB; `define'd by dir/dir.pas with the
  image's bytes), records 21..46.  DIR_$SERVER, in the DIR_SERVER
  module, reads a record's version through the symbol, indexed by
  op div 2, the lower bound 21 folded into the displacement.  Base types
  only. }
type
  dir_$op_tab_entry_t = record
    version: integer;                     { 0x00 }
    reply_version: integer;               { 0x02 }
    base_size: integer;                   { 0x04 }
    reply_size: integer;                  { 0x06 }
  end;

var
  dir_$op_tab: extern array[21..46] of dir_$op_tab_entry_t;
