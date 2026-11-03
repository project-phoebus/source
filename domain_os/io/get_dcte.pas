{ IO_$GET_DCTE - find the DCTE of a controller type and number.

  Image addresses:
    sau2  0x00E1A448  IO_$GET_DCTE
    sau3  0x00E194E0  IO_$GET_DCTE
    sau5  0x00E1A790  IO_$GET_DCTE
    sau8  0x03C1B5CC  IO_$GET_DCTE

  - IO_$DCTE_LIST's entries of the type and number are walked; each
    match gives the result, and one with status ok ends the walk.  The
    result is nil without a match.

  Status stored:
    the DCTE's status: a match, the last one's
    status_$io_controller_not_found: no match
}

{ TODO(pascal) 8 frame bytes unexplained (stand-in unused_14)

  The SAU2 frame is 20 bytes: found, p and the result variable account
  for 12.  Word locals for ctype and cnum would account for 4 more; the
  stand-in unused_14 holds the 8. }

function io_$get_dcte(in ctype: integer; in cnum: integer;
                      out status: status_$t): dcte_ptr_t;
var
  found: dcte_ptr_t;
  p: dcte_ptr_t;
  unused_14: array[1..2] of integer32;    { the stand-in (TODO) }
begin
  found := nil;
  p := io_$dcte_list;
  if p <> nil then
    repeat
      if (p^.ctype = ctype) and then (p^.cnum = cnum) then begin
        found := p;
        status := p^.cstatus;
        if status.all = status_$ok then
          exit;
      end;
      p := p^.nextp;
    until p = nil;

  if found = nil then
    status.all := status_$io_controller_not_found;
  io_$get_dcte := found;
end;
