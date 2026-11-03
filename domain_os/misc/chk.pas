{ CHK - is a controller of a type configured, with a good status.

  Image addresses:
    sau2  0x00E1A404  CHK
    sau3  0x00E1949C  CHK

  - IO_$DCTE_LIST's entries of the type are walked, a match with status
    ok ending the walk; the result is whether the last match's status is
    ok (false when none has the type).
  - The first routine of the map's IO_ segment in WIRED_PROC.

  Status stored: none.
}

function chk(in ctype: pinteger): boolean;
var
  st: status_$t;
  p: dcte_ptr_t;
  unused_c: integer32;                    { stand-in }
begin
  st.all := status_$io_controller_not_found;

  p := io_$dcte_list;
  if p <> nil then
    repeat
      if p^.ctype = ctype then begin
        st := p^.cstatus;
        if st.all = status_$ok then
          exit;
      end;
      p := p^.nextp;
    until p = nil;

  chk := st.all = status_$ok;
end;
