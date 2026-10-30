{ SET_LITES_LOC - set where the status lights are.

  Image addresses:
    sau2  0x00E0C4DC  SET_LITES_LOC

  - The location goes into LITES_LOC; lights that were off (nil) are
    started after the store when the new location is not nil.

  Status stored: none.
}

procedure set_lites_loc(loc: misc_$lites_ptr_t);
begin
  if (lites_loc = nil) and then (loc <> nil) then begin
    lites_loc := loc;
    start_mem_lites;
  end
  else
    lites_loc := loc;
end;
