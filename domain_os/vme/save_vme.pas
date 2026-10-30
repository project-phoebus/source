{ VME_$SAVE_VME - save the VME bus adapter's state.

  Image addresses:
    sau5  0x00E0ACF4  VME_$SAVE_VME

  - The clock's high half and the adapter's registers go into VME_$SAVE:
    int_status, the words at 0x20, 0x40 .. 0x90, and the 3-bit field of
    the word at 0x30, sign extended.

  Status stored: none.
}

procedure vme_$save_vme;
var
  ctl: ^vme_$ctl_t;
begin
  ctl := addr(vme_ctl);
  vme_$save.clock := time_$clockh;
  vme_$save.word_20 := ctl^.word_20;
  vme_$save.int_status := ctl^.int_status;
  vme_$save.field_30 := ctl^.ctl_30.field;
  vme_$save.word_40 := ctl^.word_40;
  vme_$save.word_50 := ctl^.word_50;
  vme_$save.word_60 := ctl^.word_60;
  vme_$save.word_70 := ctl^.word_70;
  vme_$save.word_80 := ctl^.word_80;
  vme_$save.word_90 := ctl^.word_90;
end;
