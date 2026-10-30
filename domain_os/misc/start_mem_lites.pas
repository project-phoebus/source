{ START_MEM_LITES - place the light rows and start the lights process.

  Image addresses:
    sau2  0x00E0C43C  START_MEM_LITES

  - The two rows go 48 and 16 lines above display unit 1's visible
    bottom (SMD_$INQ_DISP_INFO's status not looked at); the MEM_LITES
    process is created, a failure printed.

  Status stored: none.
}

{ TODO(pascal) START_MEM_LITES's info at -0x10, 8-aligned

  The 10-byte record lies at -0x10..-0x7, under 6 bytes nothing
  addresses: the alignment of frame objects of 8 bytes or more to 8.
  Placed right below the frame's top under word or longword alignment it
  would be at -0xA or -0xC.  The stand-in unused_6 holds the 6 bytes, so
  the declared frame has the image's offsets; with the alignment rule it
  would not be needed. }

procedure start_mem_lites;
var
  unused_6: array[1..3] of integer;       { stand-in, see the TODO }
  info: smd_disp_info_result_t;
  status: status_$t;
begin
  smd_$inq_disp_info(1, info, status);

  mem_lites_row1 := info.dims.height - 48;
  mem_lites_row2 := info.dims.height - 16;

  discard(proc1_$create_p(addr(mem_lites), 16#0400000A, status));

  if status.all <> status_$ok then
    vfmt_$write2('proc1_$create_p failed. status = %LH%.', status, 0);
end;
