{ SYSBUS_$INT - dispatch a system bus interrupt to its level's handler.

  Image addresses:
    sau4  0x0F80B2CC  SYSBUS_$INT
    sau9  0x3C40C438  SYSBUS_$INT

  - A vector outside 16#A0..16#AF crashes the system (with
    `sysbus_vectors_90', outside 16#90..16#9F and 16#F0..16#FF).
  - The second range's levels are 15..30.
  - With `util_pic' the level is disabled while its handler runs, and
    enabled again only when the handler returns true.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `sysbus_int_vec'.

  Status stored: none.
}

{ TODO(sau) SYSBUS_$INT on the SAU6

  The SAU6's SYSBUS_$INT takes two ranges of vectors (16#88..16#9F and
  16#F0..16#F7), with a second, duplicate vector it calls when the first
  handler returns false; it does not mask the level.  To be written as a
  conditional arm when that SAU is translated. }

[section(wired_proc, wired_data)]
procedure sysbus_$int(vector: integer);
  options(val_param);
var
  level: sysbus_$level_t;
  handler: sysbus_$handler_t;
  handler_arg: univ_ptr;
begin
  if (vector >= sysbus_$first_vector) and then
     (vector <= sysbus_$last_vector) then
    level := vector - sysbus_$first_vector
%if sysbus_vectors_90 %then
  else if (vector >= sysbus_$first_vector_2) and then
          (vector <= sysbus_$last_vector_2) then
    level := vector - (sysbus_$first_vector_2 - sysbus_$last_vector)
             - sysbus_$first_vector
%endif
  else
    crash_system(status_$sysbus_unknown_interrupt_id);
  handler := sysbus_$int_vec[level].handler;
  handler_arg := sysbus_$int_vec[level].handler_arg;
%if util_pic %then
  if level < sysbus_$first_hi_level then
    util_pic.enable_lo := util_pic.enable_lo - [level]
  else
    util_pic.enable_hi :=
      util_pic.enable_hi - [level - sysbus_$first_hi_level];
  if handler^(handler_arg) then
    if level < sysbus_$first_hi_level then
      util_pic.enable_lo := util_pic.enable_lo + [level]
    else
      util_pic.enable_hi :=
        util_pic.enable_hi + [level - sysbus_$first_hi_level];
%else
  discard(handler^(handler_arg));
%endif
end;
