{ SMD_$ALLOC_HDM - allocate space in hidden display memory.

  Image addresses:
    sau2  0x00E6D92E  SMD_$ALLOC_HDM
    sau4  0x0F877FF0  SMD_$ALLOC_HDM
    sau5  0x00E6FC68  SMD_$ALLOC_HDM
    sau9  0x3C474614  SMD_$ALLOC_HDM

  - First fit: the block is removed, or shortened from its start.
  - pos by the display type: a portrait display's hidden memory is the
    columns from 800, a landscape's the 224 lines from 800, tiled 224
    columns at a time; another type leaves pos as it was.
  - The color displays have their own (`color_board', `gpu_driver',
    base/config.ins.pas).
  - With `display_devices' a 1280x1024 display's hidden memory is the
    columns from 1280, 224 columns for each 1024 lines; the other
    device types' the 224 lines from 800, as a landscape display's; any
    other type crashes the system.

  Status stored:
    status_$ok: the space was allocated
    smd_$illegal_caller: the process has no display unit
    smd_$hdm_full: no block is large enough
}

{ TODO(pascal) frame of SMD_$ALLOC_HDM not accounted

  The image's frame is 0x20 bytes, and the code addresses only hw, at
  -0x14.  With need's copy slot at the top (a value parameter's copy,
  here never written, its value held in a register) and the locals in
  the order declared (unit, i, j, block_offset 2 each, hdm_list 4
  aligned), hw falls at -0x14; dpc's --dump-locals gives the locals -4
  .. -0x14 in that order.  With the `with' slot of blocks[i] (4) that is
  24 bytes; 8 are not explained.  The declaration order is chosen to fit
  the one address the image shows. }

procedure smd_$alloc_hdm(need: integer; out pos: smd_$pos_t;
                         out status: status_$t);
var
  unit: integer;
  i: integer;
  j: integer;
  block_offset: integer;
  hdm_list: smd_hdm_list_ptr_t;
  hw: smd_display_hw_ptr_t;               { in the frame }
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then begin
    status.all := smd_$illegal_caller;
    return;
  end;
  hdm_list := smd_$wired_data.unit[unit].hdm_list;
  hw := smd_$wired_data.unit[unit].hw;

  { first fit }
  for i := 1 to hdm_list^.count do
    with hdm_list^.blocks[i] do
      if need <= size then begin
        { the space's position }
        case hw^.display_type of
%if display_devices %then
          smd_$bw4_1280x1024: begin
            pos.column := (offset div 1024) * 224 + 1280;
            pos.line := offset mod 1024;
          end;
          smd_$color4_display, smd_$color5_display,
          smd_$bw5_1024x800: begin
            block_offset := offset;
            pos.column := (block_offset div 224) * 224;
            pos.line := block_offset mod 224 + 800;
          end;
          otherwise begin
            crash_system(smd_$not_implemented);
          end;
%else
          smd_$bw_15p: begin
            pos.column := 800;
            pos.line := offset;
          end;
          smd_$bw_19l: begin
            block_offset := offset;
            pos.column := (block_offset div 224) * 224;
            pos.line := block_offset mod 224 + 800;
          end;
%if color_board %then
          smd_$color_display, smd_$800_color: begin
            pos.column := 800;
            pos.line := offset + 1024;
          end;
%endif
%if gpu_driver %then
          smd_$color2_display: begin
            pos.column := 1280;
            pos.line := offset;
          end;
          smd_$color3_display: begin
            block_offset := offset;
            pos.column := (block_offset div 219) * 224;
            pos.line := block_offset mod 219 + 805;
          end;
%endif
%endif
        end;

        { an exact fit removes the block }
        if need = size then begin
          hdm_list^.count := hdm_list^.count - 1;
          for j := i to hdm_list^.count do
            hdm_list^.blocks[j] := hdm_list^.blocks[j + 1];
        end
        else begin
          size := size - need;
          offset := offset + need;
        end;
        status.all := status_$ok;
        return;
      end;

  status.all := smd_$hdm_full;
end;
