local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    task_id = {
        field_type = 'bigint',
        m = 20,
    },
    queue_id = {
        field_type = 'bigint',
        m = 20,
    },
    task_name = {
        field_type = 'varbinary',
        m = 64,
        no_hex = true,
    },
    task_state = {
        field_type = 'varbinary',
        m = 16,
        no_hex = true,
    },
    failure_count = {
        field_type = 'int',
        m = 11,
    },
    task_arguments = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_table',
    },
    task_properties = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_table',
    },
    consumer_id = {
        field_type = 'bigint',
        m = 20,
    },
    result = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_to_null',
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


_M.shard_fields = {'queue_id'}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.task_state = false
add_column.failure_count = false
add_column.task_properties = false
add_column.consumer_id = false

local ident = {
    tack_id = true,
    queue_id = true,
}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
        default = {
            task_state = 'READY',
            failure_count = 0,
            task_properties = '{}',
            consumer_id = -1,
        },
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                task_properties = true,
                modify_ts = true,
            },
            ident = ident,
        },
    },
    set_task_state = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                task_state = true,
                consumer_id = false,
                result = false,
                failure_count = false,
                task_properties = false,
                modify_ts = true,
            },
            ident = ident,
            match = {
                _task_state = false,
                _consumer_id = false,
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
            idx_task_state_queue_id_task_id = {
                'task_state', 'queue_id', 'task_id',
            },
            idx_queue_id_task_id = {
                'queue_id', 'task_id',
            },
        },
        valid_param = {
            index_columns = {
                task_state = false,
                queue_id = true,
                task_id = false,
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
    count_by_state = {
        rw = 'r',
        sql_type = 'count',
        count_as = 'task_count',
        index_to_use = 'idx_task_state_queue_id_task_id',
        valid_param = {
            ident = {
                queue_id = true,
                task_id = true,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
    },
}


return _M
