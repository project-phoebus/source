{ SMD_$NOP_MAP - the default for a device's display memory map.

  Image addresses:
    sau9  0x3C474380  SMD_$NOP_MAP

  - Maps nothing: the address is nil.

  Status stored:
    status_$ok: always
}

procedure smd_$nop_map(dcte: univ_ptr; arg_2: integer32;
                       arg_3: integer32; out va: univ_ptr;
                       out status: status_$t);
  options(val_param);
begin
  va := nil;
  status.all := status_$ok;
end;
