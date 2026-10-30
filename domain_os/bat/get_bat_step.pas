{ BAT_$GET_BAT_STEP - return a volume's BAT step.

  Image addresses:
    sau2  0x00E3BB58  BAT_$GET_BAT_STEP

  Status stored: none.
}

function bat_$get_bat_step(vol_idx: integer): pinteger;
begin
  bat_$get_bat_step := bat_data[vol_idx].hdr.bat_step;
end;
