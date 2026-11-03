{ MONO_$VIDEO_CTL - turn the video on or off.

  Image addresses:
    sau8  0x03C79C12  MONO_$VIDEO_CTL

  - The control word's video enable is set from on, with the display
    acquired (SMD_$ACQ_DISPLAY, SMD_$REL_DISPLAY).

  Status stored: none.
}

procedure mono_$video_ctl(dcte: mono_$dcte_ptr_t; on: boolean);
  options(val_param);
begin
  discard(smd_$acq_display(0));
  with dcte^.info^.regs^ do
    ctl.video_on := on;
  smd_$rel_display;
end;
