local time = require('acid.time')
local json = require('acid.json')

local _M = {}


function _M.now()
    local ms, err, errmsg = time.get_ms()
    if err ~= nil then
        return nil, err, errmsg
    end

    return ms / 1000, nil, nil
end


function _M.get_connect_ident_str(host, port)
    return string.format('connect %s %05d: host: %s, port: %s',
                         tostring(ngx.time()),
                         math.random(0, 99999), host, port)
end


function _M.shared_dict_write(shared_dict_name, key, value)
    local shared_dict = ngx.shared[shared_dict_name]
    if shared_dict == nil then
        return nil, 'InvalidSharedDict', string.format(
                'shared dict: %s not exist', shared_dict_name)
    end

    local conf_key = string.format('%s_%d', key, ngx.worker.pid())

    local value_json_str, err = json.enc(value)
    if err ~= nil then
        return nil, 'JsonEncodeError', string.format(
                'failed to json encode when wirte shared dict: %s, %s',
                shared_dict_name, err)
    end

    local ok, err = shared_dict:set(conf_key,
                                    value_json_str)
    if not ok then
        return nil, 'SharedDictSetError', string.format(
                'failed to set key %s to %s: %s',
                conf_key, shared_dict_name, err)
    end
end


function _M.shared_dict_dump(shared_dict_name)
    local shared_dict = ngx.shared[shared_dict_name]
    if shared_dict == nil then
        return nil, 'InvalidSharedDict', string.format(
                'shared dict: %s not exist', shared_dict_name)
    end

    local data = {}

    local keys = shared_dict:get_keys(0)
    for _, key in ipairs(keys) do
        local str_value, err = shared_dict:get(key)
        if err ~= nil then
            return nil, 'SharedDictGetError', string.format(
                    'failed to get %s from %s: %s',
                    key, shared_dict_name, err)
        end

        data[key] = str_value
    end

    return data, nil, nil
end



return _M
