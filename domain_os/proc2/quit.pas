{ PROC2_$QUIT - send a process SIGQUIT with the quit fault status.

  Image addresses:
    sau2  0x00E3F130  PROC2_$QUIT
    sau9  0x3C4465F8  PROC2_$QUIT

  - PROC2_$SIGNAL with SIGQUIT and the parameter fault_$quit.

  Status stored:
    proc2_$signal's status: always
}

procedure proc2_$quit(in proc_uid: uid_$t; out status_ret: status_$t);
begin
  proc2_$signal(proc_uid, proc2_$sig_quit, fault_$quit,
                status_ret);
end;
