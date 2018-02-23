local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    bucket_id = {
        field_type = 'bigint',
        m = 20,
    },
    bucket= {
        field_type = 'varchar',
        m = 255,
    },
    owner = {
        field_type = 'varchar',
        m = 64,
    },
    acl = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_acl',
    },
    redirect = {
        field_type = 'bigint',
        m = 20,
    },
    relax_upload = {
        field_type = 'tinyint',
        m = 4,
    },
    cors = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_general',
    },
    conf = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_general',
    },
    serversidekey = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_general',
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
    is_del = {
        field_type = 'tinyint',
        m = 4,
    },
    space_used = {
        field_type = 'bigint',
        m = 20,
    },
    num_used = {
        field_type = 'bigint',
        m = 20,
    },
    space_up = {
        field_type = 'bigint',
        m = 20,
    },
    num_up = {
        field_type = 'bigint',
        m = 20,
    },
    space_down = {
        field_type = 'bigint',
        m = 20,
    },
    num_down = {
        field_type = 'bigint',
        m = 20,
    },
    space_del = {
        field_type = 'bigint',
        m = 20,
    },
    num_del = {
        field_type = 'bigint',
        m = 20,
    },
}

_M.shard_fields = {}


local add_column = {
    bucket_id = true,
    bucket = true,
    owner = true,
    acl = false,
    redirect = false,
    relax_upload = false,
    cors = false,
    conf = false,
    serversidekey = false,
    ts = true,
    is_del = false,
    space_used = false,
    num_used = false,
    space_up = false,
    num_up = false,
    space_down = false,
    num_down = false,
}

local link_column = tableutil.dup(add_column, true)
link_column.redirect = true

local add_default = {
    acl = {},
    redirect = 0,
    relax_upload = 1,
    cors = {},
    conf = {},
    serversidekey = {},
    is_del = 0,
    space_used = 0,
    num_used = 0,
    space_up = 0,
    num_up = 0,
    space_down = 0,
    num_down = 0,
}

local link_default = tableutil.dup(add_default, true)
link_default.redirect = nil

local ident = {
    bucket_id = true,
}

_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
        default = add_default,
    },
    link = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = link_column,
        },
        default = link_default,
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                owner = false,
                acl = false,
                relax_upload = false,
                is_del = false,
                cors = false,
                conf = false,
                serversidekey = false,
                ts = false,

            },
            ident = ident,
        },
    },
    incr = {
        rw = 'w',
        sql_type = 'incr',
        valid_param = {
            column = {
                space_used = false,
                num_used = false,
                space_up = false,
                num_up = false,
                space_down = false,
                num_down = false,
                space_del = false,
                num_del = false,
            },
            ident = ident,
        },
    },
    markdel = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                is_del = false,
            },
            ident = ident,
        },
        default = { is_del = 1 },
    },
    undel = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                is_del = false,
            },
            ident = ident,
        },
        default = { is_del = 0 },
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
            ident = {
                bucket = true,
            },
            match = {
                _is_del = false,
            },
        },
        default = { is_del = 0 },
        unpack_list = true,
        select_column = tableutil.keys(_M.fields),
    },
    getbyid = {
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
            idx_bucket_id = {
                'bucket_id',
            },
            idx_bucket = {
                'bucket',
            },
            idx_owner_bucket = {
                'owner', 'bucket',
            },
            PRIMARY = {
                '_id',
            },
        },
        valid_param = {
            index_columns = {
                bucket_id = false,
                bucket = false,
                owner = false,
                _id = false,
            },
            match = {
                _is_del = false,
                _redirect = false,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        default = { nlimit = 1024 * 1024 },
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
