{ SCSI_$CINIT - initialize the SCSI controller.

  Image addresses:
    sau2  0x00E34F04  SCSI_$CINIT
    sau9  0x3C43BAB0  SCSI_$CINIT

  - A stub on every SAU, the SAU9's driver too: its bus is set up by
    SCSI_$INIT, the DCTE's routine.

  Returns:
    status_$io_controller_not_in_system: always

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function scsi_$cinit: integer32;
begin
  scsi_$cinit := status_$io_controller_not_in_system;
end;
