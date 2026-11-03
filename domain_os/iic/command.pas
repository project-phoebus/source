{ iic_command - give the controller a command and wait for it to end.

  Image addresses:
    sau3  0x00E85400  iic_command (module-local; the map's
                      IIC_$PROC_START)

  - The command goes into the line's command block and the controller
    is started; the wait ends on the completion interrupt (int_ec), after
    4 clock ticks, or on an abort (abort_ec).  The block's completion
    code then gives the status, the errors are counted, and the code is
    cleared.
  - The map's IIC_$PROC_START, the mark of the driver's wired range, is
    at its first byte; the routine has no name of its own.

  Status stored:
    status_$ok: the command was carried out
    status_$iic_undocumented_interrupt, status_$iic_not_initialized,
      status_$iic_transmitter_underrun,
      status_$iic_dma_multibus_read_timeout, status_$iic_invalid_ccb:
      the controller's completion code
    status_$iic_no_completion_interrupt: no interrupt came
    status_$iic_operation_aborted: the wait was aborted
}

[section(iic_aqwrd_proc, iic_aqwrd_data)]
procedure iic_command(line: pinteger; cmd: integer; out status: status_$t);
  internal;
var
  int_value: integer32;
  cb: iic_$page_ptr_t;
begin
  with iic_lines[line] do begin
    cb := addr(iic_$control_page[0][line]);
    cb^.cb.command := cmd;
    int_value := ec_$read(int_ec) + 1;
    csr^.control := iic_csr_go;
    case ec_$wait(addr(int_ec), addr(time_$clockh_ec), addr(abort_ec),
                  int_value, time_$clockh + 4,
                  ec_$read(abort_ec) + 1) of
      0: begin
        case cb^.cb.completion of
          iic_done_undocumented: begin
            status.all := status_$iic_undocumented_interrupt;
            counts.undocumented := counts.undocumented + 1;
          end;
          iic_done_ok: begin
            status.all := status_$ok;
          end;
          iic_done_not_initialized: begin
            status.all := status_$iic_not_initialized;
            counts.not_initialized := counts.not_initialized + 1;
          end;
          iic_done_underrun: begin
            status.all := status_$iic_transmitter_underrun;
            counts.underruns := counts.underruns + 1;
          end;
          iic_done_dma_timeout: begin
            status.all := status_$iic_dma_multibus_read_timeout;
            counts.dma_timeouts := counts.dma_timeouts + 1;
          end;
          iic_done_invalid_ccb: begin
            status.all := status_$iic_invalid_ccb;
            errors.invalid_ccbs := errors.invalid_ccbs + 1;
          end;
        end;
        cb^.cb.completion := 0;
      end;
      1: begin
        status.all := status_$iic_no_completion_interrupt;
      end;
      2: begin
        status.all := status_$iic_operation_aborted;
      end;
    end;
  end;
end;
