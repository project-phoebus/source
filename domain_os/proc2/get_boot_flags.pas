{ PROC2_$GET_BOOT_FLAGS - return the boot flags word.

  Image addresses:
    sau2  0x00E41B56  PROC2_$GET_BOOT_FLAGS

  Status stored: none.
}

procedure proc2_$get_boot_flags(out flags_ret: integer);
begin
  flags_ret := proc2_$boot_flags.w;
end;
