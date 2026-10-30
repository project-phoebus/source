{ scsi_find_req - find a request in a list by its id.

  Image addresses:
    sau9  0x3C4A4C00  scsi_find_req (the map's SCSI_$PROC_START)

  Assume we're called with the SCSI spin lock held.

  - Id 0 takes the list's first request.
  - Returns true and the request in req, or false and req nil.
}

function scsi_find_req(head: scsi_req_ptr_t; id: integer32;
                       out req: scsi_req_ptr_t): boolean; internal;
begin
  if (id = 0) and then (head <> nil) then begin
    req := head;
    scsi_find_req := true;
  end
  else begin
    req := head;
    while req <> nil do begin
      if req^.result.id = id then begin
        scsi_find_req := true;
        exit;
      end;
      req := req^.next;
    end;
  end;
  if req = nil then
    scsi_find_req := false;
end;
