{ FLP_$DO_IO - the driver's I/O entry.

  Image addresses:
    sau2  0x00E3DFE2  FLP_$DO_IO

  - Hands its arguments to FLP_DO_IO, with zero 0.

  Status stored: none.
}

procedure flp_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
begin
  flp_do_io(vol, req, param_3, 0, result);
end;
