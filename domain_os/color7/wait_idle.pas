{ color7_wait_idle - wait until the drawing engine is idle.

  Image addresses:
    sau7  0x3C48CDFE  color7_wait_idle (module-local)

  - The engine's status is polled until its busy field is 0, up to 1000
    times, without a wait between the polls.

  Status stored: none.
}

[section(color7_wired_proc, wired_data)]
procedure color7_wait_idle;
var
  st: color7_$status_t;
  i: integer;
begin
  with color7_static do
    for i := 1 to color7_$idle_polls do begin
      st := color7_$status_reg_ptr_t(integer32(regs) +
                                    color7_$status_offset)^.status;
      if st.busy = 0 then
        exit;
    end;
end;
