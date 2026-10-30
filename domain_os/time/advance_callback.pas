{ TIME_$ADVANCE_CALLBACK - the callback that advances a waiter's eventcount.

  Image addresses:
    sau2  0x00E16434  TIME_$ADVANCE_CALLBACK

  - When the element expires, the eventcount its datum names is advanced
    without dispatching.

  Status stored: none.
}

procedure time_$advance_callback(in elem: time_$queue_elem_ptr_t);
var
  ec: ec_$eventcount_ptr_t;
begin
  ec := elem^.callback_arg;
  ec_$advance_without_dispatch(ec^);
end;
