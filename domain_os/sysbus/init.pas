{ SYSBUS_$INIT - install the system bus's interrupt routines.

  Image addresses:
    sau2  0x00E0AB28  SYSBUS_$INIT
    sau3  0x00E0AC18  SYSBUS_$INIT
    sau9  0x3C40C6D0  SYSBUS_$INIT

  - With `sysbus_int_vec': SYSBUS_$INT goes on the vectors 16#A0..16#AF
    and every level gets SYSBUS_$UNDEF_INT; with `util_pic' the
    controller is then set up, every level disabled and its pending
    interrupts cleared.
  - Without it (the SAU2): DISK_INTERRUPT and RING_INTERRUPT go on their
    vectors; each DCTE of controller type 0, 1 or 2 has its entry, do_io
    and dinit kept in the module's slots for the type (the last of each
    type wins).  Without `winchester_config' (the SAU3) only the ring's
    vector and DCTE.
  - A fragment of the ATBUS_ module.

  Status stored: none.
}

{ TODO(sau) SYSBUS_$INIT on the SAU4 and SAU6

  The SAU4's and SAU6's trap their SYSBUS_$INT's two ranges of vectors
  (sysbus/int.pas) and set 32 and 24 entries.  The `sysbus_int_vec' arm
  below is the SAU9's.  To be written as conditional arms when those
  SAUs are translated. }

%if sysbus_int_vec %then
[section(wired_proc, wired_data)]
procedure sysbus_$init;
var
  vector: integer;
  level: sysbus_$level_t;
begin
  for vector := sysbus_$first_vector to sysbus_$last_vector do
    io_$trap(vector, addr(sysbus_$int));
  for level := 0 to sysbus_$max_level do
    sysbus_$int_vec[level].handler := addr(sysbus_$undef_int);
%if util_pic %then
  util_pic.enable_lo := [];
  util_pic.enable_hi := [];
  util_pio.reg_04 := 16#10;
  util_pio.reg_08 := 16#CF;
  util_pic.vector_base := sysbus_$first_vector;
  util_pic.pending_lo := [0..7];
  util_pic.pending_hi := [0..7];
%endif
end;
%else
[section(wired_proc, wired_data)]
procedure sysbus_$init;
var
  dcte: dcte_ptr_t;
begin
%if winchester_config %then
  io_$trap(io_vector_disk, addr(disk_interrupt));
%endif
  io_$trap(io_vector_ring, addr(ring_interrupt));

  dcte := io_$dcte_list;
  while dcte <> nil do begin
    case dcte^.ctype of
%if winchester_config %then
      io_ctype_win: begin
        type0_dcte := dcte;
        type0_do_io := dcte^.disk_do_io;
        type0_dinit := dcte^.disk_dinit;
      end;
      io_ctype_flp: begin
        type1_dcte := dcte;
        type1_do_io := dcte^.disk_do_io;
        type1_dinit := dcte^.disk_dinit;
      end;
%endif
      io_ctype_ring: begin
        type2_dcte := dcte;
        type2_do_io := dcte^.disk_do_io;
        type2_dinit := dcte^.disk_dinit;
      end;
    end;
    dcte := dcte^.nextp;
  end;
end;
%endif
