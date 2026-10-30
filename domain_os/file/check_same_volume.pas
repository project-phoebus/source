{ file_$check_same_volume - whether two objects lie on one volume.

  Image addresses:
    sau2  0x00E5E476  file_$check_same_volume

  - The first object is located: a remote one's location record goes
    back (copy_location), or its node is asked whether the two are
    neighbors.
  - Otherwise the result is whether the second, located too, is local
    and on the same volume.
  - A dismount meanwhile (the sequence number changed) repeats the test.

  Status stored:
    status_$ok: the objects were compared
    file_$object_is_remote: the first is remote and copy_location
    ast_$get_location's or rem_file_$neighbors's status: those failed
}

function file_$check_same_volume(file_uid1: uid_$t; file_uid2: uid_$t;
                                 copy_location: boolean;
                                 out location_out: file_$obj_loc_t;
                                 out status_ret: status_$t): boolean;
label
  10;
var
  uid2_masked: file_$uid_view_t;
  uid1_masked: file_$uid_view_t;
  loc2: file_$obj_loc_t;
  loc1: file_$obj_loc_t;
  location_status: status_$t;
  vol_uid: ast_$location_t;
  get_location_unused: integer32;
  dism_seqn_start: integer32;
begin
  uid1_masked.uid := file_uid1;
  uid1_masked.low_set := uid1_masked.low_set - [24..27];
  uid2_masked.uid := file_uid2;
  uid2_masked.low_set := uid2_masked.low_set - [24..27];

  repeat
    { the first object }
    file_$check_same_volume := false;
    dism_seqn_start := ast_$get_dism_seqn;
    loc1.uid := uid1_masked.uid;
    loc1.flags := loc1.flags - [6];
    ast_$get_location(loc1, 0, get_location_unused, vol_uid,
                      location_status);
    if location_status.all <> status_$ok then
      goto 10;

    { a remote first object }
    if 7 in loc1.flags then begin
      if copy_location then begin
        location_out := loc1;
        status_ret.all := file_$object_is_remote;
        return;
      end;
      file_$check_same_volume := rem_file_$neighbors(loc1.loc_info,
                                                     uid1_masked.uid,
                                                     uid2_masked.uid,
                                                     location_status);
      goto 10;
    end;

    { the second object }
    loc2.uid := uid2_masked.uid;
    loc2.flags := loc2.flags - [6];
    ast_$get_location(loc2, 1, get_location_unused, vol_uid,
                      location_status);
    if location_status.all <> status_$ok then
      goto 10;

    file_$check_same_volume := (loc1.volume = loc2.volume) and
                               not (7 in loc2.flags);

  until ast_$get_dism_seqn = dism_seqn_start;

  location_status.all := status_$ok;

10:
  status_ret := location_status;
end;
