{ FILE_$UNLOCK_ALL - release every lock of the current process.

  Image addresses:
    sau2  0x00E75138  FILE_$UNLOCK_ALL

  - FILE_$PRIV_UNLOCK_ALL with PROC1_$AS_ID.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure file_$unlock_all;
begin
  file_$priv_unlock_all(proc1_$as_id);
end;
