{ IO_$DEVICE_INTERRUPTING - ask a unit's bus whether its device is
  interrupting.

  Image addresses:
    sau2  0x00E1A748  IO_$DEVICE_INTERRUPTING
    sau5  0x00E1AAA6  IO_$DEVICE_INTERRUPTING
    sau9  0x3C41D296  IO_$DEVICE_INTERRUPTING

  - The result is the bus's device_interrupting answer for the unit's
    interrupt id; for a unit not acquired it is not set.

  Status stored:
    io_$check_unit's status: always
}

function io_$device_interrupting(unit: io_$unit_num_t;
                                 out status: status_$t): boolean;
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      io_$device_interrupting :=
        io_$bus_epv[bus].device_interrupting^(int.id);
end;
