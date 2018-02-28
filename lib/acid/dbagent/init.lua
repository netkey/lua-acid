local conf_util = require('acid.dbagent.conf_util')
local model_module = require('acid.dbagent.model_module')

local _M = {}


local function test_get_conf(curr_conf)
    if curr_conf ~= nil then
        ngx.sleep(5)
    end

    local value = {
        connections = {
            ['3500-1'] = {
                database = 'baishan-3copy',
                host = '127.0.0.1',
                port = 3500,
                user = 'baishan-3copy',
                password = 'Di5sUlMnyXKUX'
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


function _M.init(opts)
    if opts == nil then
        opts = {}
    end

    local model_module_dir = opts.model_module_dir or 'lib/acid/dbagent'
    local get_conf = opts.get_conf or test_get_conf

    local _, err, errmsg = model_module.load_model_module(model_module_dir)
    if err ~= nil then
        ngx.log(ngx.ERR, string.format(
                'failed to load model module from: %s, %s, %s',
                model_module_dir, err, errmsg))
    end
    conf_util.init_conf_update(get_conf)
end


return _M
