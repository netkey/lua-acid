local strutil = require('acid.strutil')
local upstream_util = require('acid.dbagent.upstream_util')
local mysql = require('resty.mysql')
local util = require('acid.dbagent.util')
local json = require('acid.json')
local tableutil = require('acid.tableutil')
local repr = tableutil.repr
local cjson = require('cjson')

local to_str = strutil.to_str


local _M = {}

local TRANSACTION_START = 'START TRANSACTION'
local TRANSACTION_ROLLBACK = 'ROLLBACK'
local TRANSACTION_COMMIT = 'COMMIT'


function _M.connect_db(connection_info, callbacks)
    local db, err = mysql:new()
    if not db then
        return nil, 'MysqlNewError', string.format(
                'failed to new mysql: %s', err)
    end

    db:set_timeout(1000) -- 1 second

    local options = {
        host = connection_info.host,
        port = connection_info.port,
        database = connection_info.database,
        user = connection_info.user,
        password = connection_info.password,

        -- use default
        charset = nil,
        max_packet_size = nil,
        ssl_verify = nil,
    }

    if callbacks.before_connect_db ~= nil then
        callbacks.before_connect(connection_info)
    end

    local ok, err, errcode, sqlstate = db:connect(options)

    if callbacks.after_connect_db ~= nil then
        callbacks.after_connect_db(connection_info)
    end

    if not ok then
        local error_code = 'MysqlConnectError'
        local error_message = string.format(
                'failed to connect to: %s, %s, %s, %s, %s',
                options.host, tostring(options.port), err,
                tostring(errcode), sqlstate)

        if callbacks.connect_db_error ~= nil then
            callbacks.connect_db_error(error_code, error_message)
        end

        return nil, error_code, error_message
    end

    local ident = util.get_connect_ident_str(options.host,
                                             options.port)

    return {db=db, ident=ident}, nil, nil
end


local function close_db(connect)
    local ok, err = connect.db:close()
    if not ok then
        ngx.log(ngx.ERR, string.format('failed to close: %s, %s',
                                       connect.ident, err))
    end
end


function _M.db_query(connect, sql, callbacks)
    if callbacks.before_query_db ~= nil then
        callbacks.before_query_db(sql)
    end

    local query_result, err, errcode, sqlstate = connect.db:query(sql)

    if callbacks.after_query_db ~= nil then
        callbacks.after_query_db(query_result)
    end

    if err ~= nil then
        close_db(connect)

        local error_code = 'MysqlQueryError'
        local error_message = string.format(
                'failed to query mysql: %s on: %s, error: %s, %s, %s',
                sql, connect.ident, err, errcode, sqlstate)

        if callbacks.query_db_error ~= nil then
            callbacks.query_db_error(error_code, error_message)
        end

        return nil, error_code, error_message
    end

    ngx.log(ngx.INFO, string.format(
            'query sql: %s, on: %s, query result: %s',
            sql, connect.ident, to_str(query_result)))

    return query_result, nil, nil
end


function _M.single_query_one_try(connection_info, sql, callbacks)
    local connect, err, errmsg = _M.connect_db(connection_info, callbacks)
    if err ~= nil then
        return nil, err, errmsg
    end

    local query_result, err, errmsg = _M.db_query(connect, sql, callbacks)
    if err ~= nil then
        return nil, err, errmsg
    end

    local ok, err = connect.db:set_keepalive(10 * 1000, 100)
    if not ok then
        ngx.log(ngx.ERR, string.format(
                'failed to set mysql keepalive on: %s, %s',
                connect.ident, err))
    end

    return query_result, nil, nil
end


local function roll_back(connect, callbacks)
    local query_result, err, errmsg = _M.db_query(
            connect, TRANSACTION_ROLLBACK, callbacks)
    if err ~= nil then
        ngx.log(ngx.INFO, string.format(
                'failed to roll back on: %s, %s, %s',
                connect.ident, err, errmsg))
    end
    ngx.log(ngx.INFO, string.format('roll back on: %s, result: %s',
                                    connect.ident, to_str(query_result)))
end


local function transaction_query_one_try(connection_info,
                                         sqls, sqls_opts, callbacks)
    if sqls_opts == nil then
        sqls_opts = {}
    end

    local connect, err, errmsg = _M.connect_db(connection_info, callbacks)
    if err ~= nil then
        return nil, err, errmsg
    end

    local query_result, err, errmsg = _M.db_query(connect,
                                                  TRANSACTION_START, callbacks)
    if err ~= nil then
        return nil, 'StartTransactionError', string.format(
                'failed to start transaction: %s, %s', err, errmsg)
    end

    ngx.log(ngx.INFO, string.format('start transaction on: %s, result: %s',
                                    connect.ident, to_str(query_result)))

    local transaction_result = {}

    for i, sql in ipairs(sqls) do
        local query_result, err, errmsg = _M.db_query(connect, sql, callbacks)
        if err ~= nil then
            return nil, err, errmsg
        end

        table.insert(transaction_result, query_result)
        ngx.log(ngx.INFO, string.format('execute sql: %s on: %s, result: %s',
                                        sql, connect.ident, query_result))

        local sql_opts = sqls_opts[i] or {}

        if not sql_opts.allow_empty_write then
            if query_result.affected_rows == 0 then
                roll_back(connect, callbacks)
                close_db(connect)

                return nil, 'EmptyWriteError', string.format(
                        'execute of sql: %s affected 0 row', sql)
            end
        end
    end

    local query_result, err, errmsg = _M.db_query(
            connect, TRANSACTION_COMMIT, callbacks)
    if err ~= nil then
        roll_back(connect, callbacks)
        close_db(connect)
        return nil, 'CommitTransactionError', string.format(
                'failed to commit transaction: %s, %s', err, errmsg)
    end

    ngx.log(ngx.INFO, string.format('commited transaction on: %s, result: %s',
                                    connect.ident, to_str(query_result)))

    local ok, err = connect.db:set_keepalive(10 * 1000, 100)
    if not ok then
        ngx.log(ngx.ERR, string.format(
                'failed to set mysql keepalive on: %s, %s',
                connect.ident, err))
    end

    return transaction_result[#transaction_result], nil, nil
end


local function mysql_query(api_ctx, callbacks)
    api_ctx.tried_connections = {}

    local query_result, err, errmsg

    for _ = 1, 3 do
        local connection_name = upstream_util.get_connection(api_ctx)
        local db_connetctions = api_ctx.conf.connections
        local connection_info = db_connetctions[connection_name]

        if #api_ctx.sqls == 1 then
            query_result, err, errmsg = _M.single_query_one_try(
                    connection_info, api_ctx.sqls[1], callbacks)
        else
            query_result, err, errmsg = transaction_query_one_try(
                    connection_info, api_ctx.sqls,
                    api_ctx.sqls_opts, callbacks)
        end

        table.insert(api_ctx.tried_connections, {
            connection_name = connection_name,
            query_result = query_result,
            error_code = err,
            error_message = errmsg,
        })

        if err == nil then
            return query_result, nil, nil
        end
    end

    return nil, err, errmsg
end


function _M.do_query(api_ctx)
    local callbacks = api_ctx.opts.callbacks or {}
    local query_result, err, errmsg = mysql_query(api_ctx, callbacks)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.query_result = query_result
    return query_result, nil, nil
end


return _M
