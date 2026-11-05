{ COLOR6_$END_WIRED_PROC - mark the end of the driver's wired code.

  Image addresses:
    sau7  0x3C48CDFA  COLOR6_$END_WIRED_PROC

  - An empty procedure, the last of the wired section: its address ends
    the code area of COLOR6_$WIRED_DATA.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
procedure color6_$end_wired_proc;
begin
end;
