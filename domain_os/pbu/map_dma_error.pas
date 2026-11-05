{ pbu_map_dma_error - make a DMA manager's status the PBU's.

  Image addresses:
    sau7  0x3C4B66F2  pbu_map_dma_error (module-local)
    sau8  0x03CA56F2  pbu_map_dma_error (module-local)

  - Only with the AT bus's units (`pbu_atbus_units'): each of the DMA
    manager's five statuses becomes the PBU's like one; any other status
    gets its fail bit set.

  Status stored:
    status_$pbu_illegal_dma_channel: status_$dma_illegal_channel
    status_$pbu_bad_controller_memory_length:
      status_$dma_illegal_byte_count
    status_$pbu_dma_channel_in_use: status_$dma_channel_in_use
    status_$pbu_dma_channel_not_in_use: status_$dma_channel_not_allocated
    status_$pbu_dma_not_at_end: status_$dma_did_not_finish
    the status, its fail bit set: any other
}

procedure pbu_map_dma_error(in out status: status_$t); internal;
begin
  case status.all of
    status_$dma_illegal_channel:
      status.all := status_$pbu_illegal_dma_channel;
    status_$dma_illegal_byte_count:
      status.all := status_$pbu_bad_controller_memory_length;
    status_$dma_channel_in_use:
      status.all := status_$pbu_dma_channel_in_use;
    status_$dma_channel_not_allocated:
      status.all := status_$pbu_dma_channel_not_in_use;
    status_$dma_did_not_finish:
      status.all := status_$pbu_dma_not_at_end;
    otherwise
      status.fail := true;
  end;
end;
