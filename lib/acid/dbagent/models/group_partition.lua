local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    group_id = {
        field_type = 'bigint',
        m = 20,
    },
    partition_id = {
        field_type = 'binary',
        m = 16,
    },
}


_M.shard_fields = {}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = {
                group_id = true,
                partition_id = true,
            },
        },
    },
    remove = {
        rw = 'w',
        sql_type = 'remove',
        valid_param = {
            ident = {
                group_id = true,
                partition_id = true,
            },
        },
    },
    bygroup = {
        rw = 'r',
        sql_type = 'get_multi',
        valid_param = {
            ident = {
                group_id = true,
            },
        },
        select_column = tableutil.keys(_M.fields),
    },
    bypartition = {
        rw = 'r',
        sql_type = 'get_multi',
        valid_param = {
            ident = {
                partition_id = true,
            },
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
