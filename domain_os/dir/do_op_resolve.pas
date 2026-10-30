{ dir_$do_op_resolve - DIR_$DO_OP's 16#58 operation: walk a pathname
  through the local directories.

  Image addresses:
    sau2  0x00E4D0E2  dir_$do_op_resolve

  - From the position cont, component by component: `.' is passed over,
    `..' moves to the parent, any other name becomes the current
    directory.  An entry of type 3 has its text read and ends the walk.
  - For a server process (type 9) the walk ends, flagged as a loop,
    after 20 clock ticks, or at another node's root at the second level.

  Status stored:
    status_$ok: the walk ended at the path's end or a server's limit, or
      a retryable status was cleared (flagged as a loop; not after one
      component)
    dir_$do_op_read_linku's status: an entry of type 3
    dir_$do_op_get_entryu's or dir_$get_parent_uid's status: a lookup
      failed
    name_$bad_leaf: a component longer than 255
}

procedure dir_$do_op_resolve(in path_data: univ name_$long_pname_t;
                             path_len: pinteger;
                             in out result: dir_$uid_view_t;
                             out extra_ret: integer32;
                             var parent_uid_ret: uid_$t;
                             out flags1: boolean; out flags2: boolean;
                             in out cont: dir_$path_index_t;
                             out size: pinteger;
                             out last_start: dir_$path_index_t;
                             out last_size: pinteger;
                             max: dir_$text_ptr_t;
                             out link_count: integer;
                             out status_ret: status_$t);
label
  10;
var
  entry_uid: dir_$uid_view_t;
  entry_extra: integer32;
  entry_type: integer;
  i: pinteger;
  depth: pinteger;
  is_type9: boolean;
  start_time: time_$clockh_t;
  s: integer32;
begin
  flags1 := true;
  flags2 := false;
  link_count := 0;
  status_ret.all := status_$ok;

  depth := 0;
  extra_ret := 0;

  is_type9 := proc1_$type[proc1_$current] = 9;
  start_time := time_$clockh;

  { the loop's test }
  while cont <= path_len do begin
    { a slash }
    i := cont;
    if path_data[cont] = '/' then begin
      cont := cont + 1;
      next;
    end;

    { the component's end }
    while (i <= path_len) and then (path_data[i] <> '/') do
      i := i + 1;

    size := i - cont;
    if size > 255 then begin
      status_ret.all := name_$bad_leaf;
      goto 10;
    end;

    { `.' }
    if (size = 1) and then (path_data[cont] = '.') then begin
      last_start := cont;
      last_size := size;
      cont := cont + 1;
      next;
    end;

    { the type-9 time limit }
    depth := depth + 1;
    if is_type9 and then (depth > 1) and then
       (time_$clockh - start_time > 16#14) then begin
      flags2 := true;
      goto 10;
    end;

    { `..' }
    if (size = 2) and then (path_data[cont] = '.') and then
       (path_data[cont + 1] = '.') then begin
      if result.uid <> name_$root_uid then
        if result.uid = name_$node_uid then
          result.uid := name_$root_uid
        else begin
          dir_$get_parent_uid(result.uid, status_ret);
          if status_ret.all <> status_$ok then
            goto 10;
        end;
      last_start := cont;
      last_size := size;
      cont := cont + 2;
      parent_uid_ret := uid_$nil;
      next;
    end;

    { another node's root at the second level }
    if (depth = 2) and then
       ((parent_uid_ret.low & 16#FFFFF) <> (result.uid.low & 16#FFFFF))
       and then (parent_uid_ret = name_$root_uid) then begin
      flags2 := true;
      goto 10;
    end;

    dir_$do_op_get_entryu(result, path_data[cont], size, entry_type,
                          entry_uid, entry_extra, status_ret);

    s := status_ret.all;
    if (s = status_$ok) or else (s = name_$not_found) then begin
      last_start := cont;
      last_size := size;
    end;
    if s <> status_$ok then
      goto 10;

    { a link }
    if entry_type = 3 then begin
      dir_$do_op_read_linku(result.uid, path_data[cont], size, 16#3FF, max,
                            link_count, entry_uid, status_ret);
      goto 10;
    end;

    { down one level }
    parent_uid_ret := result.uid;
    result.uid := entry_uid.uid;
    extra_ret := entry_extra;
    cont := cont + size;
  end;

10:
  if (status_ret.all <> status_$ok) and then
     dir_$is_retryable_status(status_ret) and then (depth <> 1) then begin
    status_ret.all := status_$ok;
    flags2 := true;
  end;
end;
