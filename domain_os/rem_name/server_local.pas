{ REM_NAME_SERVER_LOCAL - is the naming server on this node?

  Image addresses:
    sau2  0x00E4A408  REM_NAME_SERVER_LOCAL

  - Member 13 of the flags of socket 10's descriptor (the naming
    service's socket).  A global without `$'.

  Status stored: none.
}

function rem_name_server_local: boolean;
begin
  rem_name_server_local :=
    sock_flag_allocated in sock_$socket_ptr[rem_name_$sock]^.flags.members;
end;
