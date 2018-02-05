local strutil = require('acid.strutil')
local upstream_util = require('acid.dbagent.upstream_util')
local mysql = require('resty.mysql')
local util = require('acid.dbagent.util')
local json = require('acid.json')


local to_str = strutil.to_str


local _M = {}

local TRANSACTION_START = 'START TRANSACTION'
local TRANSACTION_ROLLBACK = 'ROLLBACK'
local TRANSACTION_COMMIT = 'COMMIT'


local function close_db(db, connect_ident)
    local ok, err = db:close()
    if not ok then
        ngx.log(ngx.ERR, string.format('failed to close: %s, %s',
                                       connect_ident, err))
    end
end


function _M.single_query_one_try(connection_info, sql)

    -- for call back args
    local query_ctx = {}


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
    local ok, err, errcode, sqlstate = db:connect(options)
    if not ok then
        return nil, 'MysqlConnectError', string.format(
                'failed to connect to: %s, %s, %s, %s, %s',
                options.host, tostring(options.port), err,
                tostring(errcode), sqlstate)
    end

    local connect_ident = util.get_connect_ident_str(options.host,
                                                options.port)

    local res, err, errcode, sqlstate = db:query(sql)
    if err ~= nil then
        close_db(db)
        return nil, 'MysqlQueryError', string.format(
                'failed to query mysql: %s on: %s, error: %s, %s, %s',
                sql, connect_ident, err, errcode, sqlstate)
    end

    ngx.log(ngx.INFO, string.format(
            'query sql: %s, on: %s, res: %s',
            sql, connect_ident, to_str(res)))

    local ok, err = db:set_keepalive(10 * 1000, 100)
    if not ok then
        ngx.log(ngx.ERR, string.format(
                'failed to set mysql keepalive on: %s, %s', err))
    end

    return res, nil, nil
end


local function roll_back(db, connect_ident)
    local res, err, errcode, sqlstate = db:query(TRANSACTION_ROLLBACK)
    if err ~= nil then
        ngx.log(ngx.INFO, string.format(
                'failed to roll back on: %s, error: %s, %s, %s',
                connect_ident, err, errcode, sqlstate))
    end
    ngx.log(ngx.INFO, string.format('roll back on: %s, res: %s',
                                    connect_ident, to_str(res)))

end


local function transaction_query_one_try(connection_info, sqls)
    -- for call back args
    local query_ctx = {}

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
    local connect_ident = util.get_connect_ident_str(options.host,
                                                     options.port)

    local ok, err, errcode, sqlstate = db:connect(options)
    if not ok then
        return nil, 'MysqlConnectError', string.format(
                'failed to connect to: %s, error: %s, %s, %s',
                connect_ident, err, errcode, sqlstate)
    end

    local res, err, errcode, sqlstate = db:query(TRANSACTION_START)
    if err ~= nil then
        close_db()
        return nil, 'MysqlQueryError', string.format(
                'failed to start transaction on: %s, error: %s, %s, %s',
                connect_ident, err, errcode, sqlstate)
    end
    ngx.log(ngx.INFO, string.format('start transaction on: %s, res: %s',
                                    connect_ident, to_str(res)))

    local transaction_res

    for _, sql in ipairs(sqls) do
        local res, err, errcode, sqlstate = db:query(sql)
        if err ~= nil then
            roll_back(db, connect_ident)
            close_db(db, connect_ident)
            return nil, 'MysqlQueryError', string.format(
                    'failed to execute sql: %s on: %s, error: %s, %s, %s',
                    sql, connect_ident, err, errcode, sqlstate)
        end

        ngx.log(ngx.INFO, string.format('execute sql: %s on: %s, res: %s',
                                        sql, connect_ident, err))

        -- to do
        local allow_empty_write = false

        if not allow_empty_write then
            if res.affected_rows == 0 then
                roll_back(db, connect_ident)
                close_db(db, connect_ident)

                return res, nil, nil
            end
        end

        transaction_res = res
    end

    local res, err, errcode, sqlstate = db:query(TRANSACTION_COMMIT)
    if err ~= nil then
        roll_back(db, connect_ident)
        close_db(db, connect_ident)
        return nil, 'MysqlCommitError', string.format(
                'failed to commit on: %s, error: %s, %s, %s',
                connect_ident, err, errcode, sqlstate)
    end

    local ok, err = db:set_keepalive(10 * 1000, 100)
    if not ok then
        ngx.log(ngx.ERR, string.format(
                'failed to set mysql keepalive on: %s, %s', err))
    end

    return transaction_res, nil, nil
end


local function mysql_query(api_ctx)
    api_ctx.tried_connections = {}

    local query_result, err, errmsg

    for i = 1, 3 do
        local connection_name = upstream_util.get_connection(api_ctx)
        local db_connetctions = api_ctx.conf.connections
        local connection_info = db_connetctions[connection_name]

        if #api_ctx.sqls == 1 then
            query_result, err, errmsg = _M.single_query_one_try(
                    connection_info, api_ctx.sqls[1])
        else
            query_result, err, errmsg = transaction_query_one_try(
                    connection_info, api_ctx.sqls)
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
    local query_result, err, errmsg = mysql_query(api_ctx)
    ngx.log(ngx.ERR, 'test-------------' .. to_str({query_result, 'error:', err, errmsg}))
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.result = query_result
    return query_result, nil, nil
end


return _M
