{ SIO_$K_SET_PARAM - set a serial line's parameters.

  Image addresses:
    sau2  0x00E680AC  SIO_$K_SET_PARAM

  - Each selector's value is checked and compared with a copy of the
    block: an unchanged one drops its selector, a changed one goes into
    the copy.
  - Speeds need both rates at most 16, the break mask no members above
    5; what is left goes to the driver's set_params, and on success the
    copy becomes the descriptor's block.

  Status stored:
    the driver's set_params status: a selector was left
    sio_$i_get_desc's status: no descriptor, or nothing changed
    status_$sio_invalid_param: a value out of its range
}

{ TODO(pascal) SIO_$K_SET_PARAM's frame has 8 bytes no object explains

  The frame has 40 bytes: copy 22, desc 4, changes 4 (register-held,
  its slot kept); the 8 bytes below are reached by no instruction (the
  stand-in unused_28).  See the TODO(pascal) in tty/k_flush_input.pas for the
  parking callers' open frame bytes. }

procedure sio_$k_set_param(in line: integer; in params: sio_$params_t;
                           in mask: sio_$flags_t; out status: status_$t);
var
  copy: sio_$params_t;
  desc: integer32;                        { SIO_$I_GET_DESC's parked result }
  changes: sio_$flags_t;
  unused_28: array[1..2] of integer32;    { stand-in, see the TODO }
begin
  desc := sio_$i_get_desc(line, status);
  if status.all <> status_$ok then
    return;

  changes := mask;
  copy := sio_$desc_ptr_t(desc)^.params;

  { the one-bit selectors }
  if 5 in changes then
    if copy.flags1 * [0] <> params.flags1 * [0] then
      copy.flags1 := (copy.flags1 - [0]) + (params.flags1 * [0])
    else
      changes := changes - [5];
  if 6 in changes then
    if copy.flags1 * [3] <> params.flags1 * [3] then
      copy.flags1 := (copy.flags1 - [3]) + (params.flags1 * [3])
    else
      changes := changes - [6];
  if 11 in changes then
    if copy.flags2 * [2] <> params.flags2 * [2] then
      copy.flags2 := (copy.flags2 - [2]) + (params.flags2 * [2])
    else
      changes := changes - [11];
  if 12 in changes then
    if copy.flags2 * [3] <> params.flags2 * [3] then
      copy.flags2 := (copy.flags2 - [3]) + (params.flags2 * [3])
    else
      changes := changes - [12];
  if 9 in changes then
    if copy.flags2 * [0] <> params.flags2 * [0] then
      copy.flags2 := (copy.flags2 - [0]) + (params.flags2 * [0])
    else
      changes := changes - [9];
  if 10 in changes then
    if copy.flags2 * [1] <> params.flags2 * [1] then
      copy.flags2 := (copy.flags2 - [1]) + (params.flags2 * [1])
    else
      changes := changes - [10];
  if 14 in changes then
    if copy.flags2 * [6] <> params.flags2 * [6] then
      copy.flags2 := (copy.flags2 - [6]) + (params.flags2 * [6])
    else
      changes := changes - [14];

  { the speed }
  if (1 in changes) or else (0 in changes) then begin
    if not ((params.baud_rate.rx <= 16#10)
            and (params.baud_rate.tx <= 16#10)) then begin
      status.all := status_$sio_invalid_param;
      return;
    end;
    if copy.baud_rate = params.baud_rate then
      changes := changes - [0, 1]
    else
      copy.baud_rate := params.baud_rate;
  end;

  { the parity }
  if 2 in changes then begin
    if not in_range(params.parity) then begin
      status.all := status_$sio_invalid_param;
      return;
    end;
    if copy.parity = params.parity then
      changes := changes - [2]
    else
      copy.parity := params.parity;
  end;

  { the stop bits }
  if 3 in changes then begin
    if not in_range(params.stop_bits) then begin
      status.all := status_$sio_invalid_param;
      return;
    end;
    if copy.stop_bits = params.stop_bits then
      changes := changes - [3]
    else
      copy.stop_bits := params.stop_bits;
  end;

  { the character size }
  if 4 in changes then begin
    if not in_range(params.char_size) then begin
      status.all := status_$sio_invalid_param;
      return;
    end;
    if copy.char_size = params.char_size then
      changes := changes - [4]
    else
      copy.char_size := params.char_size;
  end;

  { the break mask }
  if 13 in changes then begin
    if params.break_mask * [6..31] <> [] then begin
      status.all := status_$sio_invalid_param;
      return;
    end;
    if params.break_mask = copy.break_mask then
      changes := changes - [13]
    else
      copy.break_mask := params.break_mask;
  end;

  { the driver }
  if changes <> [] then begin
    sio_$set_params_t(sio_$desc_ptr_t(desc)^.driver.set_params)^(
      sio_$desc_ptr_t(desc)^.context, copy, changes, status);
    if status.all = status_$ok then
      sio_$desc_ptr_t(desc)^.params := copy;
  end;
end;
