{ FILE_$LOCATEI - an object's location, or a diskless partner's node.

  Image addresses:
    sau2  0x00E6067C  FILE_$LOCATEI

  - AST_$GET_LOCATION fills a location record of the object's UID; on
    success its location words (+0x10) are the answer.
  - On failure a diskless node's UID (first byte 0, second byte
    DISKLESS_$UID's) gives its node, the low 20 bits, and the network
    under the root (DIR_$FIND_NET).

  Status stored:
    status_$ok: the location was found, or a diskless node's
    ast_$get_location's status: any other failure
}

procedure file_$locatei(file_uid: uid_$t; out location: hint_$addr_t;
                        out status_ret: status_$t);
var
  loc: file_$lock_desc_t;
  local_status: status_$t;
  ast_loc: ast_$location_t;
  unused: integer32;
  idx: linteger;
begin
  loc.loc.uid := file_uid;
  loc.loc.flags := loc.loc.flags - [6];
  ast_$get_location(loc.loc, 0, unused, ast_loc, local_status);

  if local_status.all = status_$ok then
    location := loc.hint
  else if (file_$uid_view_t(file_uid).b0 = 0) and then
          (file_$uid_view_t(file_uid).b1 =
           file_$uid_view_t(diskless_$uid).b1) then begin
    idx := file_uid.low & 16#FFFFF;
    location.node_id := idx;
    location.flags := dir_$find_net(name_$root_uid, idx);
    local_status.all := status_$ok;
  end;

  status_ret := local_status;
end;
