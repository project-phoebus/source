{ RING_$SEND_NULL - an empty procedure.

  Image addresses:
    sau2  0x00E75914  RING_$SEND_NULL
    sau4  0x0F8831B0  RING_$SEND_NULL
    sau8  0x03C81F1E  RING_$SEND_NULL

  - unit, by address and not read: the SAU4's WIN_$DO_IO, its one
    caller, passes its controller's unit word.

  Status stored: none.
}

procedure ring_$send_null(in unit: integer);
begin
end;
