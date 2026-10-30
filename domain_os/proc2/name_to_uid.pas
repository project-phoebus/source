{ PROC2_$NAME_TO_UID - find a process by its name.

  Image addresses:
    sau2  0x00E3EAD0  PROC2_$NAME_TO_UID

  - Under ml_$proc2_lock the first allocated entry whose name equals the
    given one gives its UID (an empty name matches the first unnamed).

  Status stored:
    status_$ok: the process was found
    status_$proc2_invalid_process_name: a length outside 0..32
    proc2_$uid_not_found: none has the name
}

procedure proc2_$name_to_uid(in proc_name: univ proc2_$name_t;
                             in proc_name_len: integer;
                             out uid_ret: uid_$t;
                             out status_ret: status_$t);
label
  next_entry;
var
  index: integer;
  i: integer;
begin
  if (proc_name_len < 0) or else (proc_name_len > 32) then begin

    status_ret.all := status_$proc2_invalid_process_name;
    return;
  end;
  status_ret.all := status_$ok;
  ml_$lock(ml_$proc2_lock);
  index := p2_info_alloc_ptr;
  if index <> 0 then
    repeat
      with proc2_$info_table[index] do begin
        if ord(name_len) = proc_name_len then begin
          for i := 1 to proc_name_len do
            if name[i] <> proc_name[i] then
              goto next_entry;
          ml_$unlock(ml_$proc2_lock);
          uid_ret := uid;
          return;
        end;
      next_entry:
        index := next_index;
      end;
    until index = 0;
  ml_$unlock(ml_$proc2_lock);
  status_ret.all := proc2_$uid_not_found;
end;
