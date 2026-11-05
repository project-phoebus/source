{ SM_$SPIN_DOWN - warn about storage module drives still spinning.

  Image addresses:
    sau3  0x00E6E56C  SM_$SPIN_DOWN
    sau4  0x0F877C94  SM_$SPIN_DOWN
    sau5  0x00E6F8C4  SM_$SPIN_DOWN
    sau6  0x78076CF8  SM_$SPIN_DOWN

  - A drive that answers a seek to cylinder 0 is still spinning: the
    routine prints "Warning: storage module unit <n> still spinning."
    on the crash console and returns 20 instead of 0.
  - The controller word is not read.

  Status stored: none.
}

function sm_$spin_down(in ctlr: pinteger): integer;
var
  text: array[1..100] of char;
  status: integer32;
  text_len: integer;
  unit_arg: integer;
  result_val: integer;
  unit: integer;
begin
  result_val := 0;
  for unit := 0 to sm_max_unit do begin
    status := sm_$seek(unit, sm_dcte, 0, 0);
    if status = 0 then begin
      unit_arg := unit;
      vfmt_$encode2('%/%/Warning: storage module unit %wd still spinning.%%%.',
                    text, 100, text_len, unit_arg, 0);
      crash_show_string(text);
      result_val := 20;
    end;
  end;
  sm_$spin_down := result_val;
end;
