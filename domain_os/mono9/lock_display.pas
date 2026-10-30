{ MONO9_$LOCK_DISPLAY - claim the display for a request.

  Image addresses:
    sau9  0x3C420360  MONO9_$LOCK_DISPLAY

  - Under the module's spin lock: a request whose state is 0 gets state
    5 and the result true; any other state is left, and the result is
    false.
  - The descriptor and the kind are not read.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function mono9_$lock_display(dcte: mono9_$dcte_ptr_t;
                             var req: mono9_$lock_req_t;
                             kind: integer): boolean;
  options(val_param);
var
  lock: static integer32 := 0;            { the WIRED_DATA block }
  token: pinteger;
  locked: boolean;
begin
  token := ml_$spin_lock(lock);
  if req.state = 0 then begin
    req.state := 5;
    locked := true;
  end
  else
    locked := false;
  ml_$spin_unlock(lock, token);
  mono9_$lock_display := locked;
end;
