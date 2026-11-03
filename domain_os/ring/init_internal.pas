{ ring_$init_internal - probe a unit's controller and clear its status words.

  Image addresses:
    sau2  0x00E2FA86  ring_$init_internal (module-local)
    sau5  0x00E30FA6  ring_$init_internal (module-local)
    sau8  0x03C32780  ring_$init_internal (module-local)
    sau9  0x3C435678  ring_$init_internal (module-local)

  - The unit takes the DCTE's register block, which TESTPAGE probes.
  - With the vector registers (`ring_vector_regs', the SAU5's
    controller) the three are set to 16#3D00.
  - With the controller with buffers of its own (`ring8_controller')
    the DCTE holds the unit's I/O descriptor: both CSR windows are
    mapped, the node id read (NODE_$ME), the controller's type taken
    from its ctlr_id register, and a known type's unit acquired with
    RING8_$INT as its interrupt (the first unit's interrupt serves
    both: the second is acquired without one).  The command block is
    loaded, the receive buffers and the transmit area laid out in the
    controller's memory by the type's parameters, the driver's lengths
    set, the controller's registers initialized, its memory mapped when
    the type says so, the device enabled (for unit 1, or unit 0 when
    unit 1 has no controller), and the receive page given its map entry.

  Returns:
    0: the controller answers; its status words were cleared
    status_$io_controller_not_in_system: the probe faulted, or (with
      `ring8_controller') the type is unknown or the unit could not be
      acquired
    IO_$ALLOC's or IO_$ENABLE_DEVICE's status (`ring8_controller')

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function ring_$init_internal(var unit: ring_$unit_t; var dcte: dcte_t):
  integer32;
  internal;
%if ring8_controller %then
label
  acquired;
var
  { The controllers' memory in the I/O space, per unit. }
  ring_$mem_iova: static array[0..1] of linteger :=
    [16#000D0000, 16#000E0000];
  { The controller types' parameters. }
  ring_$ctlr_params: static array[ring8_ctlr_16k..ring8_ctlr_128k]
                       of ring8_$ctlr_param_t := [
    [mem_words := 16#2000, buf_words := 16#400,
     max_data_words := 16#200],
    [mem_words := 16#10000, buf_words := 16#A00,
     max_data_words := 16#800, map_mem := true]];
  { Twelve entries nothing reads (three runs of the same four). }
  unused_20: static array[1..12] of ring8_$unused_entry_t := [
    [-1, -1, 0, 0], [16#240, 16#340, 4, 0], [16#220, 16#320, 4, 0],
    [16#220, 16#320, 8, 0],
    [-1, -1, 0, 0], [16#240, 16#340, 4, 0], [16#220, 16#320, 4, 0],
    [16#220, 16#320, 8, 0],
    [-1, -1, 0, 0], [16#240, 16#340, 4, 0], [16#220, 16#320, 4, 0],
    [16#220, 16#320, 8, 0]];
  status: status_$t;
  ccb_status: integer32;
  regs: ring8_$csr_ptr_t;
  params: ^ring8_$ctlr_param_t;
  i: integer;
begin
  { the two CSR windows }
  io_$map_csr(ring8_$io_desc_ptr_t(dcte.disk_dinit)^, status);
  io_$map_csr(ring8_$io_desc_ptr_t(
                ring8_$io_desc_ptr_t(dcte.disk_dinit)^.unused_00)^,
              status);
  regs := ring8_$csr_ptr_t(ring8_$io_desc_ptr_t(dcte.disk_dinit)^.csr.va);
  unit.hw_regs := regs;
  node_$me := ring_$get_id(0);
  ml_$exclusion_init(ring_$ctl[dcte.cnum].buf_lock);

  { the controller's type, and the unit acquired }
  unit.ctlr_type := rshft(regs^.ctlr_id, 8) & 16#FF;
  if (unit.ctlr_type = ring8_ctlr_128k)
     or else (unit.ctlr_type = ring8_ctlr_16k) then begin
    status.all := 0;
    if ring_$int_acquired then
      ring8_$io_desc_ptr_t(dcte.disk_dinit)^.int.has_int := false;
    io_$acquire(ring8_$io_desc_ptr_t(dcte.disk_dinit)^, addr(ring8_$int),
                addr(dcte), ring_$io_unit[dcte.cnum], status);
    if status.all = 0 then
      goto acquired;
  end;
  unit.ctlr_type := 0;
  ring_$init_internal := status_$io_controller_not_in_system;
  return;

acquired:
  ring_$int_acquired := true;
  ring_$ccb[dcte.cnum].node := node_$me;
  ccb_status := ring_$set_ccb(dcte.cnum, false);
  if ccb_status <> 0 then
    crash_system(status_$network_hardware_error);

  { the buffers and the transmit area in the controller's memory }
  params := addr(ring_$ctlr_params[unit.ctlr_type]);
  unit.rx_buf_cnt := (params^.mem_words - params^.buf_words)
                     div params^.buf_words;
  unit.max_data_words := params^.max_data_words;
  unit.rx_bufs[1].ctlr_addr := 0;
  for i := 2 to unit.rx_buf_cnt do
    unit.rx_bufs[i].ctlr_addr :=
      unit.rx_bufs[i - 1].ctlr_addr + params^.buf_words;
  unit.cmd_addr := unit.rx_bufs[unit.rx_buf_cnt].ctlr_addr
                   + params^.buf_words;
  ring_$driver.max_data_len := params^.max_data_words * 2;
  ring_$driver.mtu := params^.buf_words * 2;

  { the controller's registers }
  regs^.ctlr_id := 1;
  regs^.status := [];
  regs^.command := [];
  regs^.rx_status := [];
  regs^.tx_ack := 1;
  regs^.rx_ack := 1;
  regs^.ack_0006 := 1;
  regs^.clear_error := 1;
  regs^.reg_0402 := 1;
  regs^.reg_0406 := 1;

  if ring_$ctlr_params[unit.ctlr_type].map_mem then begin
    discard(io_$alloc(ring_$io_unit[dcte.cnum], 16#FFFF, true,
                      ring_$mem_iova[dcte.cnum], status));
    if status.all <> 0 then begin
      ring_$init_internal := status.all;
      return;
    end;
  end;
  if (dcte.cnum <> 0)
     or else ((dcte.cnum = 0)
              and then (ring_$ctl[1].ctlr_type = 0)) then begin
    io_$enable_device(ring_$io_unit[dcte.cnum], status);
    if status.all <> 0 then begin
      ring_$init_internal := status.all;
      return;
    end;
  end;

  { the receive page's map entry }
  mmu_$install(0, unit.rcv_page, 0, 16#16);
  unit.rcv_pmape := mmu_$get_pmape_addr(unit.rcv_page);
  ring_$init_internal := 0;
end;
%else
var
  regs: ring_$regs_ptr_t;
  location: univ_ptr;
  data: integer;
begin
  regs := dcte.disk_dinit;
  unit.hw_regs := regs;
  location := regs;

  if not testpage(0, location, data) then
    ring_$init_internal := status_$io_controller_not_in_system
  else begin
    regs^.xmit_csr := [];
    regs^.rcv_csr := [];
%if ring_vector_regs %then
    regs^.vector_40 := 16#3D00;
    regs^.vector_48 := 16#3D00;
    regs^.vector_50 := 16#3D00;
%endif
    ring_$init_internal := 0;
  end;
end;
%endif
