{ FIND_VOLX - the volume index of a physical location.

  Image addresses:
    sau2  0x00E6B0BC  FIND_VOLX

  - The result is 0 when no mount table entry is at the location.
  - Global, though its name has no `$': the map lists only global
    symbols.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of a global routine unexplained

  The SAU2 image's frame has 4 bytes more than its objects (the result
  word, i, and perhaps a slot for the `with' temporary) need, and
  nothing addresses them.  A global routine has no reserved slot: an
  internal routine's reserved slot would fit exactly, but the map names
  the routine.  Another 4-byte local (the stepped pointer as a source
  pointer local) would fit as well.  No stand-in is declared, since what
  the bytes held is not known. }

function find_volx(dev: integer; bus: integer; ctlr: integer;
                   lv_num: integer): integer;
var
  i: integer;
begin
  for i := 1 to volx_max_volumes do
    with volx_$table[i] do
      if (e_lv_num = lv_num) and then (e_ctlr = ctlr) and then (e_dev = dev)
         and then (e_bus = bus) then begin
        find_volx := i;
        return;
      end;

  find_volx := 0;
end;
