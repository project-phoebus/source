{ FILE_$LOCATE - the node an object lives on.

  Image addresses:
    sau2  0x00E60620  FILE_$LOCATE

  - AST_$GET_LOCATION fills a location record of the object's UID; its
    node goes to the caller.

  Status stored:
    ast_$get_location's status: in either case
}

procedure file_$locate(file_uid: uid_$t; out location_out: integer32;
                       out status_ret: status_$t);
var
  loc: file_$obj_loc_t;
  local_status: status_$t;
  location: ast_$location_t;
  unused: integer32;
begin
  loc.uid := file_uid;
  loc.flags := loc.flags - [6];
  ast_$get_location(loc, 0, unused, location, local_status);

  location_out := loc.node;
  status_ret := local_status;
end;
