{ SIO2681_$INQ_LINE - report a channel's modem inputs.

  Image addresses:
    sau2  0x00E725B0  SIO2681_$INQ_LINE
    sau3  0x00E73BAC  SIO2681_$INQ_LINE
    sau4  0x0F87FB8C  SIO2681_$INQ_LINE
    sau6  0x78080AF0  SIO2681_$INQ_LINE
    sau7  0x3C488C90  SIO2681_$INQ_LINE
    sau8  0x03C7CF0C  SIO2681_$INQ_LINE

  - When the mask asks for CTS (member 8) or DCD (member 7), the chip's
    input port is read: CTS and DCD are inputs 0 and 2 for channel A, 1
    and 3 for B, low active.
  - CTS becomes member 1 of flags1, DCD member 2 (set anyway when member
    6 of flags2 is); the channel's reserved_14 set is unioned in.

  Status stored:
    status_$ok: always
}

[section(procedure$, data$)]
procedure sio2681_$inq_line(in channel: sio2681_$channel_t;
                            in out params: sio_$params_t;
                            mask: sio2681_$mask_t; out status: status_$t);
  options(val_param);
var
  ipr: sio2681_$ports_t;
  cts: boolean;
  dcd: boolean;
  chip: sio2681_$chip_ptr_t;
begin
  status.all := status_$ok;

  if mask * [7, 8] <> [] then begin
    chip := channel.chip;
    ipr.c := chip^.regs^.ipr_opcr;
    if 1 in channel.chan_flags then begin
      cts := not ipr.cts_a;
      dcd := not ipr.dcd_a;
    end
    else begin
      cts := not ipr.cts_b;
      dcd := not ipr.dcd_b;
    end;
    if 8 in mask then
      if cts then
        params.flags1 := params.flags1 + [1]
      else
        params.flags1 := params.flags1 - [1];
    if 7 in mask then
      if dcd or else (6 in params.flags2) then
        params.flags1 := params.flags1 + [2]
      else
        params.flags1 := params.flags1 - [2];
    params.flags1 := params.flags1 + channel.reserved_14;
  end;
end;
