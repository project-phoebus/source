{ name_$unmap_dir_buffers - undo a directory's mapping.

  Image addresses:
    sau2  0x00E58560  name_$unmap_dir_buffers

  - An active mapping's 65536 bytes are unmapped at once when the two
    halves are contiguous, else the two 32768-byte halves; a failure
    crashes the system.  The mapping is marked inactive.

  Status stored: none.
}

procedure name_$unmap_dir_buffers(asid: integer;
                                  in out mapped_info: name_$mapped_info_t);
  internal;
var
  size: integer32;
  status: status_$t;
begin
  if mapped_info.active then begin
    { one region or two halves }
    if mapped_info.first_base + 16#8000 = mapped_info.second_base then
      size := 65536
    else
      size := 32768;

    mst_$unmap_privi(1, uid_$nil, mapped_info.first_base, size, asid,
                     status);
    if status.code <> 0 then
      crash_system(status);

    if size = 32768 then begin
      mst_$unmap_privi(1, uid_$nil, mapped_info.second_base, 32768, asid,
                       status);
      if status.code <> 0 then
        crash_system(status);
    end;

    mapped_info.active := false;
  end;
end;
