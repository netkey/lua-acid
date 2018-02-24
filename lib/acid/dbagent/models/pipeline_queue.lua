local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    queue_id = {
        field_type = 'bigint',
        m = 20,
    },
    service = {
        field_type = 'varbinary',
        m = 128,
        no_hex = true,
    },
    name = {
        field_type = 'varbinary',
        m = 128,
        no_hex = true,
    },
    owner = {
        field_type = 'varbinary',
        m = 64,
        no_hex = true,
    },
    priority = {
        field_type = 'int',
        m = 11,
    },
    max_consumer_count = {
        field_type = 'int',
        m = 11,
    },
    queue_state = {
        field_type = 'varbinary',
        m = 16,
        no_hex = true,
    },
    properties = {
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
add_column.owner = false
add_column.queue_state = false
add_column.properties = false

local ident = {
    queue_id = true
}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
        default = {
            owner = '',
            queue_state = 'ENABLED',
            properties = '{}',
        },
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                name = false,
                owner = false,
                priority = false,
                max_consumer_count = false,
                queue_state = false,
                properties = false,
                modify_ts = true,
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
            idx_service_queue_id = {
                'service', 'queue_id',
            },
            idx_owner_queue_id = {
                'owner', 'queue_id',
            },
            idx_owner_service_queue_id = {
                'owner', 'service', 'queue_id',
            },
            PRIMARY = {
                'queue_id',
            },
        },
        valid_param = {
            index_columns = {
                owner = false,
                service = false,
                queue_id = true,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        default = {nlimit = 1024},
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
