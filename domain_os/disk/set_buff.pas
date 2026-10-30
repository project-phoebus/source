{ DISK_$SET_BUFF - DBUF_$SET_BUFF under the disk lock.

  Image addresses:
    sau2  0x00E3BBD4  DISK_$SET_BUFF

  - DBUF_$SET_BUFF, with the three arguments as they came, under the
    disk lock.

  Status stored:
    dbuf_$set_buff's status: in either case
}

procedure disk_$set_buff(buffer: univ_ptr; flags: integer;
                         out status: status_$t);
begin
  ml_$lock(ml_$disk_lock);
  dbuf_$set_buff(buffer, flags, status);
  ml_$unlock(ml_$disk_lock);
end;
