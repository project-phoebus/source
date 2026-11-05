{ SMD_$TOUCH - have a unit's device touch its memory.

  Image addresses:
    sau7  0x3C421C06  SMD_$TOUCH
    sau9  0x3C42031E  SMD_$TOUCH

  - The unit is the request's; the unit is not checked.  The result is
    the device's.

  Status stored:
    the device's touch's status: always
}

[section(wired_proc, wired_data)]
function smd_$touch(var arg_1: integer32; in req: smd_touch_req_t;
                    out status: status_$t): integer32;
begin
  with smd_$wired_data.unit[req.unit] do
    smd_$touch := vector^.touch^(dcte, arg_1, status);
end;
