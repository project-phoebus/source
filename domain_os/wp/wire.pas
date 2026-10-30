{ WP_$WIRE - wire a page.

  Image addresses:
    sau2  0x00E071B0  WP_$WIRE
    sau9  0x3C4083EA  WP_$WIRE

  - MMAP_$WIRE under ml_$pmap_lock.  A routine of the AST_ module.

  Status stored: none.
}

procedure wp_$wire(ppn: integer32); options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  mmap_$wire(ppn);
  ml_$unlock(ml_$pmap_lock);
end;
