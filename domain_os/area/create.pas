{ AREA_$CREATE - create an area in the current address space.

  Image addresses:
    sau2  0x00E079C0  AREA_$CREATE
    sau4  0x0F807CAE  AREA_$CREATE
    sau9  0x3C408FF0  AREA_$CREATE

  - A local create (remote UID 0) for the running process's address
    space, with remote backing store allowed.

  Status stored:
    area_$internal_create's status: in either case
}

function area_$create(virt_size: integer32; commit_size: integer32;
                      shared: boolean; out status: status_$t): integer32;
var
  local_status: status_$t;
begin
  area_$create := area_$internal_create(virt_size, commit_size, 0,
                                        proc1_$as_id, 1, shared,
                                        local_status);
  status := local_status;
end;
