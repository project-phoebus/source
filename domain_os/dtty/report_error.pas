{ dtty_$report_error - print an SMD failure on the console.

  Image addresses:
    sau2  0x00E1D5B2  dtty_$report_error
    sau4  0x0F81E89C  dtty_$report_error
    sau6  0x7801F7CC  dtty_$report_error
    sau7  0x3C421876  dtty_$report_error
    sau9  0x3C41FF8E  dtty_$report_error

  - "Error status <status> returned from <func_name>", then " while
    attempting to <context>" unless the context starts with `$'.

  Status stored: none.
}

procedure dtty_$report_error(in status: status_$t;
                             in func_name: univ vfmt_$string_t;
                             in context: univ vfmt_$string_t); internal;
begin
  vfmt_$write2('%/Error status %h returned from %$', status, 0);
  vfmt_$write2(func_name, 0, 0);

  if context[1] <> '$' then begin
    vfmt_$write2(' while attempting to%.', 0, 0);
    vfmt_$write2(context, 0, 0);
  end;

  vfmt_$write2('%.', 0, 0);
end;
