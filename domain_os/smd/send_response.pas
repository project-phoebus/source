{ SMD_$SEND_RESPONSE - answer a pending borrow request and wake the borrower.

  Image addresses:
    sau2  0x00E6F4BE  SMD_$SEND_RESPONSE
    sau5  0x00E718AC  SMD_$SEND_RESPONSE
    sau9  0x3C475ADE  SMD_$SEND_RESPONSE

  - The screen manager's answer to a request to borrow the display:
    response true grants it.  A caller with no display unit does
    nothing.
  - SMD_$BORROW_DISPLAY waits on the display's cursor eventcount, which
    is advanced.

  Status stored: none.
}

{ TODO(pascal) SMD_$SEND_RESPONSE's frame: 4 of its 0xC bytes not accounted

  The image's frame has 12 bytes and addresses no frame slot: unit and
  the `with' pointer are held in registers.  dpc's layout (`--dump-locals'
  on the gate's copy) gives the routine as written 8 bytes (unit and the
  `with' slot); the other 4 are not accounted. }

procedure smd_$send_response(in response: boolean);
var
  unit: pinteger;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit <> 0 then
    with smd_$display_com[unit] do begin
      smd_response_val[unit] := response;
      ec_$advance(cursor_ec);
    end;
end;
