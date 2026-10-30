{ RING_$GET_ID - the node's id.

  Image addresses:
    sau2  0x00E2FA28  RING_$GET_ID
    sau5  0x00E30F48  RING_$GET_ID
    sau9  0x3C435620  RING_$GET_ID

  - The id is formed from the three id bytes of the controller's
    registers (high, middle, low) and stored back at +8; 1 when the
    controller is not in the system.
  - With `nodeid_prom' it is formed from the four bytes of the node id
    PROM instead, and an id wider than 20 bits crashes the system.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes and the register copy of RING_$GET_ID

  The SAU2 image's frame leaves 4 bytes beyond the five 4-byte objects,
  and the three reads go through a copy of regs while the store uses
  regs itself.  A `with regs^ do' over the reads would explain both if a
  pointer's `with' had a slot of its own (the frame model gives one to
  an array element's `with' only; HINT_$ADD_NET's one pointer `with' has
  none).  Not settled; the plain references are kept. }

[section(os_init_proc, os_init_data)]
function ring_$get_id(in cnum: integer): linteger;
var
  status: status_$t;
  dcte: dcte_ptr_t;
  regs: ring_$regs_ptr_t;
  id: linteger;
begin
%if nodeid_prom %then
  id := node_id[0] * 16#1000000 + node_id[9] * 16#10000
        + node_id[17] * 256 + node_id[25];
  if (id & 16#FFF00000) <> 0 then
    crash_system(status_$network_no_nodeid_prom);
%else
  id := 1;

  dcte := io_$get_dcte(2, cnum, status);

  if status.all <> status_$io_controller_not_in_system then begin
    regs := dcte^.disk_dinit;
    id := regs^.id_12 * 16#10000 + regs^.id_14 * 256 + regs^.id_16;
    regs^.node_id := id;
  end;
%endif

  ring_$get_id := id;
end;
