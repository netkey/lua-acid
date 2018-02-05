local httpclient = require('acid.httpclient')
local aws_signer = require('resty.awsauth.aws_signer')
local acid_json = require('acid.json')
local tableutil = require('acid.tableutil')


local _M = { _VERSION = '0.0.1' }

local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local setmetatable = setmetatable
local string_format = string.format
local table_concat = table.concat
local table_insert = table.insert

local mt = { __index = _M }


function _M.new(core_ips, port, access_key, secret_key, opts)
    if type(core_ips) ~= 'table' or type(core_ips[1]) ~= 'string' then
        return nil, 'InvalidArgument', 'invalid core ips'
    end
    opts = opts or {}

    local timeout = opts.timeout or 1000
    local timeout_ratio = opts.timeout_ratio or 1.5
    local retry_sleep = opts.retry_sleep or 0.01
    local user_agent = opts.user_agent or 'unknown-user-agent'
    local ignore = opts.ignore == true
    local signer, err, msg = aws_signer.new(access_key,
                                            secret_key,
                                            {default_expires = 10})
    if err ~= nil then
        return nil, err, msg
    end

    return setmetatable({
        core_ips = core_ips,
        port = port,
        ignore = ignore,
        signer = signer,
        sess = {},

        timeout = timeout,
        timeout_ratio = timeout_ratio,
        retry_sleep = retry_sleep,
        user_agent = user_agent,
    }, mt), nil, nil
end


function _M.request_one_ip(self, core_ip, port, timeout, core2_request)
    local http = httpclient:new(core_ip, port, timeout,
                            {service_key = 'core'})
    local core2_request_copy = tableutil.dup(core2_request, true)
    core2_request_copy.headers.Host = core_ip
    local auth_ctx, err, msg = self.signer:add_auth_v4(core2_request_copy,
                                                       {sign_payload = true})
    if err ~= nil then
        return nil, err, 'failed to add auth v4: ' .. msg
    end

    local _, err, msg = http:request(core2_request_copy.uri,
                                  {method = core2_request_copy.verb,
                                   headers = core2_request_copy.headers,
                                   body = core2_request_copy.body})
    if err ~= nil then
        return nil, err, string_format('failed to request core ip %s, %s',
                                       core_ip, msg)
    end

    local body = {}
    while true do
        local buf, err, msg = http:read_body(1024*1024*10)
        if err ~= nil then
            return nil, err, 'failed to read body: ' .. msg
        end

        if buf == '' then
            break
        end

        table_insert(body, buf)
    end

    local resp_body = table_concat(body)

    if http.status ~= 200 then
        return nil, 'InvalidResponse',
                string_format('response from %s is invalid, code: %s, body: %s',
                              core_ip, tostring(http.status), resp_body)
    end

     if http.headers['connection'] == 'keep-alive' then
         http:set_keepalive(30*1000, 16)
     end

    return {body = resp_body, headers = http.headers}, nil, nil
end


function _M.do_request(self, core2_request)
    local resp, err, msg

    local port = self.port
    local timeout = self.timeout
    local timeout_ratio = self.timeout_ratio

    for _, core_ip in ipairs(self.core_ips) do
        resp, err, msg = self:request_one_ip(core_ip, port, timeout, core2_request)
        if err == nil then
            return resp, nil, nil
        end

        ngx.log(ngx.WARN, string_format(
                'failed to request core ip %s: %s, %s',
                core_ip, err, msg))

        if self.retry_sleep > 0 then
            ngx.sleep(self.retry_sleep)
        end

        if timeout ~= nil then
            timeout = timeout * timeout_ratio
        end
    end

    return nil, err, msg
end


local function parse_response_body(response_body, ignore)
    local result, err_msg = acid_json.dec(response_body)
    if err_msg ~= nil then
        return nil, 'InvalidResponse',
                string_format('failed to decode response body: %s', err_msg)
    end

    if result.error_code ~= nil then
        return nil, 'OperationalError', response_body
    end

    if true then
        return result
    end

    result = result.value

    if result == nil then
        return result, nil, nil
    end

    if result.affected_rows == 0 and ignore == false then
        return nil, 'WriteIgnored', response_body
    end

    return result, nil, nil
end


local function load_shard(self, headers)
    local shard = {
        ['shard-current']= headers['x-s2-shard-current'],
        ['shard-next']= headers['x-s2-shard-next'],
    }

    for s, v in pairs(shard) do
        local v, err_msg = acid_json.dec(v)
        if err_msg == nil then
            self.sess[s] = v
        else
            ngx.log(ngx.ERR, string_format(
                    'failed to decode header %s: %s', s, err_msg))
        end
    end
end


function _M.req(self, subject, action, params, opts)
    opts = opts or {}

    local core2_request = {
        verb = 'POST',
        uri = '/api/' .. subject .. '/' .. action,
        args = {},
        headers = {
            Host = '',
            ['Content-Length'] = 0,
            ['User-Agent'] = self.user_agent,
        },
        body = '',
    }

    core2_request.body = acid_json.enc(params)
    core2_request.headers['Content-Length'] = #core2_request.body

    local resp, err, msg = self:do_request(core2_request)
    if err ~= nil then
        ngx.log(ngx.ERR, string_format('failed to request core2: %s, %s',
                                       err, msg))
        return nil, err, msg
    end

    local ignore = opts.ignore or self.ignore
    local result, err, msg = parse_response_body(resp.body, ignore)
    if err ~= nil then
        ngx.log(ngx.ERR, string_format('failed to parse response: %s, %s',
                                       err, msg))
        return nil, err, msg
    end

    load_shard(self, resp.headers)

    return result, nil, nil
end


return _M
