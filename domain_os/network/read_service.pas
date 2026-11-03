{ NETWORK_$READ_SERVICE - the node's allowed network services.

  Image addresses:
    sau2  0x00E71D7C  NETWORK_$READ_SERVICE
    sau8  0x03C7C630  NETWORK_$READ_SERVICE

  - While the network service is active the whole service record is
    returned; otherwise an empty service set with the remote pool's
    size.

  Status stored: none.
}

[section(procedure$, data$)]
procedure network_$read_service(out service: network_$service_t);
begin
  if network_service_active in network_$allowed_service.service then
    service := network_$allowed_service
  else begin
    service.service := [];
    service.remote_pool := network_$allowed_service.remote_pool;
  end;
end;
