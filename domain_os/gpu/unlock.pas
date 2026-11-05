{ gpu_$unlock - give the graphics processor back.

  Image addresses:
    sau5  0x00E736C4  gpu_$unlock (module-local)
    sau6  0x7807A5DA  gpu_$unlock (module-local)

  - Only the holder gives it back; the lock's eventcount is advanced
    only when a process waits.

  Status stored: none.
}

procedure gpu_$unlock; internal;
begin
  if gpu_$user_pid = proc1_$current then begin
    gpu_$user_pid := 0;
    if lock_waiters > 0 then
      ec_$advance(gpu_ec);
  end;
end;
