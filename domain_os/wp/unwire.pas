{ WP_$UNWIRE - unwire a page.

  Image addresses:
    sau2  0x00E07176  WP_$UNWIRE
    sau4  0x0F8074E0  WP_$UNWIRE
    sau6  0x78007734  WP_$UNWIRE
    sau9  0x3C4083B0  WP_$UNWIRE

  - MMAP_$UNWIRE under ml_$pmap_lock.  A routine of the AST_ module.

  Status stored: none.
}

procedure wp_$unwire(wired_addr: integer32); options(val_param);
begin
  ml_$lock(ml_$pmap_lock);
  mmap_$unwire(wired_addr);
  ml_$unlock(ml_$pmap_lock);
end;
