--local etcd_client = require('acid.etcd_client')
local ngx_timer = require('ngx_timer')
local json = require('acid.json')
local tableutil = require('acid.tableutil')
local util = require('acid.dbagent.util')


local _M = {}

_M.conf = nil


local function get_conf_safe(get_conf)
    local curr_version = (_M.conf or {}).version

    ngx.log(ngx.INFO, string.format(
            'worker %d start to get conf whit curr version: %s',
            ngx.worker.id(), tostring(curr_version)))

    local ok, err_or_conf, err, errmsg = pcall(get_conf, curr_version)
    if not ok then
        ngx.log(ngx.ERR, string.format('faied to run callback get_conf: %s',
                                       err_or_conf))
        return false, nil, nil
    end

    if err ~= nil then
        ngx.log(ngx.ERR, string.format('faied to get conf: %s, %s',
                                       err, errmsg))
        return false, nil, nil
    end

    _M.conf = err_or_conf

    return _M.conf, nil, nil
end


local function init_conf_update(get_conf)
    local _, err, errmsg = ngx_timer.loop_work(0.1, get_conf_safe, get_conf)
    if err ~= nil then
        ngx.log(ngx.ERR, 'failed to init ngx timer')
        return nil, err, errmsg
    end
    return true, nil, nil
end


function _M.init_conf(get_conf)
    get_conf_safe(get_conf)
    init_conf_update(get_conf)
end


return _M
