{ COLOR6_$VIDEO_CTL - turn the video on or off.

  Image addresses:
    sau7  0x3C4836F8  COLOR6_$VIDEO_CTL

  - At the unit's page, with the control longword at +0xC00 set to the
    video's access value for the change and restored after it.

  Status stored: none.
}

procedure color6_$video_ctl(dcte: color6_$dcte_ptr_t; on: boolean);
  options(val_param);
var
  info: color6_$info_ptr_t;
  regs: color6_$regs_ptr_t;
  saved: color6_$byte_t;
  ctl: integer32;
begin
  info := dcte^.info;
  regs := info^.regs;
  saved := color6_get_page(regs);
  color6_set_page(info^.regs, dcte^.cnum);
  ctl := regs^.ctl_c00;
  regs^.ctl_c00 := color6_swap32(16#C0000080);
  if on then
    regs^.video := regs^.video ! color6_swap16(16#8000)
  else
    regs^.video := regs^.video & color6_swap16(16#7FFF);
  regs^.ctl_c00 := ctl;
  color6_set_page(info^.regs, saved);
end;
