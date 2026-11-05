{ COLOR2_$ENABLE_GPU_INT - enable the graphics processor's interrupt.

  Image addresses:
    sau5  0x00E73552  COLOR2_$ENABLE_GPU_INT
    sau6  0x7807A46E  COLOR2_$ENABLE_GPU_INT

  - Member 2 of the board's control word (a word set) is removed and
    member 7 added, in place.

  Status stored:
    status_$ok: always
}

procedure color2_$enable_gpu_int(out status: status_$t);
begin
  status.all := status_$ok;
  kolor_ctl.ctl := kolor_ctl.ctl - [2];
  kolor_ctl.ctl := kolor_ctl.ctl + [7];
end;
