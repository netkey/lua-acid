local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    level = {
        checker = {
            ['type'] = 'string',
            max_length = 16,
        },
        field_type = 'varchar',
    },
    log_ts = {
        checker = {
            {
                ['type'] = 'integer',
            },
            {
                ['type'] = 'string_number',
            },
        },
        field_type = 'bigint',
    },
    source = {
        checker = {
            ['type'] = 'string',
            max_length = 512,
        },
        field_type = 'varchar',
    },
    log_file = {
        checker = {
            ['type'] = 'string',
            max_length = 512,
        },
        field_type = 'varchar',
    },
    line_number = {
        checker = {
            {
                ['type'] = 'integer',
            },
            {
                ['type'] = 'string_number',
            },
        },
        field_type = 'int',
    },
    content = {
        checker = {
            ['type'] = 'string',
            max_length = 4096,
        },
        field_type = 'varchar',
    },
    node_id = {
        checker = {
            ['type'] = 'string',
            max_length = 16,
        },
        field_type = 'varchar',
    },
    node_ip = {
        checker = {
            ['type'] = 'string',
            max_length = 16,
        },
        field_type = 'varchar',
    },
    count = {
        checker = {
            {
                ['type'] = 'integer',
            },
            {
                ['type'] = 'string_number',
            },
        },
        field_type = 'int',
    },
}


_M.shard_fields = {}


_M.actions = {
    add = {
        rw = 'w',
        valid_param = {
            column = {
                level = true,
                log_ts = true,
                source = true,
                log_file = true,
                line_number = true,
                content = true,
                node_id = true,
                node_ip = true,
                count = true,
            },
        },
    },
    ls = {
        rw = 'r',
        all_index = {
            {'log_ts', '_id'},
            {'node_ip', '_id'},
        },
        valid_param = {
            index_keys = {
                level = false,
                log_ts = false,
                source = false,
                log_file = false,
                node_id = false,
                node_ip = false,
            },
            match = {
                _level = false,
                _log_ts = false,
                _source = false,
                _log_file = false,
                _node_id = false,
                _node_ip = false,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        select_column = tableutil.keys(_M.fields),
    },
    remove = {
        rw = 'w',
        valid_param = {
            ident = {
                level = false,
                log_ts = false,
                source = false,
                log_file = false,
                node_id = false,
                node_ip = false,
            },
            match = {
                _level = false,
                _log_ts = false,
                _source = false,
                _log_file = false,
                _node_id = false,
                _node_ip = false,
            },
        },
    },
    set = {
        rw = 'w',
        valid_param = {
            column = {
                level = false,
                log_ts = false,
                source = false,
                log_file = false,
            },
            ident = {
                level = false,
                log_ts = false,
                source = false,
                log_file = false,
                node_id = false,
                node_ip = false,
            },
        },
    },
    count = {
        rw = 'r',
        valid_param = {
            range = {
                log_ts = false,
            },
            ident = {
                level = false,
                source = false,
                log_file = false,
                node_id = false,
                node_ip = false,
            },
            extra = {
                desc = false,
                asc = false,
                group_by = true,
            },
        },
    },
}


return _M
