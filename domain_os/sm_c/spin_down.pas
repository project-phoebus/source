{ SM_C_$SPIN_DOWN - warn about SM_C drives still spinning.

  Image addresses:
    sau5  0x00E755E0  SM_C_$SPIN_DOWN

  - A unit that answers the restore command is still spinning: a warning
    goes to the crash console, and the result is 20 instead of 0.
  - Any current request is dropped; ctlr is not read.

  Status stored: none.
}

function sm_c_$spin_down(in ctlr: pinteger): integer;
var
  text: array[1..100] of char;
  status: integer32;
  text_len: integer;
  unit_arg: integer;
  result_val: integer;
  unit: integer;
begin
  result_val := 0;
  sm_c_req := nil;
  for unit := 0 to sm_max_unit do begin
    status := sm_c_$command(unit, sm_c_cmd_restore);
    if status = 0 then begin
      unit_arg := unit;
      vfmt_$encode2('%/%/Warning: storage module unit %wd still spinning.%%%.',
                    text, 100, text_len, unit_arg, 0);
      crash_show_string(text);
      result_val := 20;
    end;
  end;
  sm_c_$spin_down := result_val;
end;
