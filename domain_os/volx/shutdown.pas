{ VOLX_$SHUTDOWN - dismount every mounted volume.

  Image addresses:
    sau2  0x00E6B508  VOLX_$SHUTDOWN

  - A failure does not stop the loop; the result is the first failure's
    status, or status_$ok.
  - An entry is freed only when its mount point was dropped and its AST
    state dismounted.

  Status stored: none.
}

function volx_$shutdown: integer32;
var
  st1: status_$t;
  st2: status_$t;
  first: status_$t;
  i: integer;
begin
  first.all := status_$ok;

  for i := 1 to volx_max_volumes do
    with volx_$table[i] do
      if e_lv_num <> 0 then begin
        st1.all := status_$ok;
        if e_parent_uid <> uid_$nil then begin
          dir_$drop_mount(e_parent_uid, e_dir_uid, 0, st2);
          if st1.all = status_$ok then
            st1 := st2;
          if st2.all = status_$ok then
            e_parent_uid := uid_$nil;
        end;

        ast_$dismount(i, false, st2);
        if st1.all = status_$ok then begin
          st1 := st2;
          if st1.all = status_$ok then
            e_lv_num := 0;
        end;

        if first.all = status_$ok then
          first := st1;
      end;

  volx_$shutdown := first.all;
end;
