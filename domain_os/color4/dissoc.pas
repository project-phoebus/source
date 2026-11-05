{ COLOR4_$DISSOC - dissociate the board from the current process.

  Image addresses:
    sau7  0x3C483EF0  COLOR4_$DISSOC
    sau8  0x03C7979C  COLOR4_$DISSOC

  - Only the owner gives the board up; its registers stay mapped in its
    address space.

  Status stored:
    status_$ok: always
}

procedure color4_$dissoc(dcte: color4_$dcte_ptr_t; out status: status_$t);
  options(val_param);
begin
  with dcte^.info^ do
    if owner = proc1_$current then
      owner := 0;
  status.all := status_$ok;
end;
