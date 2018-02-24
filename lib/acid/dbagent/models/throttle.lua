local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    service = {
        field_type = 'varchar',
        m = 64,
    },
    username = {
        field_type = 'varchar',
        m = 64,
    },
    limit = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_general',
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
}

_M.shard_fields = {}


local add_column = {}

for name, _ in pairs(_M.fields) do
    add_column[name] = true
end


local ident = {
    service = true,
    username = true,
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
                limit = true,
                ts = true,
            },
            ident = ident,
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
        unpack_list = true,
        select_column = tableutil.keys(_M.fields),
    },
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            idx_service_username = {
                'service', 'username',
            },
        },
        valid_param = {
            index_columns = {
                service = false,
                username = false,
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
