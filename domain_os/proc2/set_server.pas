{ PROC2_$SET_SERVER - set or clear a process's server flag.

  Image addresses:
    sau2  0x00E41468  PROC2_$SET_SERVER

  - Under ml_$proc2_lock the boolean goes into the found entry's server
    member.

  Status stored:
    proc2_$find_index' status: always
}

procedure proc2_$set_server(in proc_uid: uid_$t; server_flag: boolean;
                            out status_ret: status_$t);
var
  status: status_$t;
  index: integer;
begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    proc2_$info_table[index].flags.server := server_flag;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
