{ OS_$INIT_POWER_OFF_CHECK - start watching the power-off request.

  Image addresses:
    sau5  0x00E36C14  OS_$INIT_POWER_OFF_CHECK

  - Compiled only with `power_off_check' (base/config.ins.pas).
  - Enters the repeating element whose callback, OS_$CHECK_POWER_OFF,
    runs about every two seconds at interrupt level.
  - Its static, the element, opens the module's WIRED_DATA block (0x20
    bytes, shared with OS_$CHECK_POWER_OFF), so the routine is headed
    with WIRED_DATA as its data section.

  Status stored: none.
}

{ TODO(pascal) the WIRED_DATA block's word at +0x1A

  The element is 0x1A bytes and the callback's flag lies at +0x1C: no
  instruction reaches +0x1A..+0x1B.  The block's other routines' statics
  give no rule (a longword-aligned start of each routine's statics, or
  the element rounded to 4 by its longword fields, would both explain
  it; os/os.pas's .DATA +0x0E is the same question).  The stand-in
  unused_1a holds the place. }

%if power_off_check %then
[section(os_init_proc, wired_data)]
procedure os_$init_power_off_check;
var
  status: status_$t;
  now: time_$clock_t;
  elem: static time_$queue_elem_t := [
    callback := addr(os_$check_power_off),
    expire := [high := 8, low := 0],
    flags := [1],
    interval := [high := 8, low := 0]];  { WIRED_DATA +0x00 }
  unused_1a: static integer;              { WIRED_DATA +0x1A, a stand-in }
begin
  time_$abs_clock(now);
  add48(elem.expire, now);
  time_$q_enter_elem(time_$rteq, now, elem, status);
end;
%endif
