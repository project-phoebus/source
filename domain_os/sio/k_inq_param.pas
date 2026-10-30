{ SIO_$K_INQ_PARAM - a serial line's parameters.

  Image addresses:
    sau2  0x00E6832A  SIO_$K_INQ_PARAM

  - The descriptor's parameter block is copied out, the driver's
    inq_params entry filling in the live values for the mask's
    selectors.

  Status stored:
    the driver's inq_params status: the line has a descriptor
    sio_$i_get_desc's status: it has none
}

{ TODO(pascal) SIO_$K_INQ_PARAM's frame has 4 bytes no object explains

  The frame has 8 bytes: desc 4; the 4 below are reached by no
  instruction (the stand-in unused_8), the 4 bytes TTY_$K_FLUSH_INPUT
  has over its locals: see the TODO(pascal) in tty/k_flush_input.pas, which
  names this routine. }

procedure sio_$k_inq_param(in line: integer; out params: sio_$params_t;
                           in mask: sio_$flags_t; out status: status_$t);
var
  desc: integer32;                        { SIO_$I_GET_DESC's parked result }
  unused_8: integer32;                    { stand-in, see the TODO }
begin
  desc := sio_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  params := sio_$desc_ptr_t(desc)^.params;
  sio_$inq_params_t(sio_$desc_ptr_t(desc)^.driver.inq_params)^(
    sio_$desc_ptr_t(desc)^.context, params, mask, status);
end;
