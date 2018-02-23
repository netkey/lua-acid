local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    task_id = {
        field_type = 'bigint',
        m = 20,
    },
    info = {
        field_type = 'varchar',
        m = 256,
    },
    status = {
        field_type = 'int',
        m = 11,
    },
    total = {
        field_type = 'bigint',
        m = 20,
    },
    complete = {
        field_type = 'int',
        m = 11,
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
}


_M.shard_fields = {}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.task_id = nil

local ident = {
    task_id = true,
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
                info=false,
                total=false,
                status=false,
                complete=false,
                ts=false,
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
        select_column = tableutil.keys(_M.fields),
        unpack_list = true,
    },
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            PRIMARY = {
                'task_id',
            },
        },
        valid_param = {
            index_columns = {
                task_id = false,
            },
            extra = {
                nlimit = false,
            },
        },
        default = {nlimit = 10},
        query_opts = {
            timeout = 5000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
