{ SIO_$K_TIMED_BREAK - hold a break on a serial line for a time.

  Image addresses:
    sau2  0x00E67EE0  SIO_$K_TIMED_BREAK
    sau4  0x0F8719D4  SIO_$K_TIMED_BREAK
    sau9  0x3C46EC54  SIO_$K_TIMED_BREAK

  - A break is raised (sio_$set_break), held for the milliseconds given
    (TIME_$WAIT2, the quit eventcount as an extra), and dropped, also
    after a quit.

  Status stored:
    time_$wait2's status: the break was held
    sio_$i_get_desc's status: the line has no descriptor
    status_$async_fault_while_waiting_for_input: a quit during the wait
}

{ TODO(pascal) SIO_$K_TIMED_BREAK's frame has 8 bytes no object explains

  The frame has 24 bytes: desc 4, delay 6 (longword aligned), the
  expression's temporary 4 at the bottom; 8 bytes between delay and the
  temporary are reached by no instruction (the stand-ins unused_10 and
  unused_14, two longwords: the bytes do not start at a multiple of 8
  from A6, where an 8-byte object would be placed).
  The SIO_$K_ and TTY_$K_ routines that park SIO_$I_GET_DESC's or
  TTY_$I_GET_DESC's result all have such bytes: see the TODO(pascal) in
  tty/k_flush_input.pas. }

procedure sio_$k_timed_break(in line: integer; in duration: pinteger;
                             out status: status_$t);
var
  desc: integer32;                        { SIO_$I_GET_DESC's parked result }
  delay: time_$clock_t;
  unused_10: integer32;                   { stand-in, see the TODO }
  unused_14: integer32;
begin
  desc := sio_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  sio_$set_break(sio_$desc_ptr_t(desc), true);
  if status.all <> status_$ok then
    return;

  { the time in 4-microsecond ticks }
  delay.high16 := 0;
  delay.low32 := duration * 250;

  { the wait, a quit ending it early }
  if time_$wait2(time_$relative, delay, fim_$quit_ec[proc1_$as_id],
                 fim_$quit_value[proc1_$as_id] + 1, status) then begin
    status.all := status_$async_fault_while_waiting_for_input;
    fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;
  end;

  sio_$set_break(sio_$desc_ptr_t(desc), false);
end;
