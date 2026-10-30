{ MMAP_$REMOTE_POOL - the remote page pool's size for a request.

  Image addresses:
    sau2  0x00E59110  MMAP_$REMOTE_POOL
    sau9  0x3C4604B8  MMAP_$REMOTE_POOL

  - On the SAU2 the routine returns the longword it is given.

  Status stored: none.
}

function mmap_$remote_pool(param: integer32): integer32;
begin
  mmap_$remote_pool := param;
end;
