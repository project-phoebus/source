{ SCSI_$C90_DMA - handle the DMA port's interrupt.

  Image addresses:
    sau9  0x3C4A60F2  SCSI_$C90_DMA

  - With the controller's interrupt disabled, moves the next bytes of
    the bus's transfer between the buffer and the DMA port
    (SCSI_$HP_WRITE: at most what the FIFO has room for;
    SCSI_$HP_READ: while the port has data).
  - SCSI_CNTS counts the interrupts in a row that moved nothing.
  - A transfer of neither direction crashes the system.

  Returns:
    true: always
}

function scsi_$c90_dma(cb: scsi_cb_ptr_t): boolean;
var
  n: integer;
begin
  sysbus_$disable_device(cb^.int_id);
  with cb^ do
    if dma_active = true then
      case dma_dir of
        scsi_$dir_out: begin
          n := scsi_$hp_write(addr(cb^.regs^.r1c), addr(cb^.regs^.dma_port),
                              univ_ptr(cb^.dma_buf + dma_done), dma_count);
          if n = 0 then
            scsi_cnts := scsi_cnts + 1
          else
            scsi_cnts := 0;
          dma_count := dma_count - pinteger(n);
          dma_done := dma_done + pinteger(n);
        end;
        scsi_$dir_in: begin
          n := scsi_$hp_read(addr(cb^.regs^.r1c), addr(cb^.regs^.dma_port),
                             univ_ptr(cb^.dma_buf + dma_done), dma_count);
          if n = 0 then
            scsi_cnts := scsi_cnts + 1
          else
            scsi_cnts := 0;
          dma_count := dma_count - pinteger(n);
          dma_done := dma_done + pinteger(n);
        end;
        otherwise begin
          crash_system(status_$scsi_illegal_data_direction);
        end;
      end;
  sysbus_$enable_device(cb^.int_id);
  scsi_$c90_dma := true;
end;
