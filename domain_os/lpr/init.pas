{ LPR_$INIT - probe the line printer port and set it up.

  Image addresses:
    sau3  0x00E32F34  LPR_$INIT
    sau4  0x0F838384  LPR_$INIT

  - When the port answers, the circular buffer is set up, LPR_$INT
    becomes the level 5 autovector's handler and the current mode (0) is
    programmed.
  - The PNA form (`lpr_pbu_unit') takes the PNA's presence from
    PBU_$MCB and sets the port's registers in PBU_CTL's page.

  Status stored: none.
}

%if lpr_pbu_unit %then
[section(os_init_proc, os_init_data)]
procedure lpr_$init;
var
  data: integer;
begin
  lpr_$present := pbu_$mcb.present;
  if lpr_$present then begin
    cbuf_$init_cb(lpr_$bcb, lpr_$buffer, 512);
    pbu_ctl.word_06 := 16#AE;
    pbu_ctl.int_mask := pbu_ctl.int_mask + [lpr_pbu_unit_number];
    pbu_ctl.word_06 := 16#0D;
    data := pbu_ctl.word_04;
  end;
end;
%else
[section(os_init_proc, os_init_data)]
procedure lpr_$init;
var
  data: integer;
begin
  lpr_$present := testpage(0, addr(lpr), data);
  if lpr_$present then begin
    cbuf_$init_cb(lpr_$bcb, lpr_$buffer, 512);
    lpr_vec := addr(lpr_$int);
    lpr_set_mode;
  end;
end;
%endif
