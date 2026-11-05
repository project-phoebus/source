{ SIO_$K_SIGNAL_WAIT - wait for one of a serial line's modem signals.

  Image addresses:
    sau2  0x00E67FBE  SIO_$K_SIGNAL_WAIT
    sau4  0x0F871AB2  SIO_$K_SIGNAL_WAIT
    sau6  0x78070C9C  SIO_$K_SIGNAL_WAIT
    sau7  0x3C47B604  SIO_$K_SIGNAL_WAIT

  - In a loop the driver refreshes the block (inq_params, selectors 7
    and 8) until one of the signals is in its first flag set; between,
    EC_$WAITN waits for the line's eventcount or a quit.
  - A quit brings the process's quit value up to its eventcount.

  Status stored:
    the driver's inq_params status: a signal is present, or it failed
    sio_$i_get_desc's status: the line has no descriptor
    status_$sio_quit_while_waiting: a quit ended the wait
}

{ TODO(pascal) SIO_$K_SIGNAL_WAIT's frame has 12 bytes no object
  explains

  The frame has 32 bytes: vals 8 at the top, ecs 8, desc 4; the 12
  bytes below are reached by no instruction (the stand-in unused_20).
  The lists at the top of the frame put desc below them, which no other
  parking caller does (sio/k_timed_break.pas, tty/k_flush_input.pas); see the
  TODO(pascal) in tty/k_flush_input.pas for the family's open frame bytes. }

procedure sio_$k_signal_wait(in line: integer; in signals: sio_$flags_t;
                             out status: status_$t);
var
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  desc: integer32;                        { SIO_$I_GET_DESC's parked result }
  unused_20: array[1..3] of integer32;    { stand-in, see the TODO }
begin
  desc := sio_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  repeat
    ecs[1] := addr(sio_$desc_ptr_t(desc)^.ec);
    vals[1] := sio_$desc_ptr_t(desc)^.ec.value + 1;
    ecs[2] := addr(fim_$quit_ec[proc1_$as_id]);
    vals[2] := fim_$quit_value[proc1_$as_id] + 1;
    sio_$inq_params_t(sio_$desc_ptr_t(desc)^.driver.inq_params)^(
      sio_$desc_ptr_t(desc)^.context, sio_$desc_ptr_t(desc)^.params,
      [7, 8], status);
    if status.all <> status_$ok then
      return;
    if sio_$desc_ptr_t(desc)^.params.flags1 * signals <> [] then
      return;
  until ec_$waitn(ecs, vals, 2) = 2;

  { a quit }
  status.all := status_$sio_quit_while_waiting;
  fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
end;
