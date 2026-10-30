{ PROC2_$SET_NAME - name a process.

  Image addresses:
    sau2  0x00E3EA2C  PROC2_$SET_NAME

  - Under ml_$proc2_lock the name (up to 32 characters) and its length go
    into the process's entry; a length of 0 stores the length byte 16#22
    and no name.

  Status stored:
    proc2_$find_index' status: the name was stored, or no such process
    status_$proc2_invalid_process_name: a length outside 0..32
}

procedure proc2_$set_name(in proc_name: univ proc2_$name_t;
                          in proc_name_len: integer;
                          in proc_uid: uid_$t;
                          out status_ret: status_$t);
var
  status: status_$t;
  index: integer;
  i: integer;
begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    with proc2_$info_table[index] do begin
      if (proc_name_len < 0) or else (proc_name_len > 32) then

        status.all := status_$proc2_invalid_process_name
      else if proc_name_len = 0 then
        name_len := chr(16#22)
      else begin
        for i := 1 to proc_name_len do
          name[i] := proc_name[i];
        name_len := chr(proc_name_len);
      end;
    end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
