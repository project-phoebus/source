{ DISK_$UNASSIGN_ALL - give up every volume assigned to the process.

  Image addresses:
    sau2  0x00E6BE1C  DISK_$UNASSIGN_ALL

  - DISK_$UNASSIGN for the volumes 1..10, the status never looked at.

  Status stored: none.
}

procedure disk_$unassign_all;
var
  status: status_$t;
  vol: integer;
  i: integer;
begin
  for i := 1 to 10 do begin
    vol := i;
    disk_$unassign(vol, status);
  end;
end;
