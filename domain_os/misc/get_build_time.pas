{ GET_BUILD_TIME - format the kernel's identification line.

  Image addresses:
    sau2  0x00E38052  GET_BUILD_TIME

  - "<name>[(<machine id>)], revision ", the revision numbers (two to
    four, by which are set), then the date and time or the time alone;
    the length is handed back.
  - The text is '?' when OS_$REV's first longword is not zero.

  Status stored: none.
}

{ TODO(pascal) GET_BUILD_TIME's sau held in a register and stored for
  the call

  The machine id's word is read into a register at entry, before the
  os_rev test, tested there and stored to its frame word only on the
  path that passes it by address to VFMT_$ENCODE5.  Read as one
  variable, sau, assigned first and held in a register between its uses
  although its address is passed: the shape of VFMT_$MAIN's and
  VFMT_$WRITE's variables (see the TODO on registers in vfmt/main.pas).
  Two variables (a register-held id and a frame sau := id inside the
  `then' part) would fit dpc's rule (a register-held local keeps a
  slot), but the frame then has 2 bytes too few: the expression
  temporary lies right below sau, where the register-held one's slot
  would be. }

procedure get_build_time(out buf: univ vfmt_$string_t; out len: integer);
var
  seg_len: integer;
  sau: integer;
begin
  sau := prom_$machine_id.sau;

  if os_$rev.os_rev <> 0 then begin
    len := 1;
    buf[1] := '?';
    return;
  end;

  { the name, and the machine id when there is one }
  if sau <> 0 then
    vfmt_$encode5('%a(%wd), revision %$', buf, 100, len,
                  os_$rev.name, os_$rev.name_len, sau, 0, 0)
  else
    vfmt_$encode2('%a, revision %$', buf, 100, len,
                  os_$rev.name, os_$rev.name_len);

  { the revision }
  if os_$rev.build <> 0 then
    vfmt_$encode5('%wd.%wd.%wd.%wd,%$', buf[len + 1], 100 - len, seg_len,
                  os_$rev.major, os_$rev.minor, os_$rev.patch,
                  os_$rev.build, 0)
  else if os_$rev.patch = 0 then
    vfmt_$encode2('%wd.%wd,%$', buf[len + 1], 100 - len, seg_len,
                  os_$rev.major, os_$rev.minor)
  else
    vfmt_$encode5('%wd.%wd.%wd,%$', buf[len + 1], 100 - len, seg_len,
                  os_$rev.major, os_$rev.minor, os_$rev.patch, 0, 0);
  len := len + seg_len;

  { the date and time, or the time }
  if os_$rev.date_len <> 0 then
    vfmt_$encode5(' %a  %a %$', buf[len + 1], 100 - len, seg_len,
                  os_$rev.date, os_$rev.date_len,
                  os_$rev.time, os_$rev.time_len, 0)
  else
    vfmt_$encode2(' %a %$', buf[len + 1], 100 - len, seg_len,
                  os_$rev.time, os_$rev.time_len);
  len := len + seg_len;
end;
