{ DIR_$SERVER - the directory half of the remote-file server.

  Image addresses:
    sau2  0x00E58200  DIR_$SERVER

  - The operation (DIR_$DO_OP) runs with the requester's SIDs and
    projects, out of super-user mode; the server's own, saved the first
    time, are restored on every path.
  - An old (version 0) header gets the default project list.
  - The four unused_ statics hold the block's alignment gaps; nothing
    addresses them.

  Status stored (in the reply):
    dir_$do_op's status: the operation ran
    acl_$set_re_all_sids' or acl_$set_proj_list's status: the
      requester's SIDs or projects could not be taken on
    status_$naming_bad_request_header_version: a header version above 1
    status_$naming_bad_request_body_version: a body version newer than
      this node's
}

{ TODO(pascal) ACL_$SET_PROJ_LIST's list argument is UID_$NIL

  The last ACL_$SET_PROJ_LIST passes UID_$NIL's address as the project
  list, with the count 0 (the code segment's cell), so the list is
  never read.  acl/acl.ins.pas declares the formal `in proj_acls:
  acl_$proj_uids_t' (0x40 bytes), and UID_$NIL is an 8-byte uid_$t: no
  type transfer can make one the other (ref "Type Transfer Functions",
  p. 4-197: the sizes must be equal).  The original's heading was
  probably `univ' there; acl/acl.ins.pas is outside this write set.
  The Pascal passes UID_$NIL's address through a pointer transfer,
  `dir_$proj_uids_ptr_t(addr(uid_$nil))^', which passes the same
  address.  If acl.ins.pas's formal becomes `in univ', the argument is
  `uid_$nil'. }

procedure dir_$server(var request: univ dir_$server_req_t;
                      var reply: univ dir_$server_reply_t;
                      var reply_len: integer);
var
  default_proj: static acl_proj_list_t :=
    [field_00 := 16#C, field_04 := 16#C, field_08 := 16#C];
                                          { +0x00: 16#C three times }
  unused_0c: static integer32;            { +0x0C, zero }
  saved_subsys: static acl_prot_info_t;   { +0x10, zero }
  unused_1c: static integer32;            { +0x1C, zero }
  saved_prot: static acl_prot_info_t;     { +0x20, zero }
  unused_2c: static integer32;            { +0x2C, zero }
  saved_re_sids: static acl_sid_block_t;  { +0x30, zero }
  unused_54: static integer32;            { +0x54, zero }
  saved_acl: static acl_sid_block_t;      { +0x58, zero }
  first_time: static boolean := true;     { +0x7C: true }
  status: status_$t;
  op_half: integer;
  body_version: integer;
begin
  reply.version := 0;
  reply.reply_version := 0;
  reply_len := 20;
  reply.flags := [];

  { the header version }
  op_half := request.op div 2;
  if request.hdr_version > 1 then begin
    reply.hdr_version := 1;
    reply.status.all := status_$naming_bad_request_header_version;
    return;
  end;

  { the body version }
  body_version := dir_$op_tab[op_half].version;
  if body_version < request.version then begin
    reply.hdr_version := body_version;
    reply.status.all := status_$naming_bad_request_body_version;
    return;
  end;

  { an old header's projects }
  if request.hdr_version = 0 then
    request.cur_proj := default_proj;

  { the server's own SIDs, saved once }
  if first_time then begin
    acl_$get_re_all_sids(saved_acl, saved_re_sids, saved_prot,
                         saved_subsys, status);
    first_time := false;
  end;

  { the requester's SIDs }
  acl_$enter_super;
  audit_$suspend;
  acl_$set_re_all_sids(saved_acl, request.re_sids, saved_prot,
                       request.cur_proj, reply.status);
  if reply.status.all = status_$ok then begin
    { the requester's projects }
    acl_$set_proj_list(request.proj_list, request.proj_count,
                       reply.status);
    if reply.status.all = status_$ok then begin
      if 2 in request.proc_flags then
        acl_$up;
      if not (0 in request.proc_flags) then
        audit_$resume;
      acl_$exit_super;

      { the operation }
      dir_$do_op(request, 16#292, 16#11A, reply, reply_len);

      acl_$enter_super;
      if not (0 in request.proc_flags) then
        audit_$suspend;
      if 2 in request.proc_flags then
        acl_$down;
    end;
  end;

  { the server's own SIDs and no projects }
  acl_$set_re_all_sids(saved_acl, saved_re_sids, saved_prot,
                       saved_subsys, status);
  acl_$set_proj_list(dir_$proj_uids_ptr_t(addr(uid_$nil))^, 0, status);
  audit_$resume;
  acl_$exit_super;
end;
