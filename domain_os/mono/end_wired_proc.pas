{ MONO_$END_WIRED_PROC - mark the end of the driver's wired code.

  Image addresses:
    sau8  0x03C812A0  MONO_$END_WIRED_PROC

  - An empty procedure, the last of the wired section: its address ends
    the code area of MONO_$WIRED_DATA.

  Status stored: none.
}

[section(mono_wired_proc, wired_data)]
procedure mono_$end_wired_proc;
begin
end;
