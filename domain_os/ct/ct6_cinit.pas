{ CT6_$CINIT - the second controller's tape initialization.

  Image addresses:
    sau6  0x7803EB40  CT6_$CINIT

  - The DCTE is noted (ct_dcte); the board is looked for at the DCTE's
    address and three more 32 KB apart (TESTPAGE), as WIN6_$CINIT does;
    where found the DCTE takes that address, and its vector four more
    for each step.
  - CT6_$INT is defined on the vector after the DCTE's, the page noted
    (ct6_page) and bit 1 of its initialization byte at +0x7FB9 cleared,
    and the driver's eventcount initialized.

  Returns:
    0: the board answered
    status_$io_controller_not_in_system: it did not

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function ct6_$cinit(var dcte: dcte_t): integer32;
var
  status: integer32;
  page: ct6_$page_ptr_t;
  i: integer;
  probe: char;
  id: io_$int_id_t;
begin
  ct_dcte := addr(dcte);
  status := status_$io_controller_not_in_system;

  { the board: at the DCTE's address or one of three after it }
  page := ct_dcte^.disk_dinit;
  for i := 0 to 3 do
    if not testpage(0, page, probe) then
      page := ct6_$page_ptr_t(integer32(page) + 16#8000)
    else begin
      ct_dcte^.disk_dinit := page;
      ct_dcte^.disk_error_que_lo := ct_dcte^.disk_error_que_lo + i * 4;
      status := status_$ok;
      exit;
    end;
  if status <> status_$ok then begin
    ct6_$cinit := status;
    return;
  end;

  id.vector := ct_dcte^.disk_error_que_lo + 1;
  sysbus_$define_int(id, addr(ct6_$int), ct_dcte);
  ct6_page := ct_dcte^.disk_dinit;
  ct6_page^.init_b9 := ct6_page^.init_b9 & 16#FD;
  ec_$init(ct_ec);
  ct6_$cinit := status_$ok;
end;
