{ scsi_map_vue - the status for the host adapter's error code.

  Image addresses:
    sau7  0x3C4B814C  scsi_map_vue (module-local)

  Returns:
    status_$ok: code 1, no error
    status_$scsi_command_in_progress: code 38
    status_$scsi_operation_timeout: code 77
    status_$scsi_dma_underrun: code 64
    status_$scsi_dma_overrun: code 65
    status_$scsi_hardware_failure: any other code

  Status stored: none.
}

function scsi_map_vue(code: integer): integer32; internal;
const
  vue_ok = 1;
  vue_busy = 38;
  vue_timeout = 77;
  vue_underrun = 64;
  vue_overrun = 65;
var
  st: integer32;
begin
  case code of
    vue_ok: begin
        st := status_$ok;
      end;
    vue_busy: begin
        st := status_$scsi_command_in_progress;
      end;
    vue_timeout: begin
        st := status_$scsi_operation_timeout;
      end;
    vue_underrun: begin
        st := status_$scsi_dma_underrun;
      end;
    vue_overrun: begin
        st := status_$scsi_dma_overrun;
      end;
    otherwise begin
        st := status_$scsi_hardware_failure;
      end;
  end;
  scsi_map_vue := st;
end;
