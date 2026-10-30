{ ring_8025_initialize - reset a unit's adapter and initialize its
  controller.

  Image addresses:
    sau9  0x3C485124  ring_8025_initialize

  - Up to three tries of: the reset, the device enabled on its bus, the
    parameters written through the system interface, the execute
    command, and three polls a tick apart.  Done when the status shows
    none of initialize, test and error; error ends the tries.
  - The parameters carry the physical addresses of the unit's system
    command and status blocks in its control area; their interrupt
    vectors are not set.

  Status stored:
    status_$ok: the controller is initialized
    ring_8025_reset's status: the reset failed
    io_$enable_device's status: the device could not be enabled
    status_$r8025_adapter_hardware_error: the controller did not take
      the parameters
}

procedure ring_8025_initialize(u: ring_8025_$unit_ptr_t;
                               out status: status_$t); internal;
label
  fail;
var
  params: ring_8025_$init_params_t;
  sts: ring_8025_$sifsts_t;
  tries: integer;
  i: integer;
  polls: integer;
begin
  params.options := 16#9F00;
  params.burst_sizes := -16#10002;            { 16#FFFEFFFE }
  params.abort_dma := chr(3);
  params.abort_parity := chr(3);
  params.scb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].scb)));
  params.ssb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].ssb)));
  for tries := 1 to 3 do begin
    ring_8025_reset(u^.regs, status);
    if status.all <> status_$ok then
      return;
    io_$enable_device(u^.io_unit, status);
    if status.all <> status_$ok then
      return;
    u^.regs^.sifadr := ring_8025_swap16(r8025_init_params_addr);
    for i := 1 to 11 do
      u^.regs^.sifdat_inc := ring_8025_swap16(params.words[i]);
    u^.regs^.sifcmd := r8025_sifcmd_execute;
    for polls := 1 to 3 do begin
      ring_8025_wait(1);
      sts := u^.regs^.sifsts;
      if not sts.error and then not sts.initialize and then not sts.test
      then begin
        status.all := status_$ok;
        return;
      end;
      if sts.error then
        goto fail;
    end;
  end;
fail:
  status.all := status_$r8025_adapter_hardware_error;
end;
