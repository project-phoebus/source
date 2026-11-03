{ io_$check_unit - check that a unit number names an acquired unit.

  Image addresses:
    sau2  0x00E1A4A4  io_$check_unit
    sau3  0x00E1953C  io_$check_unit
    sau4  0x0F81B10C  io_$check_unit
    sau5  0x00E1A7EC  io_$check_unit
    sau8  0x03C1B628  io_$check_unit

  - The result is whether the status is ok.

  Status stored:
    status_$ok: the unit is acquired
    status_$io_illegal_unit_number: a unit above 31
    status_$io_unit_not_acquired: a free slot of IO_$DCTES
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_c)

  The SAU2 frame is 12 bytes: the 4-byte slot of a routine that is not a
  global symbol and the boolean result variable account for 8.  The
  stand-in unused_c holds the other 4; nothing addresses the frame.  A
  lead: the image loads the slot's tag into a register and branches on
  the load's flags, where IO_$ACQUIRE tests the same field directly: a
  word local assigned the tag and then tested would take 2 of the 4
  bytes and give the load; dpc gives the test. }

function io_$check_unit(unit: io_$unit_num_t;
                        out status: status_$t): boolean;
  internal;
var
  unused_c: integer32;                    { the stand-in (TODO) }
begin
  status.all := status_$ok;
  if not in_range(unit) then
    status.all := status_$io_illegal_unit_number
  else if io_$dctes[unit].tag = 0 then
    status.all := status_$io_unit_not_acquired;

  io_$check_unit := status.all = status_$ok;
end;
