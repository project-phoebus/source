{ sio_$set_break - raise or drop a break on a serial line.

  Image addresses:
    sau2  0x00E67E86  sio_$set_break (module-local)
    sau4  0x0F87197A  sio_$set_break (module-local)
    sau6  0x78070B62  sio_$set_break (module-local)
    sau7  0x3C47B4CA  sio_$set_break (module-local)

  - Under SIO's spin lock the break member (3) is set and the
    transmit-active member (0) cleared, or the break member cleared;
    the driver's set_break entry gets the same flag.

  Status stored: none.
}

procedure sio_$set_break(desc: sio_$desc_ptr_t; enable: boolean); internal;
var
  token: integer;
begin
  token := ml_$spin_lock(sio_$spin_lock);
  if enable then begin
    desc^.state := desc^.state - [0];
    desc^.state := desc^.state + [3];
  end
  else
    desc^.state := desc^.state - [3];
  ml_$spin_unlock(sio_$spin_lock, token);
  sio_$set_break_t(desc^.driver.set_break)^(desc^.context, enable);
end;
