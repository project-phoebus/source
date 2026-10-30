{ disk_$wait_io - wait for the current process's I/O, timing out drives.

  Image addresses:
    sau2  0x00E3C9FE  disk_$wait_io

  - The process's two eventcounts and the clock (240 ticks) are waited
    on; the I/O eventcount ends the wait.
  - Otherwise each volume in the mask has its driver's error_que called
    (with the timeout flag when the clock fired), each error raising the
    error value; then the wait starts again.

  Status stored: none.
}

procedure disk_$wait_io(disk_mask: disk_$vol_set_t; var io_wait_val: integer32;
                        var error_wait_val: integer32);
  internal;
var
  failed: boolean;
  which: integer;
  timeout: integer;
  i: integer;
begin
  with disk_bptbl[proc1_$current] do
    repeat
      which := ec_$wait(addr(io_ec), addr(err_ec),
                        ec_$eventcount_ptr_t(addr(time_$clockh)),
                        io_wait_val, error_wait_val, time_$clockh + 240);
      if which = 0 then
        return;

      if which = 1 then
        timeout := 0
      else
        timeout := 1;

      for i := 1 to 10 do
        if i in disk_mask then begin
          disk_$error_que(disk_$dvtbl[i], timeout, failed);
          if failed and then (timeout = 0) then
            error_wait_val := error_wait_val + 1;
        end;
    until false;
end;
