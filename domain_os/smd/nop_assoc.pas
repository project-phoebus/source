{ SMD_$NOP_ASSOC - the default for a device's association with a process.

  Image addresses:
    sau9  0x3C4743A2  SMD_$NOP_ASSOC

  - Maps nothing: the address is nil.

  Status stored:
    status_$ok: always
}

procedure smd_$nop_assoc(dcte: univ_ptr; out va: univ_ptr;
                         out status: status_$t);
  options(val_param);
begin
  va := nil;
  status.all := status_$ok;
end;
