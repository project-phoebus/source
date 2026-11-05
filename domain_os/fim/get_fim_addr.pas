{ FIM_$GET_FIM_ADDR - the current address space's user FIM handler.

  Image addresses:
    sau2  0x00E0AA04  FIM_$GET_FIM_ADDR
    sau4  0x0F80B14C  FIM_$GET_FIM_ADDR
    sau6  0x7800B2C2  FIM_$GET_FIM_ADDR
    sau7  0x3C40C056  FIM_$GET_FIM_ADDR

  Status stored: none.
}

function fim_$get_fim_addr: integer32;
begin
  fim_$get_fim_addr := fim_$user_fim_addr[proc1_$as_id];
end;
