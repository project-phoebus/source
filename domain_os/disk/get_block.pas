{ DISK_$GET_BLOCK - DBUF_$GET_BLOCK under the disk lock.

  Image addresses:
    sau2  0x00E3BB80  DISK_$GET_BLOCK

  - DBUF_$GET_BLOCK, with the seven arguments as they came, under the
    disk lock; its buffer pointer is the result.

  Status stored:
    dbuf_$get_block's status: in either case
}

function disk_$get_block(vol_idx: integer; block: integer32;
                         in uid: uid_$t; block_hint: integer32;
                         block_type: integer; flags: integer;
                         out status: status_$t): univ_ptr;
begin
  ml_$lock(ml_$disk_lock);
  disk_$get_block := dbuf_$get_block(vol_idx, block, uid, block_hint,
                                     block_type, flags, status);
  ml_$unlock(ml_$disk_lock);
end;
