{ PBU_$GET_INFO - the PBU manager's information.

  Image addresses:
    sau5  0x00E592CE  PBU_$GET_INFO

  - The three words 1, 2 and 1.

  Status stored:
    status_$ok: the information was returned
    status_$pbu_bad_parameter: len is under 6 bytes
}

procedure pbu_$get_info(in len: pinteger; out info: pbu_$info_t;
                        out status: status_$t);
begin
  if len < 6 then
    status.all := status_$pbu_bad_parameter
  else begin
    info.info_1 := 1;
    info.info_2 := 2;
    info.info_3 := 1;
    status.all := status_$ok;
  end;
end;
