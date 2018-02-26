local httpclient = require('acid.httpclient')
local aws_signer = require('resty.awsauth.aws_signer')
local acid_json = require('acid.json')
local tableutil = require('acid.tableutil')
local strutil = require('acid.strutil')

local to_str = strutil.to_str


local _M = { _VERSION = '0.0.1' }

local mt = { __index = _M }


function _M.new(dbagent_ips, port, access_key, secret_key, opts)
    if type(dbagent_ips) ~= 'table' or type(dbagent_ips[1]) ~= 'string' then
        return nil, 'InvaliddbgentIps', string.format(
                'invalid dbagent ips: %s', to_str(dbagent_ips))
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
        dbagent_ips = dbagent_ips,
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


function _M.raw_request(opts)
    if opts == nil then
        opts = {}
    end

    local timeout = opts.timeout or 1000
    local uri = opts.uri or string.format('/api/%s/%s',
                                          opts.subject, opts.action)
    local headers = opts.headers or {}
    local body = opts.body or ''

    local ip = opts.ip or '127.0.0.1'
    local port = opts.port or 7011

    local http = httpclient:new(ip, port, timeout,
                                {service_key = 'dbagent'})

    local _, err, errmsg = http:request(uri,
                                        {method = 'POST',
                                         headers = headers,
                                         body = body})
    if err ~= nil then
        return nil, 'HttpRequestError', string.format(
                'failed to request ip: %s, %s, %s', ip, err, errmsg)
    end

    local bufs = {}
    while true do
        local buf, err, errmsg = http:read_body(1024*1024*10)
        if err ~= nil then
            return nil, 'ReadBodyError', string.format(
                    'failed to read body: %s, %s', err, errmsg)
        end

        if buf == '' then
            break
        end

        table.insert(bufs, buf)
    end

    local resp_body = table.concat(bufs)

    if http.status ~= 200 then
        return nil, 'InvalidResponse',
                string.format('response from %s is invalid, code: %s, body: %s',
                              ip, tostring(http.status), resp_body)
    end

    if http.headers['connection'] == 'keep-alive' then
        http:set_keepalive(30*1000, 16)
    end

    return {body = resp_body, headers = http.headers}, nil, nil
end


function _M.request_one_ip(self, dbagent_ip, port, timeout, dbagent_request)
    local dbagent_request_copy = tableutil.dup(dbagent_request, true)
    dbagent_request_copy.headers.Host = dbagent_ip

    local _, err, errmsg = self.signer:add_auth_v4(
            dbagent_request_copy, {sign_payload = true})
    if err ~= nil then
        return nil, 'AddAuthError', string.format(
                'failed to add auth v4: %s, %s', err, errmsg)
    end

    local opts = {
        ip = dbagent_ip,
        port = port,
        timeout = timeout,
        uri = dbagent_request_copy.uri,
        headers = dbagent_request_copy.headers,
        body = dbagent_request_copy.body
    }
    local resp, err, errmsg = _M.raw_request(opts)
    if err ~= nil then
        return nil, err, errmsg
    end

    return resp, nil, nil
end


function _M.do_request(self, dbagent_request)
    local resp, err, msg

    local port = self.port
    local timeout = self.timeout
    local timeout_ratio = self.timeout_ratio

    for _, dbagent_ip in ipairs(self.dbagent_ips) do
        resp, err, msg = self:request_one_ip(dbagent_ip, port, timeout,
                                             dbagent_request)
        if err == nil then
            return resp, nil, nil
        end

        ngx.log(ngx.WARN, string.format(
                'failed to request dbagent ip %s: %s, %s',
                dbagent_ip, err, msg))

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
                string.format('failed to decode response body: %s', err_msg)
    end

    if result.error_code ~= nil then
        return nil, 'OperationError', response_body
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
        ['shard-current'] = headers['x-s2-shard-current'],
        ['shard-next'] = headers['x-s2-shard-next'],
    }

    for name, str_value in pairs(shard) do
        local value, err = acid_json.dec(str_value)
        if err ~= nil then
            return nil, 'JsonDecodeError', string.format(
                    'failed to decode shard header %s, %s: %s',
                    name, str_value, err)
        else
            self.sess[name] = value
        end
    end
end


function _M.req(self, subject, action, params, opts)
    opts = opts or {}

    local dbagent_request = {
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

    dbagent_request.body = acid_json.enc(params)
    dbagent_request.headers['Content-Length'] = #dbagent_request.body

    local resp, err, errmsg = self:do_request(dbagent_request)
    if err ~= nil then
        return nil, 'DoRequestError', string.format(
                'failed to request dbagent: %s, %s', err, errmsg)
    end

    local ignore = opts.ignore or self.ignore
    local result, err, errmsg = parse_response_body(resp.body, ignore)
    if err ~= nil then
        return nil, 'ParseResponseBodyError', string.format(
                'failed to parse response body: %s, %s', err, errmsg)
    end

    local _, err, errmsg = load_shard(self, resp.headers)
    if err ~= nil then
        return nil, 'LoadShardError', string.format(
                'failed to load shard: %s, %s', err, errmsg)
    end

    return result, nil, nil
end


return _M
