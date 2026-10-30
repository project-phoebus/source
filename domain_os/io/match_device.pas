{ io_$match_device - whether two of the PROM's device records name one device.

  Image addresses:
    sau9  0x3C439010  io_$match_device (module-local)

  - Both must be valid, with the same name and kind; the unit and the
    controller are compared only where both records give them.

  Returns:
    true: the records name one device

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function io_$match_device(in a: univ os_$prom_device_t;
                          in b: univ os_$prom_device_t): boolean;
  internal;
begin
  io_$match_device := false;
  if a.valid and then b.valid
     and then (a.id = b.id)
     and then (a.kind = b.kind)
     and then (not (a.has_unit and then b.has_unit)
               or else (a.unit = b.unit))
     and then (not (a.has_ctlr and then b.has_ctlr)
               or else (a.ctlr = b.ctlr)) then
    io_$match_device := true;
end;
