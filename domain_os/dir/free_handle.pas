{ dir_$free_handle - give a directory handle back.

  Image addresses:
    sau2  0x00E4B980  dir_$free_handle (module-local)

  - Under DIR_$MUTEX; slot 0, the reserve handle, does not go on the
    free list.  DIR_$WT_FOR_HDNL_EC is advanced to wake a waiter.

  Status stored: none.
}

procedure dir_$free_handle(var handle: dir_$handle_t);
  internal;
var
  slot: integer;
begin
  ml_$exclusion_start(dir_$mutex);

  slot := handle.slot_index;
  dir_$handle_in_use := dir_$handle_in_use - [slot];

  { the reserve handle never joins the list }
  if slot <> 0 then begin
    handle.next := dir_$handle_free;
    dir_$handle_free := addr(handle);
  end;

  ec_$advance(dir_$wt_for_hdnl_ec);
  ml_$exclusion_stop(dir_$mutex);
end;
