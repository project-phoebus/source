{ server_set_attribute - serve a remote SET_ATTRIBUTE (opcode 16#04).

  Image addresses:
    sau2  0x00E62DE8  server_set_attribute (nested)

  - Nested in REM_FILE_$SERVER (rem_file/server.pas includes this
    fragment).
  - A protection (attribute 3) of an ACL with type bits, or of a 10-ACL
    object, is converted and applied as attribute 16#14.
  - Retyping an object to the symbolic-link type is refused.

  Status stored (in the reply):
    ast_$set_attribute's status: the attribute was applied, or not
    file_$incompatible_request: a retype to SLINK_$UID
    the ACL routines' or ast_$get_acl_attributes's status: the protection
      could not be converted
}

  procedure server_set_attribute;
  label
    10;
  var
    status: status_$t;
    acl_attrs: ast_$acl_attr_t;
    acl_type_uid: uid_$t;
    old_acl: uid_$t;
    loc: file_$obj_loc_t;
    converted: uid_$t;
  begin
    reply_len := 8;

    if request.sa_attr_id = 3 then begin
      if (rshft(request.sa_view.w2 & 16#FF0, 4) & 16#E0) <> 0 then begin
        acl_$convert_funky_acl(request.sa_view.uid, acl_attrs.prot,
                               converted, acl_type_uid, status);
        request.sa_view.uid := converted;
        response.reply.hdr.status := status;
        request.sa_view.low_set := request.sa_view.low_set - [24];
      end
      else begin
        loc.uid := request.sa_uid;
        loc.flags := loc.flags - [6];
        ast_$get_acl_attributes(loc, 1, acl_attrs, status);
        response.reply.hdr.status := status;
        if response.reply.hdr.status.all <> status_$ok then
          return;

        if acl_attrs.obj_type = 0 then
          goto 10;
        old_acl := request.sa_view.uid;
        acl_$convert_to_10acl(old_acl, request.sa_uid, converted,
                              acl_attrs.prot, status);
        request.sa_view.uid := converted;
        response.reply.hdr.status := status;
      end;

      if response.reply.hdr.status.all <> status_$ok then
        return;
      request.sa_acl_uid := request.sa_view.uid;
      request.sa_prot := acl_attrs.prot;
      ast_$set_attribute(request.sa_uid, 16#14, request.sa_value, status);
    end

    else if (request.sa_attr_id = 4) and then
            (request.sa_view.uid = slink_$uid) then
      status.all := file_$incompatible_request

    else
10:   ast_$set_attribute(request.sa_uid, request.sa_attr_id,
                         request.sa_value, status);

    response.reply.hdr.status := status;
  end;
