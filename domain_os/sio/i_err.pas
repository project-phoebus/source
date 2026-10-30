{ SIO_$I_ERR - take a serial line's pending condition as a status.

  Image addresses:
    sau2  0x00E67D9C  SIO_$I_ERR

  - The conditions asked for (all five, or with check_all false only
    the DCD and CTS changes) are taken off the pending set under SIO's
    spin lock.

  Returns:
    status_$sio_code_0b: condition 5, the first by priority
    status_$sio_framing_error: a framing error
    status_$sio_parity_error: a parity error
    status_$sio_input_overrun: an overrun
    status_$sio_dcd_changed: a DCD change
    status_$sio_cts_changed: a CTS change
    status_$ok: none pending, or none of those taken

  Status stored: none.
}

function sio_$i_err(desc: sio_$desc_ptr_t; check_all: boolean): integer32;
  options(val_param);
var
  taken: sio_$flags_t;                    { the result variable lies
                                            below it }
  token: integer;
begin
  if desc^.pending_int <> [] then begin
    { the conditions taken, under the lock }
    token := ml_$spin_lock(sio_$spin_lock);
    if check_all then
      taken := [0..4]
    else
      taken := [3, 4];
    taken := taken * desc^.pending_int;
    desc^.pending_int := desc^.pending_int - taken;
    ml_$spin_unlock(sio_$spin_lock, token);

    { the first by priority }
    if 5 in taken then
      sio_$i_err := status_$sio_code_0b
    else if 1 in taken then
      sio_$i_err := status_$sio_framing_error
    else if 0 in taken then
      sio_$i_err := status_$sio_parity_error
    else if 2 in taken then
      sio_$i_err := status_$sio_input_overrun
    else if 3 in taken then
      sio_$i_err := status_$sio_dcd_changed
    else if 4 in taken then
      sio_$i_err := status_$sio_cts_changed
    else
      sio_$i_err := status_$ok;
  end
  else
    sio_$i_err := status_$ok;
end;
