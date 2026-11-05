{ SIO_$I_GET_DESC - the SIO descriptor of a terminal line.

  Image addresses:
    sau2  0x00E667C6  SIO_$I_GET_DESC
    sau3  0x00E67730  SIO_$I_GET_DESC
    sau4  0x0F8702BA  SIO_$I_GET_DESC
    sau6  0x7806F4DA  SIO_$I_GET_DESC
    sau7  0x3C479E42  SIO_$I_GET_DESC

  - The real line's DTTE entry's SIO descriptor is the result.  A
    fragment of the OS_TERM module (term/os_term.pas), not of SIO.
  - On the two error exits the result is not assigned.

  Status stored:
    term_$get_real_line's status: the line was mapped, or not
    status_$requested_line_or_operation_not_implemented: the entry has
      no SIO descriptor
}

function sio_$i_get_desc(line: integer; out status: status_$t):
  integer32; options(val_param, a0_return);
var
  real_line: pinteger;                    { the result variable lies
                                            above it }
begin
  real_line := term_$get_real_line(line, status);
  if status.all <> status_$ok then
    return;

  { the line must have an SIO descriptor }
  if dtte[real_line].tty_handler = nil then begin
    status.all := status_$requested_line_or_operation_not_implemented;
    return;
  end;

  sio_$i_get_desc := integer32(dtte[real_line].tty_handler);
end;
