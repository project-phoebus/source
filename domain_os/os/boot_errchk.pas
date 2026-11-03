{ OS_$BOOT_ERRCHK - report a boot-time error status on the console.

  Image addresses:
    sau2  0x00E34B14  OS_$BOOT_ERRCHK
    sau3  0x00E32E5A  OS_$BOOT_ERRCHK
    sau5  0x00E36C5A  OS_$BOOT_ERRCHK
    sau8  0x03C383C4  OS_$BOOT_ERRCHK
    sau9  0x3C43B1AE  OS_$BOOT_ERRCHK

  - A status whose code (its low word) is 0 is no error: the result is
    true.
  - Any other is shown on the crash console with format_str (up to its
    first `%', within 50 characters) and arg_str (line characters),
    followed by a five-tick wait; the result is false.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function os_$boot_errchk(in format_str: univ crash_$chars_t;
                         in arg_str: univ crash_$chars_t;
                         in line: integer; status: status_$t): boolean;
var
  buf: array[1..100] of char;
  arg_len: integer32;
  msg_len: integer32;
  k: integer32;
  wait_status: status_$t;
  out_len: integer;
  i: integer;
  wait_delay: static time_$clock_t := [high := 5, low := 0];
                                          { OS_INIT_DATA +0x180 }
begin
  if status.code <> 0 then begin
    { the message's length, the index of its first `%' }
    msg_len := 0;
    k := 1;
    for i := 1 to 50 do begin
      if format_str[k] = '%' then begin
        msg_len := k - 1;
        exit;
      end;
      k := k + 1;
    end;

    arg_len := line;

    vfmt_$encode5('%/%/%a %a -- %lh%/%%%$', buf, 100, out_len,
                  format_str, msg_len, arg_str, arg_len, status);
    crash_show_string(buf);
    time_$wait(time_$relative, wait_delay, wait_status);
    os_$boot_errchk := false;
  end
  else
    os_$boot_errchk := true;
end;
