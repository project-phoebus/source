{ TPAD_$INQ_DTYPE - return the last device type seen.

  Image addresses:
    sau2  0x00E69AC4  TPAD_$INQ_DTYPE

  Status stored: none.
}

function tpad_$inq_dtype: tpad_$dev_type_t;
begin
  tpad_$inq_dtype := tpad_$dev_type;
end;
