{ FLP_$SHUTDOWN - mark a drive inactive and count the active ones.

  Image addresses:
    sau2  0x00E3E228  FLP_$SHUTDOWN
    sau4  0x0F8461F0  FLP_$SHUTDOWN
    sau7  0x3C44E54C  FLP_$SHUTDOWN
    sau8  0x03C46434  FLP_$SHUTDOWN

  - The result is the number of the four units still active; ctlr is
    not read.
  - The AT bus form releases the controller's interrupt unit when no
    drive is left active, and then returns no count; with
    `floppy_iomap' it frees the unit's I/O map region first.
  - The page DMA form, with no drive active, frees the unit's I/O map
    space when its flag is set; the result is then not set.

  Status stored: none.
}

%if floppy_atbus %then
function flp_$shutdown(ctlr: pinteger; unit: pinteger): integer;
  options(val_param);
var
  count: integer;
  i: integer;
  status: status_$t;
begin
  flp_unit_active[unit] := false;

  count := 0;
  for i := 0 to 3 do
    if flp_unit_active[i] then
      count := count + 1;
  if count > 0 then
    flp_$shutdown := count
  else begin
%if floppy_iomap %then
    if flp_map_allocated then begin
      io_$free_map(flp_io_unit, status);
      flp_map_allocated := false;
    end;
%endif
    io_$release(flp_io_unit, status);
  end;
end;
%elseif floppy_page_dma %then
function flp_$shutdown(ctlr: pinteger; unit: pinteger): integer;
  options(val_param);
var
  count: integer;
  i: integer;
  status: status_$t;
begin
  flp_unit_active[unit] := false;

  count := 0;
  for i := 0 to 3 do
    if flp_unit_active[i] then
      count := count + 1;
  if count > 0 then
    flp_$shutdown := count
  else if flp_map_allocated then begin
    io_$free_map(flp_io_unit, status);
    flp_map_allocated := false;
  end;
end;
%else

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
%endif
