{ SMD_$NOP_UNMAP - the default for a device's display memory unmap.

  Image addresses:
    sau9  0x3C474394  SMD_$NOP_UNMAP

  Status stored:
    status_$ok: always
}

procedure smd_$nop_unmap(dcte: univ_ptr; arg_2: integer32;
                         arg_3: integer32; va: univ_ptr;
                         out status: status_$t);
  options(val_param);
begin
  status.all := status_$ok;
end;
