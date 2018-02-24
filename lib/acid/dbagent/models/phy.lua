local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    sha1 = {
        field_type = 'binary',
        m = 20,
    },
    ver = {
        field_type = 'bigint',
        m = 20,
    },
    bucket_id = {
        field_type = 'bigint',
        m = 20,
    },
    scope = {
        field_type = 'varbinary',
        m = 4,
        no_hex = true,
    },
    key = {
        field_type = 'varbinary',
        m = 512,
        no_hex = true,
    },
    ts = {
        field_type = 'bigint',
        m = 20,
    },
    is_del = {
        field_type = 'tinyint',
        m = 4,
    },
    phy_ts = {
        field_type = 'bigint',
        m = 20,
    },
    group_id = {
        field_type = 'bigint',
        m = 20,
    },
    md5 = {
        field_type = 'binary',
        m = 16,
    },
    crc32 = {
        field_type = 'binary',
        m = 4,
    },
    size = {
        field_type = 'bigint',
        m = 20,
        no_string = true,
    },
    origo = {
        field_type = 'binary',
        m = 6,
    },
}


_M.shard_fields = {'sha1'}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.crc32 = false

local ident = {
    sha1=true,
    ver=true,
    bucket_id=true,
    scope=true,
    key=true,
    ts=true,
    is_del=true,
}


_M.actions = {
    add = {
        rw = 'w',
        sql_type = 'add',
        valid_param = {
            column = add_column,
        },
        default = {crc32 = '00000000'},
    },
    set = {
        rw = 'w',
        sql_type = 'set',
        valid_param = {
            column = {
                md5=false,
                group_id=false,
                crc32=false,
                size=false
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
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            idx_sha1_ver_bucket_id_scope_key_ts_is_del = {
                'sha1', 'ver', 'bucket_id', 'scope', 'key', 'ts', 'is_del',
            },
        },
        valid_param = {
            index_columns = {
                sha1=true,
                ver=false,
                bucket_id=false,
                scope=false,
                key=false,
                ts=false,
                is_del=false,
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
