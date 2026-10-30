{ FLP_$SHUTDOWN - mark a drive inactive and count the active ones.

  Image addresses:
    sau2  0x00E3E228  FLP_$SHUTDOWN

  - The result is the number of the four units still active; ctlr is
    not read.

  Status stored: none.
}

function flp_$shutdown(ctlr: pinteger; unit: pinteger): integer;
  options(val_param);
var
  count: integer;
  i: integer;
  unused_8: integer32;                    { stand-in }
begin
  flp_unit_active[unit] := false;

  count := 0;
  for i := 0 to 3 do
    if flp_unit_active[i] then
      count := count + 1;
  flp_$shutdown := count;
end;
