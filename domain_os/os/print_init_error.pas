{ os_$print_init_error - show a start-up message on the console.

  Image addresses:
    sau2  0x00E6D1CC  os_$print_init_error (module-local)
    sau3  0x00E6D778  os_$print_init_error (module-local)
    sau5  0x00E6E8A8  os_$print_init_error (module-local)

  Status stored: none.
}

procedure os_$print_init_error(in msg: univ vfmt_$string_t); internal;
begin
  vfmt_$write2(msg, 0, 0);
end;
