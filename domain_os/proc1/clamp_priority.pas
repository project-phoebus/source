{ proc1_$clamp_priority - a priority clamped to 1..16.

  Image addresses:
    sau2  0x00E15222  proc1_$clamp_priority (module-local)
    sau4  0x0F815A96  proc1_$clamp_priority (module-local)
    sau6  0x78015996  proc1_$clamp_priority (module-local)
    sau7  0x3C416EEE  proc1_$clamp_priority (module-local)

  - Both compares are unsigned.

  Status stored: none.
}

function proc1_$clamp_priority(value: pinteger): pinteger; internal;
begin
  if value <= 1 then
    proc1_$clamp_priority := 1
  else if value < 16 then
    proc1_$clamp_priority := value
  else
    proc1_$clamp_priority := 16;
end;
