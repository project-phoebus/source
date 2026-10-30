{ DIR_$ADD_MOUNT - enter a mount in a directory's mount table.

  Image addresses:
    sau2  0x00E534B8  DIR_$ADD_MOUNT

  - An operation-16#5A request through DIR_$DO_OP; there is no
    old-format fallback.

  Status stored:
    the reply's status: always
}

procedure dir_$add_mount(in dir_uid: uid_$t; in mount_uid: uid_$t;
                         out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$mount_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_add_mount;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[45].version;
  request.body.mount_uid := mount_uid;
  request.body.node_id := node_$me;

  dir_$do_op(request, dir_$op_tab[45].base_size, 20, response,
             received_len);

  status_ret := response.status;
end;
