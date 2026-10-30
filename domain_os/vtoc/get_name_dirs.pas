{ VTOC_$GET_NAME_DIRS - the UIDs of a volume's two name directories.

  Image addresses:
    sau2  0x00E393EE  VTOC_$GET_NAME_DIRS

  - The VTOCEs at the second and first name-directory locations give
    dir_uid and name_dir_uid; the second read's status is not tested.

  Status stored:
    vtoce_$read's status: a location was read
    status_$vtoc_no_uid: a location of 0
}

procedure vtoc_$get_name_dirs(vol_idx: integer; out name_dir_uid: uid_$t;
                              out dir_uid: uid_$t; out status: status_$t);
var
  req: vtoc_$lookup_req_t;
  vtoce: vtoce_$t;
begin
  with vtoc_$vols[vol_idx] do
    if name_dir2.all = 0 then
      status.all := status_$vtoc_no_uid
    else begin
      req.uid := uid_$nil;
      req.tail.vol_idx := vol_idx;
      req.block_hint := name_dir2;
      vtoce_$read(req, vtoce, status);
      if status.all = status_$ok then begin
        dir_uid := vtoce.id.uid;

        if name_dir1.all = 0 then
          status.all := status_$vtoc_no_uid
        else begin
          req.block_hint := name_dir1;
          vtoce_$read(req, vtoce, status);
          name_dir_uid := vtoce.id.uid;
        end;
      end;
    end;
end;
