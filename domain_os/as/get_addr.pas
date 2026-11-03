{ AS_$GET_ADDR - return the base and size of an address-space region.

  Image addresses:
    sau2  0x00E583F0  AS_$GET_ADDR
    sau8  0x03C60668  AS_$GET_ADDR
    sau9  0x3C45F7DC  AS_$GET_ADDR

  - region is one of as_$region_* (private A, global A, private B,
    global B); any other gets base 16#7FFFFFFF and size 0.
  - The sizes are the MST_ segment counts times 32 KB, except private
    B's, a constant: 8 segments, or 128 with the large address space,
    whose regions are mst/mst.ins.pas's constants, or 64 with the layout
    chosen at boot.

  Status stored: none.
}

procedure as_$get_addr(out addr_range: as_$addr_range_t;
                       in region: integer);
const
  segment_shift = 15;
%if large_address_space %then
  as_private_b_size = 16#400000;
%elseif run_time_layout %then
  as_private_b_size = 16#200000;
%else
  as_private_b_size = 16#40000;
%endif
  as_no_region_base = 16#7FFFFFFF;
begin
  case region of
    as_$region_private_a: begin
      addr_range.base := 0;
      addr_range.size := lshft(mst_$private_a_size, segment_shift);
    end;
    as_$region_global_a: begin
      addr_range.base := lshft(mst_$seg_global_a, segment_shift);
      addr_range.size := lshft(mst_$global_a_size, segment_shift);
    end;
    as_$region_private_b: begin
      addr_range.base := lshft(mst_$seg_private_b, segment_shift);
      addr_range.size := as_private_b_size;
    end;
    as_$region_global_b: begin
      addr_range.base := lshft(mst_$seg_global_b, segment_shift);
      addr_range.size := lshft(mst_$global_b_size, segment_shift);
    end;
    otherwise begin
      addr_range.base := as_no_region_base;
      addr_range.size := 0;
    end;
  end;
end;
