{ EC_$INIT - initialize a level-1 eventcount.

  Image addresses:
    sau2  0x00E151FE  EC_$INIT

  - Both waiter list pointers point at the eventcount itself, the ring's
    sentinel (ec/m68k/advance_int.s walks the ring until it comes back
    to it).
  - A fragment of the PROC1_ module (proc1/proc1.pas), not of an EC
    module.

  Status stored: none.
}

procedure ec_$init(out ec: ec_$eventcount_t);
begin
  ec.value := 0;
  ec.waiter_list_head := addr(ec);
  ec.waiter_list_tail := addr(ec);
end;
