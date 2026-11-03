{ MBUS_$INT - the Multibus's interrupt routine: find the interrupting level
  and call its handler.

  Image addresses:
    sau3  0x00E0AB8E  MBUS_$INT
    sau4  0x0F80B272  MBUS_$INT

  - The adapter's register at +2 is read once: a level from 7 down is
    interrupting when its bit and its pending bit (eight above) are both
    set.  The first one found is disabled while its handler runs and
    enabled again when the handler returns true; the others wait for
    the next interrupt.
  - Nothing happens when no level is interrupting.
  - With `mbus_vectored_adapter' the vector gives the level, which is
    acknowledged (+0x80) and masked (+0x82) while its handler runs.

  Status stored: none.
}

{ TODO(sau) MBUS_$INT on the SAU6

  The SAU6's MBUS_$INT takes the interrupt's vector (16#B0 plus the
  level, a word by value) and calls that level's handler without
  polling the adapter or touching its registers.  To be written with
  its part when that SAU is translated. }

{ TODO(pascal) 4 frame bytes unexplained

  The image's frame is 16#14 bytes; these locals give 16#10.  No local
  of the image's code uses the other 4, and no other SAU's MBUS_$INT
  has this form, so no stand-in is added. }

%if mbus_vectored_adapter %then
procedure mbus_$int(vector: integer);
  options(val_param);
var
  level: integer;
  ctl: ^mbus_$ctl_t;
  mask: set of 0..15;
  handler: mbus_$handler_t;
  handler_arg: univ_ptr;
begin
  level := vector - mbus_$first_vector;
  ctl := addr(pbu_ctl);
  ctl^.ack := level + mbus_$ack_base;
  mask := [level];
  ctl^.int_mask := ctl^.int_mask + mask;
  handler := mbus_$int_vec[level].handler;
  handler_arg := mbus_$int_vec[level].handler_arg;
  if handler^(handler_arg) then
    ctl^.int_mask := ctl^.int_mask - mask;
end;
%else
procedure mbus_$int;
var
  ctl: ^mbus_$ctl_t;
  pending: set of 0..15;
  level: integer;
  handler: mbus_$handler_t;
  handler_arg: univ_ptr;
begin
  ctl := addr(pbu_ctl);
  pending := ctl^.int_enable;
  for level := 7 downto 0 do
    if (level in pending)
       and then (level + mbus_$pending_bits in pending) then begin
      ctl^.int_enable := ctl^.int_enable - [level];
      handler := mbus_$int_vec[level].handler;
      handler_arg := mbus_$int_vec[level].handler_arg;
      if handler^(handler_arg) then
        ctl^.int_enable := ctl^.int_enable + [level];
      exit;
    end;
end;
%endif
