local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    level = {
        field_type = 'varchar',
        m = 16,
    },
    log_ts = {
        field_type = 'bigint',
        m = 20,
    },
    content = {
        field_type = 'varchar',
        m = 4096,
    },
    log_file = {
        field_type = 'varchar',
        m = 512,
    },
    source_file = {
        field_type = 'varchar',
        m = 16,
    },
    line_number = {
        field_type = 'int',
        m = 11,
    },
    node_id = {
        field_type = 'varchar',
        m = 16,
    },
    node_ip = {
        field_type = 'varchar',
        m = 16,
    },
    count = {
        field_type = 'int',
        m = 11,
    },
}


_M.shard_fields = {}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
    },
    remove_multi = {
        rw = 'w',
        sql_type = 'remove_multi',
        valid_param = {
            range = {
                log_ts = true,
            },
            ident = {
                log_file = false,
                source_file = false,
                line_number = false,
                node_id = false,
                node_ip = false,
            },
        },
    },
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            idx_log_ts = {
                'log_ts',
            },
            idx_node_ip_log_ts = {
                'node_ip', 'log_ts',
            },
            PRIMARY = {
                '_id',
            },
        },
        valid_param = {
            index_columns = {
                node_ip = false,
                _id = false,
            },
            range = {
                log_ts = false,
            },
            ident = {
                log_file = false,
                source_file = false,
                line_number = false,
                node_id = false,
                node_ip = false,
            },
            extra = {
                leftopen = false,
                order_by = false,
                nlimit = false,
            },
        },
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
    groupby = {
        rw = 'r',
        sql_type = 'gorup_by',
        valid_param = {
            range = {
                log_ts = false,
            },
            ident = {
                level = false,
                log_file = false,
                source_file = false,
                line_number = false,
                node_id = false,
                node_ip = false,
            },
            extra = {
                group_by = true,
                group_by_asc = false,
                group_by_desc = false,
            },
        },
        query_opts = {
            timeout = 3000,
        },
    },
}


return _M
