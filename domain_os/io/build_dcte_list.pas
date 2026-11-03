{ io_$build_dcte_list - link the DCTEs into IO_$DCTE_LIST.

  Image addresses:
    sau2  0x00E32834  io_$build_dcte_list
    sau3  0x00E31004  io_$build_dcte_list
    sau5  0x00E347E4  io_$build_dcte_list

  - The dynamic DCTE area's records (each rounded up to 8 bytes) are
    linked while more than 8 bytes remain; then every static DCTE
    DEV_DCTES names, and the list's head is stored.

  Status stored (in each DCTE):
    status_$ok: its length is a multiple of 8
    status_$io_bad_dcte_length: its length is not (linked), or is 0 (not
      linked; the walk ends)
}

{ TODO(pascal) 8 frame bytes unexplained (stand-ins unused_8, unused_5c)

  In the SAU2 frame, with the reserved slot, head and four locals, 4
  bytes before head are needed for head to lie where it does (at a
  multiple of 8, or after a 4-byte local not translated), and 4 below
  the locals are unexplained (the second loop's element pointer, held in
  a register, has no local here).  The stand-ins unused_8 and unused_5c
  hold them. }

[section(os_init_proc, os_init_data)]
procedure io_$build_dcte_list; internal;
var
  unused_8: integer32;                    { the stand-in (TODO) }
  head: dcte_t;
  tail: dcte_ptr_t;
  d: dcte_ptr_t;
  next: linteger;
  k: integer32;                           { k * 4 in the image's code }
  unused_5c: integer32;                   { the stand-in (TODO) }
begin
  { the dynamic area }
  head.nextp := nil;
  tail := addr(head);
  next := linteger(io_$dcte_area_start);
  while linteger(io_$dcte_area_end) - next > 8 do begin
    d := dcte_ptr_t(next);
    if d^.length = 0 then begin
      d^.cstatus.all := status_$io_bad_dcte_length;
      exit;
    end;
    if (d^.length & 7) <> 0 then
      d^.cstatus.all := status_$io_bad_dcte_length
    else
      d^.cstatus.all := status_$ok;
    d^.nextp := nil;
    tail^.nextp := d;
    tail := d;
    next := next + ((d^.length + 7) & (-8));
  end;

  { the static DCTEs }
  k := 0;
  while dev_dctes[k] <> nil do begin
    d := dev_dctes[k];
    d^.nextp := nil;
    tail^.nextp := d;
    tail := d;
    k := k + 1;
  end;

  io_$dcte_list := head.nextp;
end;
