{ COLOR5_$DISSOC - dissociate the board from the current process.

  Image addresses:
    sau8  0x03C79AD8  COLOR5_$DISSOC

  - Only the owner gives the board up; its registers stay mapped in its
    address space.

  Status stored:
    status_$ok: always
}

procedure color5_$dissoc(dcte: color5_$dcte_ptr_t; out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    if owner = proc1_$current then
      owner := 0;
  status.all := status_$ok;
end;
