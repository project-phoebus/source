{ SIO2681_$SET_BREAK - start or stop a break on a channel.

  Image addresses:
    sau2  0x00E1D114  SIO2681_$SET_BREAK
    sau3  0x00E1C288  SIO2681_$SET_BREAK
    sau4  0x0F81E328  SIO2681_$SET_BREAK
    sau6  0x7801F208  SIO2681_$SET_BREAK
    sau7  0x3C4214F4  SIO2681_$SET_BREAK
    sau8  0x03C1E8AC  SIO2681_$SET_BREAK

  - Under the driver's spin lock the start-break command (enable true)
    or the stop-break command is written; the line's output is then
    restarted (SIO_$I_TSTART).

  Status stored: none.
}

procedure sio2681_$set_break(in channel: sio2681_$channel_t; enable: boolean);
  options(val_param);
var
  token: integer;
begin
  token := ml_$spin_lock(spin_lock);

  if enable then
    channel.regs^.cra := cmd_break_start
  else begin
    channel.regs^.cra := cmd_break_stop;
    sio_$i_tstart(channel.sio_desc);
  end;

  ml_$spin_unlock(spin_lock, token);
end;
