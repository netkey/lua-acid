local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    username = {
        field_type = 'varchar',
        m = 64,
    },
    accesskey = {
        field_type = 'varchar',
        m = 64,
    },
    secretkey = {
        field_type = 'varchar',
        m = 64,
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
    is_del = {
        field_type = 'tinyint',
        m = 4,
    },
}

_M.shard_fields = {}


local add_column = {}

for name, _ in pairs(_M.fields) do
    add_column[name] = true
end

add_column.is_del = false


local ident = {accesskey = true}


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
                is_del=false,
                ts=false,
            },
            ident = ident,
        },
    },
    markdel = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                is_del=false,
            },
            ident = ident,
        },
        default = {is_del = 1}
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
        indexes = {
            idx_username_accesskey = {
                'username', 'accesskey',
            },
            idx_accesskey = {
                'accesskey',
            },
        },
        valid_param = {
            index_columns = {
                username = false,
                accesskey = false,
            },
            extra = {
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
