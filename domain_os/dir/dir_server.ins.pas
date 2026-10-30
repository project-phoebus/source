{ dir/dir_server.ins.pas - DIR_SERVER (the remote directory server's
  request handler), for the Domain Pascal tree.

  DIR_$SERVER's heading and the request and reply records it takes,
  apart from dir/dir.ins.pas because the records hold acl/acl.ins.pas's.
  Its users: dir/dir_server.pas and REM_FILE_$SERVER's module.

  Include base/base.ins.pas, acl/acl.ins.pas and dir/dir.ins.pas
  (dir_$byte_t) before it.
}

type
  { A remote directory request as DIR_$SERVER reads it, 0x292 bytes
    (the request size it passes to DIR_$DO_OP): dir/dir.ins.pas
    dir_$request_t's header, with REM_FILE_'s fields in it typed: the
    header version at +0x0C, the body version at +0x0E, the
    requester's current projects at +0x14 (12 bytes,
    ACL_$SET_RE_ALL_SIDS's fourth argument), the flags word at +0x20
    (members 0 and 2 tested: dir_$request_t's proc_flags), the
    requester's SIDs at +0x28, its project list at +0x4C and count at
    +0x8C, the body from +0x8E.  A dpc probe confirmed every offset
    and the size 0x292.  The other names are dir_$request_t's. }
  dir_$server_req_t = record
    unused_00: array[1..3] of char;       { 0x00 }
    op: dir_$byte_t;                      { 0x03 }
    uid: uid_$t;                          { 0x04 }
    hdr_version: integer;                 { 0x0C }
    version: integer;                     { 0x0E }
    unused_10: integer;                   { 0x10 }
    reply_version: integer;               { 0x12 }
    cur_proj: acl_proj_list_t;            { 0x14 }
    proc_flags: set of 0..15;             { 0x20 }
    unused_22: array[1..6] of char;       { 0x22 }
    re_sids: acl_sid_block_t;             { 0x28 }
    proj_list: acl_$proj_uids_t;          { 0x4C }
    proj_count: integer;                  { 0x8C }
    body: array[0..515] of char;          { 0x8E }
  end;

  { Its reply as DIR_$SERVER writes it, 0x11A bytes (DIR_$DO_OP's reply
    size): dir_$reply_t's header (the status at +0x04, the two version
    words at +0x08 and +0x0A, the flags at +0x12), with the word at
    +0x0C typed, the version a refused request should have used (named
    hdr_version here, as the version words at +0x08 are dir_$reply_t's).
    Probed with the request. }
  dir_$server_reply_t = record
    unused_00: integer32;                 { 0x00 }
    status: status_$t;                    { 0x04 }
    version: integer;                     { 0x08 }
    reply_version: integer;               { 0x0A }
    hdr_version: integer;                 { 0x0C }
    unused_0e: array[1..4] of char;       { 0x0E }
    flags: set of 0..15;                  { 0x12 }
    body: array[0..261] of char;          { 0x14 }
  end;

{ DIR_$SERVER - the directory half of the remote-file server. }
procedure dir_$server(var request: univ dir_$server_req_t;
                      var reply: univ dir_$server_reply_t;
                      var reply_len: integer); extern;
