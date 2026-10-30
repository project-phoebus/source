{ TTY_$K_DRAIN_OUTPUT - wait until a line's output buffer is empty, for
  a caller of the kernel interface.

  Image addresses:
    sau2  0x00E67AAE  TTY_$K_DRAIN_OUTPUT

  - Under the TTY lock; the wait, on the line's output eventcount and
    the quit eventcount of the current address space, is done with the
    lock released.
  - The loop is `repeat ... until result = 2'; the drained test's `then'
    part, `tty_$i_unlock(tty^); return', is the routine's tail, merged
    by the compiler (ref 6.4.24 p. 6-27).

  Status stored:
    tty_$i_get_desc's status: the output drained, or the line has no
      descriptor
    status_$tty_quit_while_waiting_for_input: a quit (noted as seen)
}

{ TODO(pascal) the loop's form needs a dropped `bra' to the next
  instruction

  The other form, an endless loop with `if ... then exit' for the
  drained test and the quit's store and `exit' at the end, needs the
  compiler to drop an `exit''s branch to the next instruction, which is
  not a known form; the merged tail is.  The `repeat ... until result =
  2' form is kept. }

{ TODO(pascal) 10 frame bytes that nothing addresses (stand-in unused_20)

  The SAU2 frame has 10 bytes below the locals that no instruction
  addresses (6 more than the 4 of TTY_$K_FLUSH_INPUT's TODO).  The
  stand-in is one 8-byte object; what the source declared there is not
  known.  Two readings fit: TTY_$K_PUT's declarations (the same frame
  size), of which this routine uses tty and one word; or the usual 4
  and another 4. }

procedure tty_$k_drain_output(in line: integer; out status: status_$t);
var
  vals: array[1..2] of integer32;
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  tty: integer32;
  result: integer;
  unused_20: array[1..2] of integer32;    { stand-in, see the TODO above }
begin
  tty := tty_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  tty_$i_lock(tty_$desc_ptr_t(tty)^);

  repeat
    { the line's output eventcount }
    ecs[1] := tty_$desc_ptr_t(tty)^.output_ec;
    vals[1] := ecs[1]^.value + 1;

    { the quit eventcount of this address space }
    ecs[2] := addr(fim_$quit_ec[proc1_$as_id]);
    vals[2] := fim_$quit_value[proc1_$as_id] + 1;

    { drained: release the lock and return }
    if tty_$desc_ptr_t(tty)^.output.head = tty_$desc_ptr_t(tty)^.output.tail then begin
      tty_$i_unlock(tty_$desc_ptr_t(tty)^);
      return;
    end;

    { wait without the lock }
    tty_$i_unlock(tty_$desc_ptr_t(tty)^);
    result := ec_$waitn(ecs, vals, 2);
    tty_$i_lock(tty_$desc_ptr_t(tty)^);
  until result = 2;

  { a quit; note it as seen }
  status.all := status_$tty_quit_while_waiting_for_input;
  fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;

  tty_$i_unlock(tty_$desc_ptr_t(tty)^);
end;
