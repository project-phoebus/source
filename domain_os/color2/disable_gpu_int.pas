{ COLOR2_$DISABLE_GPU_INT - disable the graphics processor's interrupt.

  Image addresses:
    sau5  0x00E73570  COLOR2_$DISABLE_GPU_INT

  - Member 7 of the board's control word (a word set) is removed and
    member 6 added, in place.

  Status stored:
    status_$ok: always
}

procedure color2_$disable_gpu_int(out status: status_$t);
begin
  status.all := status_$ok;
  kolor_ctl.ctl := kolor_ctl.ctl - [7];
  kolor_ctl.ctl := kolor_ctl.ctl + [6];
end;
