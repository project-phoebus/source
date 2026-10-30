{ dir_$do_op_drop_mount - DIR_$DO_OP's handler for operation 16#5C,
  removing a mount from the mount table.

  Image addresses:
    sau2  0x00E533E6  dir_$do_op_drop_mount

  - Under DIR_$MUTEX the first entry for the mounted root or the node is
    removed, the last entry moved into its place.

  Status stored:
    status_$ok: always
}

procedure dir_$do_op_drop_mount(in mount_uid: uid_$t; node_id: integer32;
                                out status_ret: status_$t);
var
  n: integer;
begin
  ml_$exclusion_start(dir_$mutex);

  for n := 1 to dir_$mttab.count do
    if (mount_uid = dir_$mttab.mount_tgt[n]) or else
       (node_id = dir_$mttab.mount_node[n]) then begin
      if dir_$mttab.count > 1 then begin
        dir_$mttab.mount_uid[n].high := 0;
        dir_$mttab.mount_tgt[n] := dir_$mttab.mount_tgt[dir_$mttab.count];
        dir_$mttab.mount_uid[n] := dir_$mttab.mount_uid[dir_$mttab.count];
        dir_$mttab.mount_node[n] :=
          dir_$mttab.mount_node[dir_$mttab.count];
      end;
      dir_$mttab.count := dir_$mttab.count - 1;
      exit;
    end;

  ml_$exclusion_stop(dir_$mutex);
  status_ret.all := status_$ok;
end;
