{ DISK_$INVALIDATE - drop a volume's buffers, under the disk lock.

  Image addresses:
    sau2  0x00E3BC0E  DISK_$INVALIDATE

  - DBUF_$INVALIDATE for every block (block 0) of the volume, under the
    disk lock.

  Status stored: none.
}

procedure disk_$invalidate(vol_idx: integer);
begin
  ml_$lock(ml_$disk_lock);
  dbuf_$invalidate(0, vol_idx);
  ml_$unlock(ml_$disk_lock);
end;
