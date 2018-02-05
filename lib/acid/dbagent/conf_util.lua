--local etcd_client = require('acid.etcd_client')
local ngx_timer = require('ngx_timer')
local json = require('acid.json')
local tableutil = require('acid.tableutil')
local util = require('acid.dbagent.util')


local _M = {}

_M.conf = nil


--function _M.get_conf_from_etcd(curr_version)
    --local conf = {}
    --_M.etcd_modified_index = nil
    --local hosts, err, errmsg = conf.get_etcd_host()
    --if err ~= nil then
        --ngx.log(ngx.ERR, string.format('failed to get etcd host: %s, %s',
                                       --err, errmsg))
        --return nil, err, errmsg
    --end

    --local client, err, errmsg = etcd_client.new(
            --hosts, {basic_auth_account=conf.etcd_account})
    --if err ~= nil then
        --ngx.log(ngx.ERR, string.format('failed to new etcd client: %s, %s',
                                       --err, errmsg))
        --return nil, err, errmsg
    --end

    --local wait_index = 0
    --if _M.etcd_modified_index ~= nil then
        --wait_index = _M.etcd_modified_index + 1
    --end

    --local result, err, errmsg = client:watch(conf.etcd_shard_conf_key,
                                             --{waitIndex=wait_index},
                                             --{timeout=conf.etcd_watch_timeout})
    --if err ~= nil then
        --if err ~= 'TimeoutError' then
            --ngx.log(ngx.ERR, string.format('failed to watch: %s',
                                           --conf.etcd_shard_conf_key, err, errmsg))
        --end
        --return nil, err, errmsg
    --end

    --local value = result.data.node.value
    --local modified_index = result.data.node.modifiedIndex

    --local shard_conf, err = json.dec(value)
    --if err ~= nil then
        --ngx.log(ngx.ERR, string.format(
                --'shard conf in etcd is not invalid json: %s', err))
        --return nil, 'InternalError', 'shard conf in etcd is invalid'
    --end

    --local _, err, errmsg = check_shard_conf(shard_conf)
    --if err ~= nil then
        --ngx.log(ngx.ERR, string.format(
                --'check shard conf failed: %s, %s', err, errmsg))
        --return nil, 'InternalError', 'check shard conf failed'
    --end

    --_M.shard_conf = shard_conf
    --_M.etcd_modified_index = modified_index

    --ngx.log(ngx.INFO, string.format(
            --'at time: %s, update shard conf to index: %d',
            --tostring(ngx.time()), _M.etcd_modified_index))

    --if err ~= nil then
        --ngx.log(ngx.ERR, string.format(
                --'failed to write shard conf to shared dict: %s, %s',
                --err, errmsg))
    --end
    --return true, nil, nil
--end


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
