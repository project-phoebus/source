{ disk_$set_chain_status - give every request of a chain one status.

  Image addresses:
    sau2  0x00E3CCCE  disk_$set_chain_status

  Status stored (in the requests):
    the status given: always
}

procedure disk_$set_chain_status(req: disk_$io_req_ptr_t;
                                 in status: univ status_$t);
  internal;
var
  r: disk_$io_req_ptr_t;
begin
  r := req;
  while r <> nil do begin
    r^.status := status;
    r := r^.next;
  end;
end;
