{ FIM_$ACKNOWLEDGE - acknowledge a quit for the current address space.

  Image addresses:
    sau2  0x00E0A96C  FIM_$ACKNOWLEDGE
    sau4  0x0F80B0B4  FIM_$ACKNOWLEDGE
    sau9  0x3C40C2FC  FIM_$ACKNOWLEDGE

  Status stored: none.
}

procedure fim_$acknowledge;
begin
  fim_$quit_value[proc1_$as_id] := fim_$quit_ec[proc1_$as_id].value;

  fim_$quit_inh[proc1_$as_id] := false;

  ec_$advance(fim_$deliv_ec[proc1_$as_id]);
end;
