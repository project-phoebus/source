{ DXM_$ADD_SIGNAL - queue a signal for a process on the unwired DXM
  queue.

  Image addresses:
    sau2  0x00E17270  DXM_$ADD_SIGNAL

  - A signal record (the delivery routine, the signal, its parameter,
    the process's index) is built and DXM_$ADD_SIGNAL_CALLBACK queued on
    DXM_$UNWIRED_Q with its 10 bytes, check_dup passed on.

  Status stored:
    dxm_$add_callback's status: always
}

{ TODO(pascal) 6 frame bytes left by an alignment of 8

  The 6 bytes above the 10-byte record that nothing addresses are what
  an alignment of 8 for objects of 8 bytes or more leaves, as in
  tty_$i_wait.  That alignment is not settled (tty/i_wait.pas has the
  same TODO); with word or longword alignment alone the record would be
  at -0xA (or -0xC) and the frame 0x10 (it is 0x14). }

procedure dxm_$add_signal(routine: integer; proc_index: integer;
                          signal: integer; param: status_$t;
                          check_dup: boolean; out status: status_$t);
  options(val_param);
var
  signal_data: dxm_$signal_data_t;
begin
  { the signal record }
  signal_data.routine := routine;
  signal_data.proc_index := proc_index;
  signal_data.signal := signal;
  signal_data.param := param;

  { queue its delivery }
  dxm_$add_callback(dxm_$unwired_q, addr(dxm_$add_signal_callback),
                    addr(signal_data), 10, check_dup, status);
end;
