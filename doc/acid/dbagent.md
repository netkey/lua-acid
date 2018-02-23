<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
#   Table of Content

- [Name](#name)
- [Status](#status)
- [Description](#description)
- [Synopsis](#synopsis)
- [Methods](#methods)
  - [init.init](#initinit)
  - [api.do_api](#apido_api)
- [Author](#author)
- [Copyright and License](#copyright-and-license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

#   Name

acid.dbagent

#   Status

This library is considered production ready.

#   Description

This library provides easy access to mysql.

#   Synopsis

```lua
init_worker_by_lua_block {
    local dbagnet_init = require('acid.dbagent.init')

    local function get_conf(curr_version)
	    if curr_version ~= nil then
			ngx.sleep(5)
		end

		local value = {
			connections = {
				['3500-1'] = {
					database = 'test-database',
					host = '127.0.0.1',
					port = 3500,
					user = 'user_name',
					password = '123456'
				},
			},

			tables = {
				key = {
					{
						from = {'1000000000000000000', '', ''},
						db = '3500',
					},
				},
			},

			dbs = {
				['3500'] = {
					r = {
						'3500-1',
					},
					w = {
						'3500-1',
					},
				},
			},
		}

		local conf = {
			version = 1,
			value = value,
		}

		return conf
    end

    local opts = {
        model_module_dir = '/path/to/dir',
        get_conf = get_conf,
    }

    dbagent_init.init(opts)
}

rewrite_by_lua_block {
    local dbagent_api = require('acid.dbagent.api')

	local function before_connect_db(connection_info)
		ngx.log(ngx.INFO, string.format('about to connect to %s:%d',
										connection_info.host,
										connection_info.port))
	end

	local function on_error(error_code, error_message)
		ngx.log(ngx.ERR, string.format('%s:%s', error_code, error_messge))
	end

	local function before_query_db(sql)
		ngx.log(ngx.INFO, 'about to query: ' .. sql)
	end

	local function after_query_db(query_result)
		ngx.log(ngx.INFO, 'query result: ' .. tostring(query_result))
	end

	local callbacks = {
		before_connect_db = before_connect_db,
		connect_db_error = on_error,
		before_query_db = before_query_db,
		after_query_db = after_query_db,
		query_db_error = on_error,
	}

    dbagent_api.do_api({callbacks=callbacks})
}
```

#   Methods

## init.init

**syntax**:
`init(opts)`

Load model modules and setup a timer to update conf immediately when
the conf changes.

**arguments**:

-   `opts`:
    is a table contains any of the following fields.

    -   `model_module_dir`: the directory where model modules located.
        For example, if the model module file is
        '/path/to/dir/models/bucket.lua', then set `model_module_dir`
        to '/path/to/dir'.

    -   `get_conf`: a callback function, syntax is
        `conf, err, errmsg = get_conf(curr_version)`, curr_version is
        the current used version of conf, this function should return
        only when conf changed or `curr_version` is `nil`, the returned
        `conf` should contain two fields, 'value` and 'version'.


**return**:
nothing

##  api.do_api

**syntax**:
`do_api(opts)`

**arguments**:

-   `opts`:
    is a table contains any of the following fields.

    -   `callbacks`: a table contains following callback functions:

        - `before_connect_db`: called just before connecting mysql,
           the argument is a table contains 'host' and 'port' of the
           mysql about to connect.

        - `after_connect_db`: called when connected mysql,
           the argument is the same as `before_connect_db`.

        - `connect_db_error`: called when failed to connect mysql,
           the argument is the 'error_code' and 'error_messge'.

        - `before_query_db`: called just before querying msyql,
           the argument is the 'sql' about to query.

        - `after_query_db`: called when finished to query msyql,
           the argument is the query result returned by `ngx.mysql`.

        - `query_db_error`: called when failed to query msyql,
           the argument is the same as `connect_db_error`.

**return**:
this function do not return.

#   Model

In order to use this module to access a mysql table, you need to provide
a model module for each table, following is an example.

```lua
local tableutil = require('acid.tableutil')


local _M = {}


_M.fields = {
    a = {
        field_type = 'bigint',
        m = 20,
    },
    b = {
        field_type = 'varbinary',
        m = 4,
        no_hex = true,
    },
    c = {
        field_type = 'varbinary',
        m = 512,
        no_hex = true,
    },
    d = {
        field_type = 'bigint',
        m = 20,
    },
    e = {
        field_type = 'tinyint',
        m = 4,
    },
    f = {
        field_type = 'binary',
        m = 16,
    },
    g = {
        field_type = 'text',
        m = nil,
        convert_method = 'json_null_or_empty_to_table',
    },
}


_M.shard_fields = {
    'a',
    'b',
    'c',
}


local add_column = {}
for field_name, _ in pairs(_M.fields) do
    add_column[field_name] = true
end

local ident = {
    a = true,
    b = true,
    c = true,
    d = false,
}

local match = {
    _e = false,
    _f = false,
}

_M.actions = {
    add = {
        rw = 'w',
        valid_param = {
            column = add_column,
        },
        default = {g = '{}'},
    },
    set = {
        rw = 'w',
        valid_param = {
            column = {
                e = false,
                f = false,
            },
            ident = ident,
            match = match,
        },
    },
    remove = {
        rw = 'w',
        valid_param = {
            ident = ident,
            match = match,
        },
    },
    get = {
        rw = 'r',
        valid_param = {
            ident = ident,
            match = match,
        },
        select_column = tableutil.keys(_M.fields),
        unpack_list = true,
    },
    ls = {
        rw = 'r',
        indexes = {
            idx_a_b_c_d = {
                'a', 'b', 'c', 'd',
            },
        },
        valid_param = {
            index_columns = {
                a = true,
                b = true,
                c = true,
                d = false,
            },
            match = match,
            extra = {
                leftopen = false,
                nlimit = false,
            },
        },
        select_column = tableutil.keys(_M.fields),
    },
}


return _M
```

## fields

Set the attributes of each field in a database table.

### field_type

Set the type of the field, such as 'bigint', 'varbinary' and so on.

### m

The length or display width of the field, used to check the input argument.

### no_hex
By default, 'varbinary' and 'binary' fields will be set and read in
hex format, if this is not expected, set `no_hex` to `true`.

### convert_method
If you use a string field to save some struct value, such as a dict,
you can specify a convert method to convert a struct to and from a string.

## shard_fields

The fields used to do table sharding.

## actions

The supported operations on a database table.

### valid_param

The fields allowed to include in the request arguments.
Value `true` mean field must be exist in arguments, `false`
mean it can be missing.

#### valid_param.column

The fields to set, the argument value in request is the new value of
that field.

#### valid_param.ident

The fields are used to identify the records that you are insterested in.

#### valid_para.match

Fields used to restrict the operation, only records with fields value
equal to value specified in request are operated on or returned.

#### valid_param.index_columns

All index fields.

#### valid_param.extra

Some extra parameters, such as 'leftopen', 'nlimit'.

### rw

Specify operation type of the action, 'r' for read and 'w' for write.

### indexes

Specify the indexes can be used.

### default

Specify default value for some fields.

### select_column

Specify the clomuns to return if the the atction is a read operation.

### query_opts

Specify options used when query msyql database, such as 'timeout'.

#### query_opts.timeout

#   Conf

The conf tells a teble located in which database and how to connect to
each database.

## tables

Specify the sharding infomation of each table.

## dbs

Specify all possible access point for each database

## connections

Specify connection infomation of each access point, such as ip address,
port, password, and so on.

#### database

The database name.

#### host

The ip address of the database instance.

#### port

The port of the database instance.

#### user

The user name used to access the database.

#### password

The password used to access the database.

#   Author

Renzhi (任稚) <zhi.ren@baishancloud.com>

#   Copyright and License

The MIT License (MIT)

Copyright (c) 2015 Renzhi (任稚) <zhi.ren@baishancloud.com>
