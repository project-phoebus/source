{ XPD_$INIT - wire and clear XPD's tables at boot.

  Image addresses:
    sau2  0x00E32304  XPD_$INIT

  - The pages from XPD_$DATA to PROC2_$DATA (at most three) are wired,
    XPD_$DATA zeroed, and the eventcount of every target record and
    debugger slot initialized.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure xpd_$init;
var
  page_list: array[1..3] of integer32;
  page_count: integer;
  i: integer;
  j: integer;
begin
  mst_$wire_area(addr(xpd_$targets), addr(proc2_$info_table), page_list, 3,
                 page_count);

  os_$data_zero(xpd_$targets, 16#4E8);

  for i := 0 to 57 do
    ec_$init(xpd_$targets[i].ec);

  for j := 1 to 6 do
    ec_$init(xpd_$debuggers[j].ec);
end;
