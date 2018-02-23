local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    group_move_task_id = {
        field_type = 'bigint',
        m = 20,
    },
    task_id = {
        field_type = 'bigint',
        m = 20,
    },
    group_id = {
        field_type = 'bigint',
        m = 20,
    },
    phase = {
        field_type = 'varchar',
        m = 40,
    },
    script = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_to_null',
    },
    tick = {
        field_type = 'int',
        m = 11,
    },
    is_active = {
        field_type = 'int',
        m = 11,
    },
}


_M.shard_fields = {}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.group_move_task_id = nil

local ident = {
    group_move_task_id = true,
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
                phase=false,
                script=false,
                tick=false,
                is_active=false,
            },
            ident = ident,
        },
    },
    incr = {
        rw = 'w',
        sql_type = 'incr',
        valid_param = {
            column = {
                tick=false,
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
            idx_group_id_is_active = {
                'group_id', 'is_active',
            },
            idx_phase_group_id_is_active = {
                'phase', 'group_id', 'is_active',
            },
            PRIMARY = {
                'group_move_task_id',
            },
        },
        valid_param = {
            index_columns = {
                phase = false,
                group_id = false,
                is_active = false,
                group_move_task_id = false,
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
