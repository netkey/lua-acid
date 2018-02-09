local util = require('acid.dbagent.util')
--local statistic = require('acid.dbagent.statistic')
local author = require('acid.dbagent.author')
local api_util = require('acid.dbagent.api_util')
local sql_util = require('acid.dbagent.sql_util')
local mysql_util = require('acid.dbagent.mysql_util')
local model_module = require('acid.dbagent.model_module')
local arg_util = require('acid.dbagent.arg_util')
local upstream_util = require('acid.dbagent.upstream_util')
local tableutil = require('acid.tableutil')
local convertor = require('acid.dbagent.convertor')
local repr = tableutil.repr


local _M = {}


local function _do_api(api_ctx)
    local now, err, errmsg = util.now()
    if err ~= nil then
        return 'InternalError', string.format(
                'failed to get time: %s, %s', err, errmsg)
    end
    api_ctx.start_time = now

    --local auth_info, err, errmsg = author.do_auth()
    --if err ~= nil then
        --return nil, err, errmsg
    --end
    --api_ctx.auth_info = auth_info


    local _, err, errmsg = api_util.extract_request_info(api_ctx)
    if err ~= nil then
        return nil, 'ExtractError', string.format(
                'failed to extract request info: %s, %s', err, errmsg)
    end

    local _, err, errmsg = model_module.pick_model(api_ctx)
    if err ~= nil then
        return nil, 'PickModelError', string.format(
                'failed to pick model: %s, %s', err, errmsg)
    end

    local _, err, errmsg = arg_util.set_default(api_ctx)
    if err ~= nil then
        return nil, 'SetDefaultError', string.format(
                'failed to set default: %s, %s', err, errmsg)
    end

    local _, err, errmsg = arg_util.check(api_ctx)
    if err ~= nil then
        return nil, 'CheckArgumentError', string.format(
                'failed to check argument: %s, %s', err, errmsg)
    end

    local _, err, errmsg = convertor.convert_arg(api_ctx)
    if err ~= nil then
        return nil, 'ConvertArgumentError', string.format(
                'failed to convert argument: %s, %s', err, errmsg)
    end

    local _, err, errmsg = upstream_util.get_upstream(api_ctx)
    if err ~= nil then
        return nil, 'GetUpstreamError', string.format(
                'failed to get upstream: %s, %s', err, errmsg)
    end

    local _, err, errmsg = sql_util.make_sqls(api_ctx)
    if err ~= nil then
        return nil, 'MakeSqlError', string.format(
                'failed to make sql: %s, %s', err, errmsg)
    end

    local _, err, errmsg = mysql_util.do_query(api_ctx)
    if err ~= nil then
        return nil, 'DoQueryError', string.format(
                'failed to do query: %s, %s', err, errmsg)
    end

    local resp_value, err, errmsg = api_util.make_resp_value(api_ctx)
    if err ~= nil then
        return nil, 'MakeRespValueError', string.format(
                'failed to make resp value: %s, %s', err, errmsg)
    end

    return resp_value, nil, nil
end


function _M.do_api()
    ngx.ctx.api = {
        start_time = util.now(),
    }

    local api_ctx = ngx.ctx.api

    local resp

    local resp_value, err, errmsg = _do_api(api_ctx)
    if err ~= nil then
        resp = {error_code = err, error_message = errmsg}
    else
        resp = {value = resp_value}
    end

    ngx.log(ngx.ERR, 'test---------' .. repr({resp_value, err, errmsg}))

    api_util.output_json(resp)
end


return _M
