{ SMD_$NOP_FIFOWAIT - the default for a device's FIFO wait: nothing.

  Image addresses:
    sau7  0x3C421A30  SMD_$NOP_FIFOWAIT
    sau9  0x3C420148  SMD_$NOP_FIFOWAIT

  Status stored: none.
}

[section(wired_proc, wired_data)]
procedure smd_$nop_fifowait(dcte: univ_ptr);
  options(val_param);
begin
end;
