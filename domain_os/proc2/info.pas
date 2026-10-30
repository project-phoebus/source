{ PROC2_$INFO - the combined PROC1/PROC2 information block for an ASID.

  Image addresses:
    sau2  0x00E407B4  PROC2_$INFO

  - The allocated entry with the ASID is found before the lock (none for
    key 0); under ml_$proc2_lock proc2_$build_info_internal fills a
    local block, copied out up to the caller's length (at most 228
    bytes).

  Status stored:
    proc2_$build_info_internal's status: always
}

procedure proc2_$info(in scan_key: integer;
                      in pid: integer;
                      out info: univ proc2_$info_buf_t;
                      in info_len: pinteger;
                      out status_ret: status_$t);
var
  local_info: proc2_$info_buf_t;
  unused_1d0: proc2_$info_buf_t;          { the stand-in }
  len: pinteger;
  idx: integer;
  status: status_$t;
  n: pinteger;
  i: integer;
begin
  len := info_len;
  if scan_key <> 0 then begin
    idx := p2_info_alloc_ptr;
    if idx <> 0 then
      repeat
        if proc2_$info_table[idx].asid = scan_key then
          exit;
        idx := proc2_$info_table[idx].next_index;
      until idx = 0;
  end
  else
    idx := 0;
  ml_$lock(ml_$proc2_lock);
  proc2_$build_info_internal(idx, pid, local_info, status);
  ml_$unlock(ml_$proc2_lock);
  if len < 228 then
    n := len
  else
    n := 228;
  for i := 1 to n do
    info[i] := local_info[i];
  status_ret := status;
end;
