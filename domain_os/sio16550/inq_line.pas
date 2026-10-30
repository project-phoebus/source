{ SIO16550_$INQ_LINE - report a channel's modem inputs.

  Image addresses:
    sau9  0x3C47A02C  SIO16550_$INQ_LINE

  - Member 8 of mask reports CTS as member 1 of the first flags, member
    7 DCD as member 2; the channel's line_flags are added in either
    case.

  Status stored:
    status_$ok: always
}

[section(procedure$, data$)]
procedure sio16550_$inq_line(in chan: sio16550_$chan_t;
                             in out params: sio_$params_t;
                             mask: sio_$flags_t; out status: status_$t);
  options(val_param);
var
  msr: sio16550_$bits_t;
begin
  status.all := status_$ok;
  msr.c := chan.regs^.msr;
  if 8 in mask then
    if sio16550_$msr_cts in msr.s then
      params.flags1 := params.flags1 + [1]
    else
      params.flags1 := params.flags1 - [1];
  if 7 in mask then
    if sio16550_$msr_dcd in msr.s then
      params.flags1 := params.flags1 + [2]
    else
      params.flags1 := params.flags1 - [2];
  params.flags1 := params.flags1 + chan.line_flags;
end;
