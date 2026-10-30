{ VTOC_$SET_NAME_DIRS - look up a volume's two name directories.

  Image addresses:
    sau2  0x00E39486  VTOC_$SET_NAME_DIRS

  - VTOC_$LOOKUP of the first UID at the first name-directory location,
    then, on success, of the second at the second.  Nothing in the SAU2
    image calls it.

  Status stored:
    vtoc_$lookup's status: always
}

procedure vtoc_$set_name_dirs(vol_idx: integer; in dir1_uid: uid_$t;
                              in dir2_uid: uid_$t; out status: status_$t);
var
  req: vtoc_$lookup_req_t;
begin
  req.uid := dir1_uid;
  req.tail.vol_idx := vol_idx;
  req.block_hint := vtoc_$vols[vol_idx].name_dir1;
  vtoc_$lookup(req, status);

  if status.all = status_$ok then begin
    req.uid := dir2_uid;
    req.block_hint := vtoc_$vols[vol_idx].name_dir2;
    vtoc_$lookup(req, status);
  end;
end;
