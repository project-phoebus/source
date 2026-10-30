{ dir_$do_op_get_entryu - DIR_$DO_OP's 16#44 operation: a directory
  entry by name.

  Image addresses:
    sau2  0x00E4CFFA  dir_$do_op_get_entryu
    sau2  0x00E4CB6A  dir_$lookup_entry (nested)
    sau2  0x00E4CD90  dir_$get_entry_cached (nested)

  - Through the entry cache; a found file whose UID names another node
    updates that node's hint.
  - The nested routines (dir/lookup_entry.pas, dir/get_entry_cached.pas)
    are included in its declaration part.

  Status stored:
    dir_$get_entry_cached's status: always
}

procedure dir_$do_op_get_entryu(in uid: dir_$uid_view_t;
                                in name: univ name_$long_name_t;
                                name_len: integer; var type_ret: integer;
                                var uid_ret: dir_$uid_view_t;
                                var extra_ret: integer32;
                                out status_ret: status_$t);

%include 'dir/lookup_entry.pas';             { dir_$lookup_entry }
%include 'dir/get_entry_cached.pas';         { dir_$get_entry_cached }

begin
  dir_$get_entry_cached(status_ret);

  { a file of another node: its hint }
  if ((uid_ret.uid.low & 16#FFFFF) <> node_$me) and then
     (uid_ret.b0 <> 0) and then (type_ret = 1) and then
     (status_ret.all = status_$ok) then
    dir_$update_hint(uid.uid, network_$me, node_$me, uid_ret.uid,
                     extra_ret);
end;
