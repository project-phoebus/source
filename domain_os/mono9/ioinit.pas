{ MONO9_$IOINIT - initialize the display controller at boot.

  Image addresses:
    sau9  0x3C43B6E8  MONO9_$IOINIT

  - The display memory's address goes from the configuration to the
    state record.
  - The small form (DISP_QUERY 0) is 1024 by 800; the vector's 1280 by
    1024 is kept otherwise.
  - With a display (DISP_QUERY below 2) the driver gets its one unit
    (SMD_$ADD_DEVICE).

  Status stored (the result):
    status_$ok: the display is there
    status_$io_controller_not_in_system: DISP_QUERY says none
}

[section(os_init_proc, os_init_data)]
function mono9_$ioinit(var dcte: mono9_$dcte_t): integer32;
var
  status: integer32;
  info: mono9_$info_ptr_t;
  hdm: mono9_$hdm_ptr_t;
  config: mono9_$config_ptr_t;
  small: boolean;
  present: boolean;
begin
  status := status_$ok;
  info := dcte.info;
  hdm := dcte.hdm;
  config := dcte.config;
  info^.memory_addr := config^.memory_addr;
  small := disp_query = 0;
  if small then begin
    hdm^.width := mono9_$small_width;
    hdm^.height := mono9_$small_height;
  end;
  present := disp_query < mono9_$no_display;
  if present then
    smd_$add_device(1, addr(dcte))
  else
    status := status_$io_controller_not_in_system;
  mono9_$ioinit := status;
end;
