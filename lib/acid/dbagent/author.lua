local aws_authenticator = require('resty.awsauth.aws_authenticator')

local access_key = 'ijfiewf'
local secret_key = 'ijfiewajf'

local _M = {}


local function get_secret_key(ctx)
    if ctx.access_key == access_key then
        return secret_key, nil, nil
    end

    return nil, 'InvalidAccessKeyId',
            'the access key does not exists: ' .. ctx.access_key
end


local function get_bucket_from_host(host)
    return host, nil, nil
end


function _M.do_auth()
    local authenticator = aws_authenticator.new(
            get_secret_key,
            get_bucket_from_host,
            ngx.shared.signing_key)

    local auth_ctx, err, msg = authenticator:authenticate()
    if err ~= nil then
        ngx.log(ngx.INFO, string.format(
                'authentication error: %s, %s', err, msg))
        return nil, err, msg
    end

    if auth_ctx.anonymous == true then
        ngx.log(ngx.INFO, 'received an anonymous request')
        return nil, 'AccessDenied', 'anonymous access is not allowed'
    end

    ngx.log(ngx.INFO, 'authentication succeed the access key is:' ..
            auth_ctx.access_key)
    return auth_ctx, nil, nil
end


return _M
