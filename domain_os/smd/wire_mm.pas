{ SMD_$WIRE_MM - wire main memory for display use.

  Image addresses:
    sau2  0x00E6F4A0  SMD_$WIRE_MM
    sau5  0x00E7188E  SMD_$WIRE_MM

  - Not implemented; the first three parameters are not read.

  Status stored:
    smd_$not_implemented: always
}

{ TODO(pascal) SMD_$WIRE_MM's frame: 8 bytes with no object

  The image's frame has 8 bytes and addresses none of them; the routine
  has no local.  dpc's layout of the routine as written has no frame
  bytes.  A lead: two of the unused arguments as value parameters of 4
  bytes, whose copies would take 8 bytes; whether the compiler reserves
  a copy it never makes is not known, and nothing points to which two.
  Not settled. }

procedure smd_$wire_mm(in param1: integer32;
                       in param2: integer32;
                       in param3: integer32;
                       out status: status_$t);
begin
  status.all := smd_$not_implemented;
end;
