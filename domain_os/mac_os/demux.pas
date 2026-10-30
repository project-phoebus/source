{ MAC_OS_$DEMUX - hand a received packet to the channel its type belongs
  to.

  Image addresses:
    sau2  0x00E0B816  MAC_OS_$DEMUX

  - The packet's frame type is looked up in the port's packet-type
    table; the entry's channel's callback gets the packet record, with
    the arrival time and the channel's address stored in it.

  Status stored:
    the callback's status: the packet was handed on
    status_$mac_XXX_unknown (16#3A000F): no entry holds the type, or its
      channel has no callback
}

{ TODO(pascal) 0x46 frame bytes of MAC_OS_$DEMUX hold nothing

  Nothing addresses the 0x46 bytes of the frame above clock; below it,
  the frame leaves 16 bytes for entry_idx and channel and the two `with'
  temporaries (12), 4 more.  A local of 0x46 bytes
  declared before clock fits the top (mac_os_$rcv_pkt_t is 0x4C bytes,
  so not a copy of the packet record); the stand-ins unused_40,
  unused_44 and unused_46 (64 bytes at a multiple of 8 from A6, a
  longword and a word: one 0x46-byte object would be placed at a
  multiple of 8 and lengthen the frame) and unused_5c hold the places.
  Not settled. }

procedure mac_os_$demux(in out pkt: mac_os_$rcv_pkt_t;
                        in port_num: integer;
                        in demux_flag: boolean;
                        out status: status_$t);
var
  unused_40: array[1..64] of char;        { stand-in: TODO above }
  unused_44: integer32;
  unused_46: integer;
  clock: time_$clock_t;
  entry_idx: integer;
  channel: pinteger;
  unused_5c: integer32;                   { stand-in: TODO above }
begin
  status.all := status_$ok;
  time_$abs_clock(clock);

  with mac_os_$port_pkt_tables[port_num] do begin
    entry_idx := mac_os_$find_packet_type(pkt.frame_type, entries,
                                          entry_count);
    if entry_idx = -1 then begin
      status.all := status_$mac_XXX_unknown;
      return;
    end;
    channel := entries[entry_idx].channel_index;
  end;

  with mac_os_$channel_table[channel] do begin
    if callback = nil then begin
      status.all := status_$mac_XXX_unknown;
      return;
    end;
    pkt.time := clock;
    pkt.channel := addr(mac_os_$channel_table[channel]);
    callback^(pkt, port_num, demux_flag, status);
  end;
end;
