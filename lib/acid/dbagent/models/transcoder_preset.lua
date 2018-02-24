local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    transcoder_preset_id = {
        field_type = 'bigint',
        m = 20,
    },
    preset_name = {
        field_type = 'varbinary',
        m = 128,
        no_hex = true,
    },
    preset_type = {
        field_type = 'varbinary',
        m = 32,
        no_hex = true,
    },
    username = {
        field_type = 'varbinary',
        m = 64,
        no_hex = true,
    },
    description = {
        field_type = 'text',
        m = nil,
    },
    settings = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_table',
    },
    create_ts = {
        field_type = 'bigint',
        m = 20,
    },
    modify_ts = {
        field_type = 'bigint',
        m = 20,
    },
}


_M.shard_fields = {}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.transcoder_preset_id = nil

local ident = {
    transcoder_preset_id = true
}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                settings = false,
                description = false,
                modify_ts = true,
            },
            ident = ident,
            match = {
                _modify_ts = false,
            },
        },
    },
    remove = {
        rw = 'w',
        sql_type = 'remove',
        valid_param = {
            ident = ident,
        },
    },
    get = {
        rw = 'r',
        sql_type = 'get',
        valid_param = {
            ident = ident,
        },
        select_column = tableutil.keys(_M.fields),
        unpack_list = true,
    },
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            idx_username_transcoder_preset_id = {
                'username', 'transcoder_preset_id',
            }
        },
        valid_param = {
            index_columns = {
                username = true,
                transcoder_preset_id = false,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        default = {nlimit = 1},
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
