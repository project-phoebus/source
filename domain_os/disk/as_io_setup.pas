{ AS_IO_SETUP - check and wire the page of an asynchronous transfer.

  Image addresses:
    sau2  0x00E6B74C  AS_IO_SETUP

  - The page is wired (MST_$WIRE) and the cache flushed; the wired page
    is the result.
  - The failure paths do not assign the result.

  Status stored:
    status_$ok: the page was wired
    status_$invalid_volume_index: an index outside 1..10
    status_$disk_buffer_not_page_aligned: the buffer does not start a
      page
    status_$volume_not_properly_mounted: the volume is not assigned to
      the calling process
    mst_$wire's status, with the fail bit: the page could not be wired
}

function as_io_setup(var vol_idx: integer; buffer: univ_ptr;
                     out status: status_$t): integer32;
begin
  if not (vol_idx in [1..10]) then
    status.all := status_$invalid_volume_index
  else
    with disk_$dvtbl[vol_idx] do
      if (integer32(buffer) & 16#3FF) <> 0 then
        status.all := status_$disk_buffer_not_page_aligned
      else if (mount_state <> 2) or else
              (mount_proc <> proc1_$current) then
        status.all := status_$volume_not_properly_mounted
      else begin
        as_io_setup := mst_$wire(integer32(buffer), status);
        if status.code <> 0 then
          status.fail := true;
        cache_$flush_virtual;
      end;
end;
