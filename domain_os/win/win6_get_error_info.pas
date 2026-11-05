{ WIN6_$GET_ERROR_INFO - copy out the error counts and the error log.

  Image addresses:
    sau6  0x7801AA24  WIN6_$GET_ERROR_INFO

  Status stored: none.
}

procedure win6_$get_error_info(out errors: win6_$errors_t;
                               out epbx: integer;
                               out epbs: win6_$epbs_t);
begin
  errors := win6_$errors;
  epbx := win6_$epbx;
  epbs := win6_$epbs;
end;
