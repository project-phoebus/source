{ FILE_$CREATE - create an untyped object in a directory.

  Image addresses:
    sau2  0x00E5D778  FILE_$CREATE

  - FILE_$PRIV_CREATE with type 0, the nil type UID, no size (the
    default), no flags and no owner information.

  Status stored:
    file_$priv_create's status: in either case
}

procedure file_$create(in dir_uid: uid_$t; var file_uid_ret: uid_$t;
                       out status_ret: status_$t);
begin
  discard(file_$priv_create(0, uid_$nil, dir_uid, file_uid_ret, 0, 0, nil,
                            status_ret));
end;
