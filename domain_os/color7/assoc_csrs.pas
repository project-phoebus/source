{ COLOR7_$ASSOC_CSRS - give the current process the board's registers.

  Image addresses:
    sau7  0x3C484716  COLOR7_$ASSOC_CSRS

  - The registers are at their fixed address: va is it, and the current
    process and address space become their owner; then the video is
    turned on (COLOR7_$VIDEO_CTL).

  Status stored:
    status_$ok: always
}

procedure color7_$assoc_csrs(dcte: color7_$dcte_ptr_t; out va: univ_ptr;
                             out status: status_$t);
  options(val_param);
begin
  va := color7_static.regs;
  status.all := status_$ok;
  color7_static.asid := proc1_$as_id;
  color7_static.owner := proc1_$current;
  color7_$video_ctl(dcte, true);
end;
