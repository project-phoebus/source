{ COLOR7_$SHUTDOWN - give up the board at shutdown.

  Image addresses:
    sau7  0x3C48495C  COLOR7_$SHUTDOWN

  - The current process takes the registers over and gives them back
    (COLOR7_$DISSOC); the status is dropped.

  Status stored: none.
}

procedure color7_$shutdown(dcte: color7_$dcte_ptr_t);
  options(val_param);
var
  status: status_$t;
begin
  color7_static.owner := proc1_$current;
  color7_$dissoc(dcte, status);
end;
