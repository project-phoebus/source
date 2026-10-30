{ PROC2_$SET_ACCT_INFO - record the calling process's accounting data.

  Image addresses:
    sau2  0x00E41AC0  PROC2_$SET_ACCT_INFO

  - Under ml_$proc2_lock up to 32 characters of accounting text, their
    length and an accounting UID go into the caller's entry, its debug
    member (3) cleared.

  Status stored:
    status_$ok: always
}

procedure proc2_$set_acct_info(in info: univ proc2_$acct_info_t;
                               in info_len: integer;
                               in acct_uid: uid_$t;
                               out status_ret: status_$t);
var
  len: integer;
  i: integer;
begin
  ml_$lock(ml_$proc2_lock);
  with proc2_$info_table[proc2_$pid_to_index[proc1_$current]] do begin

    len := info_len;
    if len > 32 then
      len := 32;
    for i := 1 to len do
      acct_info[i] := info[i];
    acct.info_len := len;
    acct.uid := acct_uid;
    flags.bits := flags.bits - [proc2_pf_debug];
  end;
  ml_$unlock(ml_$proc2_lock);
  status_ret.all := status_$ok;
end;
