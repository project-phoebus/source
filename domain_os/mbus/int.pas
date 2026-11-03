{ MBUS_$INT - the Multibus's interrupt routine: find the interrupting level
  and call its handler.

  Image addresses:
    sau3  0x00E0AB8E  MBUS_$INT

  - The adapter's register at +2 is read once: a level from 7 down is
    interrupting when its bit and its pending bit (eight above) are both
    set.  The first one found is disabled while its handler runs and
    enabled again when the handler returns true; the others wait for
    the next interrupt.
  - Nothing happens when no level is interrupting.

  Status stored: none.
}

{ TODO(sau) MBUS_$INT on the SAU4 and SAU6

  The SAU4's and SAU6's MBUS_$INT take the interrupt's vector (16#B0
  plus the level, a word by value) and call that level's handler
  without polling the adapter: the SAU4's sets the level's bit in the
  adapter's register at +0x82 and clears it after a true answer, the
  SAU6's touches no register.  To be written with their parts when those
  SAUs are translated; the code below is the SAU3's
  (`mbus_polled_adapter'). }

{ TODO(pascal) 4 frame bytes unexplained

  The image's frame is 16#14 bytes; these locals give 16#10.  No local
  of the image's code uses the other 4, and no other SAU's MBUS_$INT
  has this form, so no stand-in is added. }

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
