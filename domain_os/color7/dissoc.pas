{ COLOR7_$DISSOC - dissociate the board from the current process.

  Image addresses:
    sau7  0x3C48475A  COLOR7_$DISSOC

  - The registers have no owner, whichever process asks; then the
    drawing engine is waited for (COLOR7_$BUSY_WAIT).

  Status stored:
    COLOR7_$BUSY_WAIT's status: always
}

procedure color7_$dissoc(dcte: color7_$dcte_ptr_t; out status: status_$t);
  options(val_param);
begin
  color7_static.asid := 0;
  color7_static.owner := 0;
  color7_$busy_wait(dcte, status);
end;
