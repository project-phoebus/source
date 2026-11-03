{ RING_$GET_ID - the node's id.

  Image addresses:
    sau2  0x00E2FA28  RING_$GET_ID
    sau4  0x0F832F20  RING_$GET_ID
    sau5  0x00E30F48  RING_$GET_ID
    sau8  0x03C326F0  RING_$GET_ID
    sau9  0x3C435620  RING_$GET_ID

  - The id is formed from the three id bytes of the controller's
    registers (high, middle, low) and stored back at +8; 1 when the
    controller is not in the system.
  - With `ring_board_dma' the id bytes are other registers, and the id
    is not stored back.
  - With `nodeid_prom' it is formed from the four bytes of the node id
    PROM instead, and an id wider than 20 bits crashes the system.
  - With `nodeid_prom_probe' the node id PROM is probed first: the id
    comes from it when it answers and its first word is zero, from the
    first unit's controller registers otherwise, and an id wider than 20
    bits crashes the system.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes and the register copy of RING_$GET_ID

  The SAU2 image's frame leaves 4 bytes beyond the five 4-byte objects,
  and the three reads go through a copy of regs while the store uses
  regs itself.  A `with regs^ do' over the reads would explain both if a
  pointer's `with' had a slot of its own (the frame model gives one to
  an array element's `with' only; HINT_$ADD_NET's one pointer `with' has
  none).  Not settled; the plain references are kept.

  The `nodeid_prom_probe' form's probe_data, the first local, is a
  4-byte object at the top of the frame, where the SAU2 image's status
  lies one longword lower than the other locals put it, and the SAU9
  image's frame is as large as with it.  Declared in every form it would
  account for those 4 bytes on both; it is declared with the part only,
  until that is checked against both images. }

[section(os_init_proc, os_init_data)]
function ring_$get_id(in cnum: integer): linteger;
var
%if nodeid_prom_probe %then
  probe_data: integer32;
%endif
  status: status_$t;
  dcte: dcte_ptr_t;
%if nodeid_prom_probe %then
  regs: ring_$id_words_ptr_t;
%else
  regs: ring_$regs_ptr_t;
%endif
  id: linteger;
begin
%if nodeid_prom_probe %then
  probe_data := 1;
  if testpage(0, addr(node_id_prom), probe_data)
     and then (node_id_prom[0] = 0) then
    regs := addr(node_id_prom)
  else
    regs := addr(ring2);
  id := rshft(regs^[0], 8) * 16#1000000 + rshft(regs^[1], 8) * 16#10000
        + rshft(regs^[2], 8) * 256 + rshft(regs^[3], 8);
  if (id & 16#FFF00000) <> 0 then
    crash_system(status_$network_no_nodeid_prom);
%elseif nodeid_prom %then
  id := node_id[0] * 16#1000000 + node_id[9] * 16#10000
        + node_id[17] * 256 + node_id[25];
  if (id & 16#FFF00000) <> 0 then
    crash_system(status_$network_no_nodeid_prom);
%else
  id := 1;

  dcte := io_$get_dcte(2, cnum, status);

  if status.all <> status_$io_controller_not_in_system then begin
    regs := dcte^.disk_dinit;
%if ring_board_dma %then
    id := regs^.id_0a * 16#10000 + regs^.id_0c * 256 + regs^.id_0e;
%else
    id := regs^.id_12 * 16#10000 + regs^.id_14 * 256 + regs^.id_16;
    regs^.node_id := id;
%endif
  end;
%endif

  ring_$get_id := id;
end;
