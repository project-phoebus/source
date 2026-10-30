{ FILE_$NEIGHBORS - whether two objects are neighbors (on one volume).

  Image addresses:
    sau2  0x00E5E5AE  FILE_$NEIGHBORS

  - file_$check_same_volume's boolean, with copy_location false and a
    location record of its own that is never read.

  Status stored:
    file_$check_same_volume's status: in either case
}

function file_$neighbors(file_uid1: uid_$t; file_uid2: uid_$t;
                         out status_ret: status_$t): boolean;
var
  location: file_$obj_loc_t;
begin
  file_$neighbors := file_$check_same_volume(file_uid1, file_uid2, false,
                                             location, status_ret);
end;
