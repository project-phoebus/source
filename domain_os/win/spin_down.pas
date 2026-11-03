{ WIN_$SPIN_DOWN - stop the drive's spindle.

  Image addresses:
    sau2  0x00E19BC0  WIN_$SPIN_DOWN
    sau4  0x0F81A6D4  WIN_$SPIN_DOWN
    sau5  0x00E1A0A4  WIN_$SPIN_DOWN
    sau8  0x03C1A010  WIN_$SPIN_DOWN

  - The ANSI form issues SPIN CONTROL (16#55) with 0; the result is 20
    when it succeeded, else 0.
  - The descriptor-list form restores drive 0 unless WIN_$DT is set; the
    result is 3.
  - The AT bus form only returns 3.
  - The ring/disk form selects each of the four drives and sequences
    down the ones that answer; the result is 30 when one did, else 0.

  Status stored: none.
}

%if win_descriptor_ctlr %then
function win_$spin_down(in unit: pinteger): integer;
begin
  if win_$dt = 0 then
    discard(restore(unit, 0));
  win_$spin_down := 3;
end;
%elseif win_atbus_ctlr %then
function win_$spin_down(in unit: pinteger): integer;
begin
  win_$spin_down := 3;
end;
%elseif win_ring_disk_ctlr %then
function win_$spin_down(in unit: pinteger): integer;
var
  regs: win_$regs_ptr_t;
  drive: pinteger;
begin
  win_$spin_down := 0;
  regs := win_units[unit].regs;
  for drive := 0 to 3 do begin
    regs^.select := 255 - lshft(16, drive);
    if regs^.cmd <> 255 then begin
      regs^.cmd := win_cmd_sequence_down;
      win_$spin_down := 30;
    end;
  end;
end;
%else

function win_$spin_down(in unit: pinteger): integer;
var
  status: integer32;
  out_byte: win_$byte_t;
begin
  status := win_$ansi_command(unit, 16#55, chr(0), out_byte);
  if status = status_$ok then
    win_$spin_down := 16#14
  else
    win_$spin_down := 0;
end;
%endif
