{ COLOR7_$START_WIRED_PROC - mark the start of the driver's wired code.

  Image addresses:
    sau7  0x3C48CDFC  COLOR7_$START_WIRED_PROC

  - An empty procedure, the first of the wired section: its address
    starts the code area of COLOR7_$WIRED_DATA.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_$start_wired_proc;
begin
end;
