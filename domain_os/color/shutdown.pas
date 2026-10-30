{ COLOR_$SHUTDOWN - give up the color board at shutdown.

  Image addresses:
    sau5  0x00E72DD8  COLOR_$SHUTDOWN

  - Once the board has been associated, the current process takes it
    over and gives it back (COLOR_$DISSOC).

  Status stored: none.
}

procedure color_$shutdown;
begin
  if color_associated then begin
    color_owner := proc1_$current;
    color_$dissoc;
  end;
end;
