{ TPAD_$RE_RANGE - restart the current unit's touchpad ranging.

  Image addresses:
    sau2  0x00E69A0E  TPAD_$RE_RANGE
    sau4  0x0F8734D4  TPAD_$RE_RANGE
    sau6  0x78072630  TPAD_$RE_RANGE
    sau7  0x3C47CFA8  TPAD_$RE_RANGE

  - TPAD_$RE_RANGE_UNIT for the current unit; its status is ignored.

  Status stored: none.
}

procedure tpad_$re_range;
var
  status: status_$t;
begin
  tpad_$re_range_unit(tpad_$unit, status);
end;
