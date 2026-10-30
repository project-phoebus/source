{ RING_INTERRUPT - the ring's first-level interrupt routine.

  Image addresses:
    sau2  0x00E0AB0C  RING_INTERRUPT

  - Calls the do_io routine SYSBUS_$INIT installed for the type-2 (ring)
    controller, with its DCTE (RING_$INT).
  - A fragment of ATBUS_ (sysbus/atbus_.pas), whose module variables
    type2_do_io and type2_dcte it names.  A global without `$'.

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure ring_interrupt;
begin
  type2_do_io^(type2_dcte^);
end;
