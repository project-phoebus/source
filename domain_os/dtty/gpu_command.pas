{ dtty_$gpu_command - send commands to the graphics processor.

  Image addresses:
    sau6  0x7801F65E  dtty_$gpu_command (module-local)

  - words holds count words, one command after another: its operation,
    the count of its arguments and the arguments.
  - The DN580's processor (SMD_$GRAPHIC_DEVICE_ID 2) takes each command
    through its registers when it is not busy: the count, the arguments
    and the operation last.  Otherwise the words go through the FIFO, as
    many at a time as its free count allows.
  - Then waits until the processor is done (dtty_$get_disp_type).
  - words is the pointer, passed by address (`univ' cancels the
    by-value passing `internal' gives a 4-byte `in' parameter, ref
    Table 5-1): the callers pass the address of a temporary holding
    their command's address.
  - With `dtty_gpu' only.

  Status stored: none.
}

{ TODO(pascal) 12 frame bytes unaddressed

  The SAU6 image's frame is 28 bytes; the routine's slot and these
  locals take 16.  Nothing in the routine addresses the frame (every
  local is held in a register).  The SAU5's copy of the routine, the
  same code with its own register choices, has a 32-byte frame and
  spills one pointer to its bottom longword.  Not settled; no stand-in
  is added. }

procedure dtty_$gpu_command(in words: univ dtty_gpu_words_ptr_t;
                            count: integer); internal;
var
  i: integer;
  op: pinteger;
  n: integer;
  first: integer;
  k: integer;
begin
  if smd_$graphic_device_id = smd_gdev_color2 then begin
    i := 1;
    while i < count do begin
      op := words^[i];
      n := words^[i + 1];
      first := i + 2;
      while 15 in kolor_ctl.status do { empty };
      kolor_ctl.count := n;
      for k := 0 to n - 1 do
        kolor_ctl.args[k] := words^[k + first];
      kolor_ctl.op := op;
      i := first + n;
    end;
  end
  else begin
    i := 0;
    while i < count do begin
      n := kolor_ctl.fifo_count & 16#F;
      if count - i < n then
        n := count - i;
      for k := 1 to n do
        kolor_ctl.fifo := words^[k + i];
      i := i + n;
    end;
  end;
  dtty_$get_disp_type;
end;
