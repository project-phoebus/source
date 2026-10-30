{ PROC2_$MY_PID - the calling process's PROC1 pid.

  Image addresses:
    sau2  0x00E40CA0  PROC2_$MY_PID

  Status stored: none.
}

function proc2_$my_pid: pinteger;
begin
  proc2_$my_pid := proc1_$current;
end;
