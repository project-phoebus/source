{ TPAD_$INQ_DTYPE - return the last device type seen.

  Image addresses:
    sau2  0x00E69AC4  TPAD_$INQ_DTYPE
    sau4  0x0F87358A  TPAD_$INQ_DTYPE
    sau6  0x780726E6  TPAD_$INQ_DTYPE
    sau7  0x3C47D05E  TPAD_$INQ_DTYPE

  Status stored: none.
}

function tpad_$inq_dtype: tpad_$dev_type_t;
begin
  tpad_$inq_dtype := tpad_$dev_type;
end;
