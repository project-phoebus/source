{ ring_8025_initialize - reset a unit's adapter and initialize its
  controller.

  Image addresses:
    sau7  0x3C495E0C  ring_8025_initialize
    sau8  0x03C89524  ring_8025_initialize
    sau9  0x3C485124  ring_8025_initialize

  - Up to three tries of: the reset, the device enabled on its bus, the
    parameters written through the system interface, the execute
    command, and three polls a tick apart.  Done when the status shows
    none of initialize, test and error; error ends the tries.
  - With `ring_8025_dma_channel' the unit's DMA channel is stopped
    before each reset and set to cascade mode in place of the device's
    enabling, and the burst sizes are zero.
  - The parameters carry the physical addresses of the unit's system
    command and status blocks in its control area (with
    `ring_8025_iomap' their bus addresses, at the region's control
    page); their interrupt vectors are not set.

  Status stored:
    status_$ok: the controller is initialized
    ring_8025_reset's status: the reset failed
    io_$enable_device's status: the device could not be enabled
    dma_$start_ncheck's status: the DMA channel could not be started
    status_$r8025_adapter_hardware_error: the controller did not take
      the parameters
}

procedure ring_8025_initialize(u: ring_8025_$unit_ptr_t;
                               out status: status_$t); internal;
label
  fail;
var
  params: ring_8025_$init_params_t;
%if ring_8025_dma_channel %then
  count: integer32;
%endif
  sts: ring_8025_$sifsts_t;
  tries: integer;
  i: integer;
  polls: integer;
begin
%if ring_8025_no_data_bursts %then
  params.options := 16#9C00;
%else
  params.options := 16#9F00;
%endif
%if ring_8025_dma_channel %then
  params.burst_sizes := 0;
%else
  params.burst_sizes := -16#10002;            { 16#FFFEFFFE }
%endif
  params.abort_dma := chr(3);
  params.abort_parity := chr(3);
%if ring_8025_iomap %then
  params.scb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].scb)),
                     sizeof(ring_8025_$scb_t), u^.iomap_page + r8025_map_ctl);
  params.ssb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].ssb)),
                     sizeof(ring_8025_$ssb_t), u^.iomap_page + r8025_map_ctl);
%else
  params.scb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].scb)));
  params.ssb_pa := ring_8025_vtop(
                     integer32(addr(ring8025_$aux_da.ctl[u^.cnum].ssb)));
%endif
  for tries := 1 to 3 do begin
%if ring_8025_dma_channel %then
    dma_$stop(u^.dma_channel, count, status);
%endif
    ring_8025_reset(u^.regs, status);
    if status.all <> status_$ok then
      return;
%if ring_8025_dma_channel %then
    dma_$start_ncheck(u^.dma_channel, 0, 0, 1, 4, status);
%else
    io_$enable_device(u^.io_unit, status);
%endif
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
