{ SMD_$NOP_LOGO - the default for a device's boot logo.

  Image addresses:
    sau7  0x3C480C96  SMD_$NOP_LOGO
    sau9  0x3C4743B6  SMD_$NOP_LOGO

  - Draws nothing.

  Status stored:
    status_$ok: always
}

procedure smd_$nop_logo(dcte: univ_ptr; logo: smd_logo_ptr_t;
                        out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
end;
