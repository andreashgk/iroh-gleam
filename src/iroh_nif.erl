-module(iroh_nif).

-export([canceltoken_cancel/1, connection_open_bi/1, connection_open_uni/1,
         connection_subscribe/2, endpoint_addr/1, endpoint_bind/3, endpoint_close/1,
         endpoint_connect/3, endpoint_id/1, endpoint_is_closed/1, endpoint_online/1,
         endpoint_subscribe/2, incoming_accept/1, incoming_ignore/1, incoming_refuse/1,
         public_key_from_string/1, public_key_to_addr/1, public_key_to_string/1,
         secret_key_generate/0, secret_key_to_public/1, stream_finish/1, stream_read/2,
         stream_read_exact/2, stream_read_to_end/2, stream_write/2, ticket_from_addr/1,
         ticket_to_addr/1]).

-on_load init/0.

init() ->
    PrivDir =
        case code:priv_dir(iroh) of
            {error, bad_name} ->
                "priv";
            Dir ->
                Dir
        end,
    SoName = filename:join(PrivDir, "libiroh_nif"),
    erlang:load_nif(SoName, 0).

canceltoken_cancel(_) ->
    exit(nif_library_not_loaded).

connection_open_bi(_) ->
    exit(nif_library_not_loaded).

connection_open_uni(_) ->
    exit(nif_library_not_loaded).

connection_subscribe(_, _) ->
    exit(nif_library_not_loaded).

endpoint_addr(_) ->
    exit(nif_library_not_loaded).

endpoint_bind(_, _, _) ->
    exit(nif_library_not_loaded).

endpoint_close(_) ->
    exit(nif_library_not_loaded).

endpoint_connect(_, _, _) ->
    exit(nif_library_not_loaded).

endpoint_id(_) ->
    exit(nif_library_not_loaded).

endpoint_is_closed(_) ->
    exit(nif_library_not_loaded).

endpoint_online(_) ->
    exit(nif_library_not_loaded).

endpoint_subscribe(_, _) ->
    exit(nif_library_not_loaded).

incoming_accept(_) ->
    exit(nif_library_not_loaded).

incoming_ignore(_) ->
    exit(nif_library_not_loaded).

incoming_refuse(_) ->
    exit(nif_library_not_loaded).

public_key_from_string(_) ->
    exit(nif_library_not_loaded).

public_key_to_addr(_) ->
    exit(nif_library_not_loaded).

public_key_to_string(_) ->
    exit(nif_library_not_loaded).

secret_key_generate() ->
    exit(nif_library_not_loaded).

secret_key_to_public(_) ->
    exit(nif_library_not_loaded).

stream_finish(_) ->
    exit(nif_library_not_loaded).

stream_read(_, _) ->
    exit(nif_library_not_loaded).

stream_read_exact(_, _) ->
    exit(nif_library_not_loaded).

stream_read_to_end(_, _) ->
    exit(nif_library_not_loaded).

stream_write(_, _) ->
    exit(nif_library_not_loaded).

ticket_from_addr(_) ->
    exit(nif_library_not_loaded).

ticket_to_addr(_) ->
    exit(nif_library_not_loaded).
