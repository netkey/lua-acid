local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    username = {
        field_type = 'varchar',
        m = 64,
    },
    info = {
        field_type = 'text',
        m = nil,
    },
    email = {
        field_type = 'varchar',
        m = 64,
    },
    password = {
        field_type = 'binary',
        m = 16,
    },
    salt = {
        field_type = 'varchar',
        m = 40,
    },
    company = {
        field_type = 'varchar',
        m = 64,
    },
    max_nr_project = {
        field_type = 'bigint',
        m = 20,
    },
    limiation = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_to_table',
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


local ident = { username = true }


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
                email=false,
                password=false,
                salt=false,
                company=false,
                limitation=false,
                max_nr_project=false,
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
        unpack_list = true,
        select_column = tableutil.keys(_M.fields),
    },
    login = {
        rw = 'r',
        sql_type = 'get',
        valid_param = {
            ident = {
                email = true,
            },
        },
        unpack_list = true,
        select_column = tableutil.keys(_M.fields),
    },
    ls = {
        rw = 'r',
        indexes = {
            idx_username= {
                'username',
            },
            idx_email = {
                'email',
            },
            PRIMARY = {
                '_id',
            },
        },
        valid_param = {
            index_columns = {
                username = false,
                email = false,
                _id = false,
            },
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        default = { nlimit = 1 },
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
