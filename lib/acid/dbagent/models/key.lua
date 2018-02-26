local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
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
    owner = {
        field_type = 'varchar',
        m = 64,
    },
    acl = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_acl',
    },
    sha1 = {
        field_type = 'binary',
        m = 20,
    },
    ver = {
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
    file_meta = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_table',
    },
    group_id = {
        field_type = 'bigint',
        m = 20,
    },
    origo = {
        field_type = 'binary',
        m = 6,
    },
    expires = {
        field_type = 'bigint',
        m = 20,
    },
    multipart = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_general',
    },
}


_M.shard_fields = {
    'bucket_id',
    'scope',
    'key',
}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end
add_column.multipart = false
add_column.crc32 = false

local ident = {
    bucket_id = true,
    scope = true,
    key = true,
    ts = false,
}

local match = {
    _sha1=false,
    _ver=false,
	_size=false,
	_ts=false,
	_group_id=false,
	_is_del=false,
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
                acl = false,
                file_meta = false,
                expires = false,
                multipart = false,
            },
            ident = ident,
            match = match,
        },
    },
    replace = {
        rw = 'w',
        sql_type = 'replace',
        valid_param = {
            column = add_column,
            match = {
                _bucket_id = true,
                _scope = true,
                _key = true,
                _ts = true,
            },
        },
        default = {crc32 = '00000000'},
    },
    remove = {
        rw = 'w',
        sql_type = 'remove',
        valid_param = {
            ident = ident,
            match = match,
        },
    },
    get = {
        rw = 'r',
        sql_type = 'get',
        valid_param = {
            ident = ident,
            match = match,
        },
        select_column = tableutil.keys(_M.fields),
        unpack_list = true,
    },
    wget = {
        rw = 'w',
        sql_type = 'get',
        valid_param = {
            ident = ident,
            match = match,
        },
        select_column = tableutil.keys(_M.fields),
        unpack_list = true,
    },
    ls = {
        rw = 'r',
        sql_type = 'indexed_ls',
        indexes = {
            idx_bucket_id_scope_key_ts = {
                'bucket_id', 'scope', 'key', 'ts',
            },
            PRIMARY = {
                '_id',
            },
        },
        valid_param = {
            index_columns = {
                bucket_id = false,
                scope = false,
                key = false,
                ts = false,
                _id = false,
            },
            match = match,
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        query_opts = {
            timeout = 3000,
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
