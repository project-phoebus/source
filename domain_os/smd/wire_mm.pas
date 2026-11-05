{ SMD_$WIRE_MM - wire main memory for display use.

  Image addresses:
    sau2  0x00E6F4A0  SMD_$WIRE_MM
    sau4  0x0F879C22  SMD_$WIRE_MM
    sau5  0x00E7188E  SMD_$WIRE_MM
    sau6  0x78078BE8  SMD_$WIRE_MM

  - With `blt_main_memory' (base/config.ins.pas): npages pages of the
    buffer at va, a page each 1024 bytes, are wired into the unit's
    display record (mm_pages, mm_page_count).  A failure unwires the
    pages wired before it (SMD_$UNWIRE_MM) and leaves the count 0.
  - Otherwise not implemented; the first three parameters are not read.

  Status stored:
    MST_$WIRE's status: with `blt_main_memory', each page's (not
      written when npages is 0)
    smd_$too_many_pages: with `blt_main_memory', npages is over 32
    smd_$not_implemented: without `blt_main_memory', always
}

{ TODO(pascal) SMD_$WIRE_MM's frame: 8 bytes with no object

  The SAU2's and SAU5's frame has 8 bytes and addresses none of them;
  the routine has no local.  dpc's layout of the routine as written has
  no frame bytes.  A lead: two of the unused arguments as value
  parameters of 4 bytes, whose copies would take 8 bytes; whether the
  compiler reserves a copy it never makes is not known, and nothing
  points to which two.  Not settled.  The SAU4's frame
  (`blt_main_memory') is 0x10 bytes, and its code addresses none of them
  either: its locals are held in registers. }

procedure smd_$wire_mm(in va: integer32; in npages: pinteger;
                       in unit: pinteger;
                       out status: status_$t);
%if blt_main_memory %then
var
  page_va: integer32;
  i: pinteger;
begin
  page_va := va;
  if npages > smd_mm_max_pages then begin
    status.all := smd_$too_many_pages;
    return;
  end;
  with smd_$display_com[unit] do begin
    for i := 1 to npages do begin
      mm_pages[i] := mst_$wire(page_va, status);
      if status.all <> status_$ok then begin
        { the pages wired before this one }
        if i > 1 then begin
          mm_page_count := i - 1;
          smd_$unwire_mm(smd_$display_com[unit],
                         smd_$wired_data.unit[unit].ctrl_regs);
        end;
        mm_page_count := 0;
        return;
      end;
      page_va := page_va + 1024;
    end;
    mm_page_count := npages;
  end;
end;
%else
begin
  status.all := smd_$not_implemented;
end;
%endif
