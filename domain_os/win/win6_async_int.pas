{ WIN6_$ASYNC_INT - the controller's asynchronous status interrupt.

  Image addresses:
    sau6  0x7801ADFC  WIN6_$ASYNC_INT

  - The status word is logged (LOG_INT_ERROR) and the interrupt's flag
    cleared.

  Status stored: none.
}

function win6_$async_int(in dcte: dcte_t): boolean;
var
  page: win6_$page_ptr_t;
begin
  page := win6_page;
  log_int_error(page^.async_status);
  page^.async_int.flag := 0;
  win6_$async_int := true;
end;
