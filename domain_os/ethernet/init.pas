{ ETHERNET_$INIT - initialize an Ethernet controller.

  Image addresses:
    sau2  0x00E78004  ETHERNET_$INIT
    sau9  0x3C48201C  ETHERNET_$INIT

  - Conditional on the driver (`ethernet_driver', base/config.ins.pas).
    Where it is configured out (the SAU2), a stub that returns
    status_$io_controller_not_in_system, the same code as SCSI_$CINIT.
  - With the driver: the DCTE's unit must be 0 or 1 and its adapter
    answer at the CSR pages its I/O descriptor maps (the DCTE's longword
    at 0x34 points to it); the adapter is reset, the unit's record set
    up, the driver record given the network's UID and a NET_IO port
    created for the unit, and the unit's I/O map space allocated.
  - The result is the status as a longword; a unit out of range or an
    adapter that does not answer is status_$io_controller_not_in_system.

  Status stored: none.
}

[section(ether_proc, ether_data)]
function ethernet_$init(var dcte: dcte_t): integer32;
%if ethernet_driver %then
var
  regs: ethernet_$regs_ptr_t;
  status: status_$t;
  u: ethernet_$unit_ptr_t;
  i: integer;
%endif
begin
%if ethernet_driver %then
  if dcte.cnum <= eth_max_unit then begin
    io_$map_csr(ethernet_$io_desc_ptr_t(dcte.disk_dinit)^, status);
    if status.all <> status_$ok then begin
      ethernet_$init := status.all;
      return;
    end;
    regs := ethernet_$regs_ptr_t(
              ethernet_$io_desc_ptr_t(dcte.disk_dinit)^.csr.va);
    if ethernet_probe(regs) then begin
      if not ethernet_reset(regs, status) then begin
        ethernet_$init := status.all;
        return;
      end;
      u := addr(ether_ucb[dcte.cnum]);
      u^.flags := [eth_unit_configured];
      ml_$exclusion_init(u^.lock);
      u^.users := 0;
      u^.wired := false;
      u^.cnum := dcte.cnum;
      u^.station.high := 0;
      u^.station.low := 0;
      u^.regs := ethernet_$regs_ptr_t(
                   ethernet_$io_desc_ptr_t(dcte.disk_dinit)^.csr.va);
      u^.regs^.control := 0;
      u^.dcte := addr(dcte);
      ml_$exclusion_init(u^.excl_1098);
      for i := 1 to 10 do
        u^.channels[i].open := false;
      ec_$init(u^.rcv_exit_ec);
      u^.rcv_state := eth_rcv_bufs;
      u^.idle_defers := 0;
      for i := 1 to 10 do
        u^.stats.counts[i] := 0;
      ethernet_driver.network_uid := ethernet_$network_uid;
      ethernet_port_array[dcte.cnum] :=
        net_io_$create_port(4, dcte.cnum, addr(ethernet_driver), 0, status);
      if status.all <> status_$ok then begin
        ethernet_$init := status.all;
        return;
      end;
      case dcte.cnum of
        0: discard(io_$alloc(ether_ucb[dcte.cnum].io_unit, 8092, true,
                             16#80000, status));
        1: discard(io_$alloc(ether_ucb[dcte.cnum].io_unit, 8092, true,
                             16#84000, status));
      end;
      if status.all <> status_$ok then begin
        ethernet_$init := status.all;
        return;
      end;
      ethernet_$init := status_$ok;
      return;
    end;
  end;
  ethernet_$init := status_$io_controller_not_in_system;
%else
  ethernet_$init := status_$io_controller_not_in_system;
%endif
end;
