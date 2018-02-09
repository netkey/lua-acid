local client = require('acid.dbagent.client')
local json = require('acid.json')
local tableutil = require('acid.tableutil')
local strutil = require('acid.strutil')
local to_str = strutil.to_str

math.randomseed(ngx.now() * 1000)

local tttt = {}

local req_template = {
    bucket_id = '1010000000000122891',
    scope = 'u',
    key = 'test-key',
    acl = {
        GRPS000000ANONYMOUSE = {'READ'},
        user_foo = {'READ', 'READ_ACP', 'WRITE', 'WRITE_ACP'},
    },
    expires = 0,
    file_meta = {
        ['Content-Type'] = 'application/octet-stream',
    },
    group_id = 1113841,
    is_del = 0,
    md5 = '2be9bd7a3434f7038ca27d1918de5123',
    owner = 'user_foo',
    sha1 = 'f56d6351aa71cff0debea014d13525e42036187a',
    origo = '00163e0029df',
    crc32 = '12345678',
    size = 44444,
    ts = '1517908873695000102',
    ver = '1517908873695000102',
}


function tttt.key_basic(t)
    local cli, err, errmsg = client.new({'127.0.0.1'}, 1989, '', '')
    t:eq(nil, err, errmsg)

    local req = tableutil.dup(req_template, true)
    req.key = 'test-key-' .. tostring(math.random(10000))

    local r, err, errmsg = cli:req('key', 'add', req)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))

    local ident = {
        bucket_id = req.bucket_id,
        scope = req.scope,
        key = req.key,
        ts = req.ts,
    }
    local r, err, errmsg = cli:req('key', 'get', ident)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))

    req.expires = '0'
    req.group_id = tostring(req.group_id)
    req.size = tostring(req.size)

    test.dd(r)

    t:eqdict(req, r)

    local set_req = {
        file_meta = {
            foo = 'bar',
        },
    }
    tableutil.update(set_req, ident)
    local r, err, errmsg = cli:req('key', 'set', set_req)
    t:eq(nil, err, errmsg)
    t:eq(nil, r.error_code, to_str(r))

    local r, err, errmsg = cli:req('key', 'get', ident)
    t:eq(nil, err, errmsg)
    t:eqdict(r.file_meta, {foo='bar'})
    t:eq(nil, r.error_code, to_str(r))

    local r, err, errmsg = cli:req('key', 'remove', ident)
    t:eq(nil, err, errmsg)
    t:eq(nil, r.error_code, to_str(r))

    local r, err, errmsg = cli:req('key', 'get', ident)
    t:eq(nil, err, errmsg)
    t:eq(r, nil)

end


function tttt.key_ls(t)
    local cli, err, errmsg = client.new({'127.0.0.1'}, 1989, '', '')
    t:eq(nil, err, errmsg)

    local random_n = math.random(10000)

    local req = tableutil.dup(req_template, true)
    req.key = 'test-key-' .. tostring(random_n)

    local r, err, errmsg = cli:req('key', 'add', req)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))

    req.key = 'test-key-' .. tostring(random_n + 1)

    local r, err, errmsg = cli:req('key', 'add', req)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))

    local ls_req = {
        bucket_id = req.bucket_id,
        scope = 'u',
        key = 'test-key-' .. tostring(random_n),
        nlimit = 2,
    }
    local r, err, errmsg = cli:req('key', 'ls', ls_req)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))
    t:eq(2, #r)
    t:eq(ls_req.key, r[1].key)
    t:eq('test-key-' .. tostring(random_n + 1), r[2].key)

    local ls_req = {
        bucket_id = req.bucket_id,
        scope = 'u',
        key = 'test-key-' .. tostring(random_n),
        nlimit = 2,
        leftopen = true,
    }
    local r, err, errmsg = cli:req('key', 'ls', ls_req)
    t:eq(nil, err, errmsg)
    test.dd(r)
    t:eq(nil, r.error_code, to_str(r))
    t:eq(true, #r <= 2)
    t:eq('test-key-' .. tostring(random_n + 1), r[1].key)
end


function tttt.key_convert_fiels(t)
    for _, to_update, expected_json_str, desc in t:case_iter(2, {
        { {acl={}}, '"acl":{}' },
        { {acl={foo={}}}, '"acl":{"foo":[]}' },
        { {acl={foo={'READ'}}}, '"acl":{"foo":["READ"]}' },
        { {file_meta=''}, '"file_meta":""' },
        { {file_meta={}}, '"file_meta":{}' },
    }) do
        local cli, err, errmsg = client.new({'127.0.0.1'}, 1989, '', '')
        t:eq(nil, err, errmsg)

        local random_n = math.random(10000)

        local req = tableutil.dup(req_template, true)
        req.key = 'test-key-' .. tostring(random_n)
        tableutil.update(req, to_update, {recursive=false})

        local r, err, errmsg = cli:req('key', 'add', req)
        t:eq(nil, err, errmsg)
        t:eq(nil, r.error_code, to_str(r))

        local get_req = {
            bucket_id = req.bucket_id,
            scope = req.scope,
            key = req.key,
            ts = req.ts,
        }
        local opts = {
            port = 1989,
            subject = 'key',
            action = 'get',
            body = json.enc(get_req),
        }
        local r, err, errmsg = client.raw_request(opts)
        t:eq(nil, err, errmsg)
        t:eq(true, strutil.contains(r.body, expected_json_str))
    end
end


function test.replace(t)
    local cli, err, errmsg = client.new({'127.0.0.1'}, 1989, '', '')
    t:eq(nil, err, errmsg)

    local req = tableutil.dup(req_template, true)
    req.key = 'test-key-' .. tostring(math.random(10000))

    -- add
    local r, err, errmsg = cli:req('key', 'add', req)
    t:eq(nil, err, errmsg)
    --test.dd(r)
    t:eq(nil, r.error_code, to_str(r))

    -- set multipart
    local ident = {
        bucket_id = req.bucket_id,
        scope = req.scope,
        key = req.key,
        ts = req.ts,
    }

    local set_req = {
        multipart = {1}
    }
    tableutil.update(set_req, ident)
    local r, err, errmsg = cli:req('key', 'set', set_req)
    t:eq(nil, err, errmsg)
    t:eq(nil, r.error_code, to_str(r))

    -- get
    local r, err, errmsg = cli:req('key', 'get', ident)
    t:eq(nil, err, errmsg)
    --test.dd(r)
    t:eq(nil, r.error_code, to_str(r))
    t:eqdict({1}, r.multipart)

    -- replace
    local math = {
        _bucket_id = req.bucket_id,
        _scope = req.scope,
        _key = req.key,
        _ts = req.ts,
    }

    local replace_req = tableutil.dup(req, true)
    replace_req.multipart = {1, 2}
    tableutil.update(replace_req, math)

    local r, err, errmsg = cli:req('key', 'replace', replace_req)
    t:eq(nil, err, errmsg)
    --test.dd(r)

    -- get
    local r, err, errmsg = cli:req('key', 'get', ident)
    t:eq(nil, err, errmsg)
    t:eqdict({1, 2}, r.multipart)

    local r, err, errmsg = cli:req('key', 'remove', ident)
    t:eq(nil, err, errmsg)
    t:eq(nil, r.error_code, to_str(r))
end
