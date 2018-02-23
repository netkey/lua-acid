local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    group_id = {
        field_type = 'bigint',
        m = 20,
    },
    readonly = {
        field_type = 'tinyint',
        m = 4,
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
    space_used = {
        field_type = 'bigint',
        m = 20,
    },
    num_used = {
        field_type = 'bigint',
        m = 20,
    },
    close_ts = {
        field_type = 'bigint',
        m = 20,
    },
    life_cycle = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_null',
    },
}


_M.shard_fields = {}


local add_column = {
    group_id = true,
    readonly = false,
    ts = true,
    space_used = false,
    num_used = false,
    close_ts = false,
    life_cycle = false,
}

local ident = {
    group_id = true,
}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
        default = {
            readonly = 0,
            space_used = 0,
            num_used = 0,
            close_ts = 0,
            life_cycle = '',
        },
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                readonly=false,
                space_used=false,
                num_used=false,
                ts=false,
                close_ts=false,
                life_cycle=false,
            },
            ident = ident,
        },
    },
    incr = {
        rw = 'w',
        sql_type = 'incr',
        valid_param = {
            column = {
                space_used=false,
                num_used=false,
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
            idx_group_id = {
                'goroup_id',
            },
            idx_readonly_group_id = {
                'readonly', 'goroup_id',
            },
            PRIMARY = {
                '_id',
            },
        },
        valid_param = {
            index_columns = {
                group_id = false,
                readonly = false,
                _id = false,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        default = {
            nlimit = 10,
        },
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
