{ DISK_$GET_QBLKS - take count queue blocks, waiting in turn.

  Image addresses:
    sau2  0x00E3BFF4  DISK_$GET_QBLKS

  - disk_$get_qblks_internal with mode false (the caller waits its turn
    in the ring).

  Status stored: none.
}

procedure disk_$get_qblks(count: integer; out qblk_head: disk_$io_req_ptr_t;
                          out qblk_tail: disk_$io_req_ptr_t);
begin
  disk_$get_qblks_internal(count, false, qblk_head, qblk_tail);
end;
