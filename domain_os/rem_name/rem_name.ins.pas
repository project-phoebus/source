{ rem_name/rem_name.ins.pas - REM_NAME (the remote naming service's
  client), for the Domain Pascal tree.

  The socket, the entry types, the sizes, the request and reply
  records, the directory and replica entry records, the block's
  map-symbol variables and the headings of the map-global routines, in
  map order.  No customer insert file of the SR10.2 install declares
  REM_NAME.

  The statuses are in name/name.ins.pas.  The module is
  rem_name/rem_name.pas.  Include base/base.ins.pas and
  name/name.ins.pas before it.
}

const
  { The naming service's socket: rem_name_$send_request passes it as
    PKT_$SAR_INTERNET's dest_sock; REM_NAME_SERVER_LOCAL reads its
    descriptor, SOCK_$SOCKET_PTR's element 10. }
  rem_name_$sock = 10;

  { The entry types of a reply and of rem_name_$dir_entry_t:
    REM_NAME_$GET_ENTRY_BY_NAME tests 1 and 2 and stores 1 and 3. }
  entry_type_normal = 1;
  entry_type_link = 2;
  entry_type_link_alt = 3;

  { The reply buffers' sizes, passed as rem_name_$send_request's
    resp_size. }
  rem_name_reply_size = 362;
  rem_name_read_reply_size = 512;

type
  { The request template, 15 words, 30 bytes: the block's first object,
    its first word or-ed with the flags.  Its words are pkt/pkt.ins.pas
    pkt_$info_t's first fifteen (flags, routing_type, addr_type,
    protocol, ...), which is 32 bytes: see the TODO(pascal) in
    rem_name/send_request.pas. }
  rem_name_$config_t = array[1..15] of pinteger;

  { A name of up to 32 characters. }
  rem_name_$name_t = array[1..32] of char;

  { The 12 bytes after an entry's name, its UID and extra word, copied
    from the reply one byte at a time: a character array. }
  rem_name_$entry_data_t = array[1..12] of char;

  { A directory entry, 0x30 bytes (`type' is entry_type here, a reserved
    word).  The 12 bytes from 0x24 are one character array or the UID
    and extra word apart: two views of the same bytes, a variant (ref
    3.10.3). }
  rem_name_$dir_entry_t = record
    entry_type: integer;                  { 0x00 }
    name_len: pinteger;                   { 0x02 }
    name: rem_name_$name_t;               { 0x04 }
    case integer of
      1: (uid: uid_$t;                    { 0x24 }
          extra: integer32);              { 0x2C }
      2: (data: rem_name_$entry_data_t);  { 0x24 }
  end;

  { The entries REM_NAME_$READ_DIR and _DIR_READU fill, from 1.  The
    type is a `univ' formal's; its bound is chosen so that 48 times it
    does not fit in 16 bits, which the longword index arithmetic would
    need (rem_name_$rep_entries_t below the other way). }
  rem_name_$dir_entries_t = array[1..1024] of rem_name_$dir_entry_t;

  { A replica entry, 0x12 bytes, only copied. }
  rem_name_$rep_entry_t = record
    words: array[1..4] of integer32;      { 0x00 }
    tail: integer;                        { 0x10 }
  end;

  { The replica entries REM_NAME_$READ_REP fills, from 1, in word
    arithmetic: 18 times the bound fits in 16 bits. }
  rem_name_$rep_entries_t = array[1..1024] of rem_name_$rep_entry_t;

  { The 22 bytes REM_NAME_$GET_INFO hands back. }
  rem_name_$info_t = record
    words: array[1..5] of integer32;      { 0x00 }
    tail: integer;                        { 0x14 }
  end;

  { REM_NAME_$DIR_READU's continuation, a longword whose low word is the
    entry index, READ_DIR's start_index: two views, a variant. }
  rem_name_$continuation_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (high: integer;                  { 0x00 }
          index: pinteger);               { 0x02 }
  end;

  { The first 0x12 bytes of every reply: the opcode, and the status at
    0xE (a longword at 2 mod 4, the kernel's word rules). }
  rem_name_$reply_hdr_t = record
    word_00: integer;                     { 0x00 }
    opcode: pinteger;                     { 0x02 }
    unused_04: array[1..10] of char;      { 0x04 }
    status: status_$t;                    { 0x0E }
  end;

  { The 0x16A-byte reply of GET_ENTRY_BY_NAME, _BY_NODE_ID, _BY_UID,
    GET_INFO and LOCATE_SERVER: after the header, an entry's type, name
    length, name and 12 bytes (GET_ENTRY_BY_NAME); GET_INFO's 22 bytes
    from 0x12; REM_NAME_$LOCATE_SERVER's server node, a longword at
    0x1E.  Three views of the bytes after the header, a variant; the
    fourth gives the size. }
  rem_name_$reply_t = record
    hdr: rem_name_$reply_hdr_t;           { 0x00 }
    case integer of
      1: (entry_type: integer;            { 0x12 }
          name_len: pinteger;             { 0x14 }
          name: rem_name_$name_t;         { 0x16 }
          data: rem_name_$entry_data_t);  { 0x36 }
      2: (info: rem_name_$info_t);        { 0x12 }
      3: (unused_12: array[1..12] of char;  { 0x12 }
          server_node: integer32);        { 0x1E }
      4: (bytes: array[1..344] of char);   { 0x12..0x169 }
  end;

  { The reply of READ_DIR and READ_REP, received into a NETBUF header
    page: the entry count at 0x16; the wire bytes READ_DIR unpacks from
    0x18; the replica records READ_REP copies from 0x18.  The page holds
    27 records. }
  rem_name_$read_reply_t = record
    hdr: rem_name_$reply_hdr_t;           { 0x00 }
    word_12: integer;                     { 0x12 }
    word_14: integer;                     { 0x14 }
    count: pinteger;                      { 0x16 }
    case integer of
      1: (data: array[1..488] of char);   { 0x18..0x1FF }
      2: (reps: array[1..27] of rem_name_$rep_entry_t);  { 0x18 }
  end;
  rem_name_$read_reply_ptr_t = ^rem_name_$read_reply_t;

  { The requests, each its routine's frame object: the opcode longword,
    a UID, the word 1 at 0xC (every routine), 0x24 bytes no routine
    stores, then each request's own fields from 0x32.  The sizes sent
    are the records' sizes (50 GET_INFO and LOCATE_SERVER; 54 READ_DIR,
    READ_REP; 56 GET_ENTRY_BY_NODE_ID; 58 GET_ENTRY_BY_UID; 52 plus the
    name's length GET_ENTRY_BY_NAME).  unused_0e for the unset bytes. }
  rem_name_$req_t = record
    opcode: integer32;                    { 0x00 }
    uid: uid_$t;                          { 0x04 }
    one: integer;                         { 0x0C }
    unused_0e: array[1..36] of char;      { 0x0E }
  end;

  rem_name_$by_name_req_t = record
    opcode: integer32;                    { 0x00 }
    dir_uid: uid_$t;                      { 0x04 }
    one: integer;                         { 0x0C }
    unused_0e: array[1..36] of char;      { 0x0E }
    name_len: pinteger;                   { 0x32 }
    name: rem_name_$name_t;               { 0x34 }
  end;

  { GET_ENTRY_BY_NODE_ID's node address, two 24-bit fields from 0x32
    (ref 3.10.7): the bytes 08 00 1E, Apollo's Ethernet vendor prefix,
    and a 24-bit node. }
  rem_name_$node_addr_t = packed record
    prefix: 0..16#FFFFFF;                 { 0x32..0x34 }
    node: 0..16#FFFFFF;                   { 0x35..0x37 }
  end;

  rem_name_$by_node_req_t = record
    opcode: integer32;                    { 0x00 }
    dir_uid: uid_$t;                      { 0x04 }
    one: integer;                         { 0x0C }
    unused_0e: array[1..36] of char;      { 0x0E }
    node_addr: rem_name_$node_addr_t;     { 0x32 }
  end;

  rem_name_$by_uid_req_t = record
    opcode: integer32;                    { 0x00 }
    dir_uid: uid_$t;                      { 0x04 }
    one: integer;                         { 0x0C }
    unused_0e: array[1..36] of char;      { 0x0E }
    target_uid: uid_$t;                   { 0x32 }
  end;

  { READ_DIR's and READ_REP's: the start index widened with zeros into
    a longword. }
  rem_name_$read_req_t = record
    opcode: integer32;                    { 0x00 }
    dir_uid: uid_$t;                      { 0x04 }
    one: integer;                         { 0x0C }
    unused_0e: array[1..36] of char;      { 0x0E }
    start_index: integer32;               { 0x32 }
  end;

var
  { The block's map symbols (the REM_NAME data segment, .DATA; defined
    in rem_name/rem_name.pas): the time a server was last heard from (a
    clock high longword), the last status, the current server's node
    and network, the PKT_$SAR_INTERNET timeout, and the heard-from
    flag. }
  rem_name_$time_heard_from_server: extern time_$clockh_t;
  rem_name_$last_status: extern status_$t;
  rem_name_$curr_node: extern integer32;
  rem_name_$curr_net: extern integer32;
  rem_name_$service_delay: extern pinteger;
  rem_name_$heard_from_server: extern boolean;

{ Routine headings, in map order. }

{ REM_NAME_SERVER_LOCAL - is the naming server on this node? }
function rem_name_server_local: boolean; extern;

{ LOCATE_SERVER - find a naming server, at most four tries until one
  answers, and forget it when it has been silent too long. }
procedure locate_server(out node_ret: integer32;
                        out net_ret: integer32;
                        out status: status_$t); extern;

{ REM_NAME_$REGISTER_SERVER - note that a naming server was heard from. }
procedure rem_name_$register_server(in net: integer32;
                                    in node: integer32); extern;

{ REM_NAME_$GET_ENTRY_BY_NAME - ask a naming server for a directory's
  entry by its name. }
procedure rem_name_$get_entry_by_name(net: integer32;
                                      node: integer32;
                                      in dir_uid: uid_$t;
                                      in name: univ rem_name_$name_t;
                                      name_len: pinteger;
                                      out entry: rem_name_$dir_entry_t;
                                      out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$GET_INFO - ask a naming server for an object's 22 bytes of
  information. }
procedure rem_name_$get_info(net: integer32;
                             node: integer32;
                             in uid: uid_$t;
                             out info: rem_name_$info_t;
                             out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$LOCATE_SERVER - find a naming server, on this node first, then
  by broadcast. }
procedure rem_name_$locate_server(out node_ret: integer32;
                                  out net_ret: integer32;
                                  out status: status_$t); extern;

{ REM_NAME_$GET_ENTRY_BY_NODE_ID - ask a naming server for a directory's
  entry by a node's ID. }
procedure rem_name_$get_entry_by_node_id(net: integer32;
                                         node: integer32;
                                         in dir_uid: uid_$t;
                                         target_node: linteger;
                                         out entry: rem_name_$dir_entry_t;
                                         out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$GET_ENTRY_BY_UID - ask a naming server for a directory's entry
  by an object's UID. }
procedure rem_name_$get_entry_by_uid(net: integer32;
                                     node: integer32;
                                     in dir_uid: uid_$t;
                                     in target_uid: uid_$t;
                                     out entry: rem_name_$dir_entry_t;
                                     out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$READ_DIR - read a directory's entries from a naming server. }
procedure rem_name_$read_dir(net: integer32;
                             node: integer32;
                             in dir_uid: uid_$t;
                             start_index: pinteger;
                             out entries: univ rem_name_$dir_entries_t;
                             max_entries: pinteger;
                             out count: pinteger;
                             out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$READ_REP - read a directory's replica records from a naming
  server. }
procedure rem_name_$read_rep(net: integer32;
                             node: integer32;
                             in dir_uid: uid_$t;
                             start_index: pinteger;
                             out reps: univ rem_name_$rep_entries_t;
                             max_entries: pinteger;
                             out count: pinteger;
                             out status: status_$t);
  options(extern, val_param);

{ REM_NAME_$DIR_READU - read a directory's entries from the current naming
  server, as many round trips as it takes. }
procedure rem_name_$dir_readu(in dir_uid: uid_$t;
                              out entries: univ rem_name_$dir_entries_t;
                              in out continuation: rem_name_$continuation_t;
                              in max_entries: pinteger;
                              out count: pinteger;
                              out status: status_$t); extern;

{ REM_NAME_$GET_ENTRY - look a name up in a directory on the current
  naming server, locating a server when needed. }
procedure rem_name_$get_entry(in dir_uid: uid_$t;
                              in name: univ rem_name_$name_t;
                              in name_len: pinteger;
                              out entry: rem_name_$dir_entry_t;
                              out status: status_$t); extern;

{ REM_NAME_$FIND_NETWORK - look a node's entry up in a directory on the
  current naming server, locating a server when needed. }
procedure rem_name_$find_network(in dir_uid: uid_$t;
                                 in target_node: linteger;
                                 out entry: rem_name_$dir_entry_t;
                                 out status: status_$t); extern;

{ REM_NAME_$FIND_UID - look an object's entry up by its UID on the current
  naming server, locating a server when needed. }
procedure rem_name_$find_uid(in dir_uid: uid_$t;
                             in target_uid: uid_$t;
                             out entry: rem_name_$dir_entry_t;
                             out status: status_$t); extern;
