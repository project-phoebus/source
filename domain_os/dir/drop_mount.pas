{ DIR_$DROP_MOUNT - remove a mount from a directory's mount table.

  Image addresses:
    sau2  0x00E53518  DIR_$DROP_MOUNT

  - An operation-16#5C request through DIR_$DO_OP; there is no
    old-format fallback.

  Status stored:
    the reply's status: always
}

procedure dir_$drop_mount(in mount_point_uid: uid_$t; in dir_uid: uid_$t;
                          in lv_num: integer32; out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$mount_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_drop_mount;
  request.hdr.uid := mount_point_uid;
  request.hdr.version := dir_$op_tab[46].version;
  request.body.mount_uid := dir_uid;
  request.body.node_id := lv_num;

  dir_$do_op(request, dir_$op_tab[46].base_size, 20, response,
             received_len);

  status_ret := response.status;
end;
