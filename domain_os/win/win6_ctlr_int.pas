{ WIN6_$CTLR_INT - the controller's error interrupt.

  Image addresses:
    sau6  0x7801AE2E  WIN6_$CTLR_INT

  - The status word is logged (LOG_INT_ERROR) and the interrupt's flag
    cleared.

  Status stored: none.
}

function win6_$ctlr_int(in dcte: dcte_t): boolean;
var
  page: win6_$page_ptr_t;
begin
  page := win6_page;
  log_int_error(page^.ctlr_status);
  page^.ctlr_int.flag := 0;
  win6_$ctlr_int := true;
end;
