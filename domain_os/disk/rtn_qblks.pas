{ DISK_$RTN_QBLKS - give a chain of queue blocks back.

  Image addresses:
    sau2  0x00E3C0C4  DISK_$RTN_QBLKS

  - disk_$rtn_qblks_internal with the caller's arguments.

  Status stored: none.
}

procedure disk_$rtn_qblks(count: integer; qblk_head: disk_$io_req_ptr_t;
                          qblk_tail: disk_$io_req_ptr_t);
begin
  disk_$rtn_qblks_internal(count, qblk_head, qblk_tail);
end;
