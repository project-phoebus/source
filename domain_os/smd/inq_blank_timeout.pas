{ SMD_$INQ_BLANK_TIMEOUT - return the time after which the screen blanks.

  Image addresses:
    sau2  0x00E6F1B4  SMD_$INQ_BLANK_TIMEOUT
    sau4  0x0F8798FE  SMD_$INQ_BLANK_TIMEOUT
    sau5  0x00E7156A  SMD_$INQ_BLANK_TIMEOUT
    sau9  0x3C475974  SMD_$INQ_BLANK_TIMEOUT

  - The clock value's low word is 0; param1 is not read.

  Status stored:
    status_$ok: always
}

procedure smd_$inq_blank_timeout(in param1: integer32;
                                 out timeout: time_$clock_t;
                                 out status: status_$t);
begin
  timeout.high := blank_timeout;
  timeout.low := 0;
  status.all := status_$ok;
end;
