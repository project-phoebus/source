{ DIR_$INIT - build the directory lock and handle tables at boot.

  Image addresses:
    sau2  0x00E3140C  DIR_$INIT
    sau9  0x3C43756C  DIR_$INIT

  - The 32 lock records and handles are linked into free lists (handle
    0, DIR_$ALLOC_HANDLE's reserve, kept out); the two exclusion locks
    and the wait-for-handle eventcount are initialized, then OLD_DIR.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure dir_$init;
var
  i: integer;
begin
  dir_$handle_in_use := [];
  dir_$lock_in_use := [];

  for i := 0 to 31 do begin
    ec_$init(dir_$wait_ecs[i]);
    dir_$handle_tab[i].slot_index := i;
    dir_$handle_tab[i].next := addr(dir_$handle_tab[i + 1]);
    dir_$lock_tab[i].next := addr(dir_$lock_tab[i + 1]);
    dir_$lock_tab[i].index := i;
  end;

  { the ends the free lists must not follow }
  dir_$lock_tab[31].next := nil;
  dir_$handle_tab[31].next := nil;
  dir_$handle_tab[0].next := nil;

  dir_$lock_free := addr(dir_$lock_tab[0]);
  dir_$handle_free := addr(dir_$handle_tab[1]);

  ml_$exclusion_init(dir_$mutex);
  ml_$exclusion_init(dir_$link_buf_mutex);
  ec_$init(dir_$wt_for_hdnl_ec);

  dir_$old_init;
end;
