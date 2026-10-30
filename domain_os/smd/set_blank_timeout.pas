{ SMD_$SET_BLANK_TIMEOUT - set the time after which the screen blanks.

  Image addresses:
    sau2  0x00E6F192  SMD_$SET_BLANK_TIMEOUT
    sau5  0x00E71548  SMD_$SET_BLANK_TIMEOUT
    sau9  0x3C475952  SMD_$SET_BLANK_TIMEOUT

  - Only the clock's high 32 bits are kept; the blink callback compares
    them, added to the last activity's time, with the high clock.
  - param1 is not read.

  Status stored:
    status_$ok: always
}

procedure smd_$set_blank_timeout(in param1: integer32;
                                 in timeout: time_$clock_t;
                                 out status: status_$t);
begin
  blank_timeout := timeout.high;
  status.all := status_$ok;
end;
