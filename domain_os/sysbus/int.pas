{ SYSBUS_$INT - dispatch a system bus interrupt to its level's handler.

  Image addresses:
    sau4  0x0F80B2CC  SYSBUS_$INT
    sau6  0x7800B424  SYSBUS_$INT
    sau9  0x3C40C438  SYSBUS_$INT

  - A vector outside 16#A0..16#AF crashes the system (with
    `sysbus_vectors_90', outside 16#90..16#9F and 16#F0..16#FF; with
    `sysbus_vectors_88', outside 16#88..16#9F and 16#F0..16#F7).
  - The second range's levels are 15..30 (23..30 with
    `sysbus_vectors_88').
  - With `util_pic' the level is disabled while its handler runs, and
    enabled again only when the handler returns true.
  - With `sysbus_vectors_88', when the handler returns false the
    level's second handler (SYSBUS_$DUP_VEC) is called, its result
    ignored.
  - handler_arg is declared first: every image's frame holds it at the
    top.
  - A fragment of the ATBUS_ module (sysbus/atbus_.pas), with
    `sysbus_int_vec'.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of the `util_pic' form unexplained

  The SAU9 image's frame is 16#10 bytes; these locals give 16#C, the
  SAU4's and SAU6's size.  handler_arg is at the top in all three.
  Nothing in the SAU9's code addresses the other 4; no stand-in is
  added. }

[section(wired_proc, wired_data)]
procedure sysbus_$int(vector: integer);
  options(val_param);
var
  handler_arg: univ_ptr;
  level: sysbus_$level_t;
  handler: sysbus_$handler_t;
begin
  if (vector >= sysbus_$first_vector) and then
     (vector <= sysbus_$last_vector) then
    level := vector - sysbus_$first_vector
%if sysbus_vectors_90 or sysbus_vectors_88 %then
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
%elseif sysbus_vectors_88 %then
  if not handler^(handler_arg) then begin
    level := sysbus_$int_vec[level].dup_slot;
    handler := sysbus_$dup_vec[level].handler;
    handler_arg := sysbus_$dup_vec[level].handler_arg;
    discard(handler^(handler_arg));
  end;
%else
  discard(handler^(handler_arg));
%endif
end;
