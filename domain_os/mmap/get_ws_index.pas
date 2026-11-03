{ MMAP_$GET_WS_INDEX - return an address space's working set list index.

  Image addresses:
    sau2  0x00E0CA3A  MMAP_$GET_WS_INDEX
    sau4  0x0F80D08A  MMAP_$GET_WS_INDEX
    sau8  0x03C0D966  MMAP_$GET_WS_INDEX
    sau9  0x3C40E9A2  MMAP_$GET_WS_INDEX

  - The address space's entry of MMAP_$WS_OWNER.
  - pid 0 passes the test and reads MMAP_$WSL_HI_MARK as entry 0.

  Status stored:
    status_$ok: the index was returned
    status_$mmap_illegal_pid: an address space above 64
}

procedure mmap_$get_ws_index(pid: pinteger; out wsl_index: pinteger;
                             out status: status_$t);
begin
  status.all := status_$ok;
  if pid > 64 then
    status.all := status_$mmap_illegal_pid
  else
    wsl_index := mmap_$ws_owner[pid];
end;
