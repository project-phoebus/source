{ COLOR7_$END_WIRED_PROC - mark the end of the driver's wired code.

  Image addresses:
    sau7  0x3C48D52C  COLOR7_$END_WIRED_PROC

  - An empty procedure, the last of the wired section: its address ends
    the code area of COLOR7_$WIRED_DATA.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_$end_wired_proc;
begin
end;
