{ sio_$init_dtte - set up a display terminal table entry.

  Image addresses:
    sau2  0x00E32B76  sio_$init_dtte (module-local)
    sau3  0x00E3133E  sio_$init_dtte (module-local)
    sau4  0x0F835D22  sio_$init_dtte (module-local)
    sau8  0x03C36542  sio_$init_dtte
    sau9  0x3C43954A  sio_$init_dtte (module-local)

  - The entry's three eventcounts are initialized, its flag cleared and
    its discipline stored.  A fragment of the OS_TERM_INIT module.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure sio_$init_dtte(var dtte: dtte_t; discipline: integer); internal;
begin
  ec_$init(ec_$eventcount_ptr_t(addr(dtte.input_ec))^);
  ec_$init(ec_$eventcount_ptr_t(addr(dtte.output_ec))^);
  ec_$init(ec_$eventcount_ptr_t(addr(dtte.ec_00))^);
  dtte.flags := false;
  dtte.discipline := discipline;
end;
