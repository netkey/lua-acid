local strutil = require('acid.strutil')
local tableutil = require('acid.tableutil')
local arg_schema_checker = require('arg_schema_checker')
local json = require('acid.json')
local repr = tableutil.repr

local to_str = strutil.to_str

local _M = {}


local function build_any_schema(field)
    local _ = field

    local schema = {
        ['type'] = 'any',
    }

    return {schema}
end


local function build_string_schema(field)
    local schema = {
        ['type'] = 'string',
    }
    if field.m ~= nil then
        schema.max_length = field.m
    end

    return {schema}
end


local function build_integer_schema(field)
    local _ = field
    local schema = {
        ['type'] = 'integer',
    }

    return {schema}
end


local function build_integer_or_string_schema(field)
    local _ = field
    local schemas = {}
    tableutil.extends(schemas, build_integer_schema(field))
    tableutil.extends(schemas, build_string_schema(field))
    return schemas
end


local function build_binary_schema(field)
    if field.no_hex then
        return build_string_schema(field)
    end

    local schema = {
        ['type'] = 'string',
        fixed_length = field.m * 2,
    }

    return {schema}
end


local function build_varbinary_schema(field)
    if field.no_hex then
        return build_string_schema(field)
    end

    local schema = {
        ['type'] = 'string',
        max_length = field.m * 2,
    }

    return {schema}
end


local schema_builder = {
    binary = build_binary_schema,
    varbinary = build_varbinary_schema,
    varchar = build_string_schema,
    text = build_string_schema,
    tinyint = build_integer_schema,
    int = build_integer_schema,
    bigint = build_integer_or_string_schema,
}


function _M.build_field_schema(field)
    if field.convert_method ~= nil then
        field.checker = build_any_schema(field)
        return
    end

    local builder = schema_builder[field.field_type]

    if builder == nil then
        ngx.log(ngx.ERR, 'no schema builder for: ' .. failed.field_type)
        return
    end

    field.checker = builder(field)
end


function _M.set_default(api_ctx)
    local args = api_ctx.args
    local default = api_ctx.action_model.default

    if default == nil then
        return true, nil, nil
    end

    local setter = tableutil.default_setter(default)
    setter(args)

    return true, nil, nil
end


local function schema_check(args, subject_model)
    for arg_name, arg_value in pairs(args) do
        local name = arg_name
        if strutil.startswith(arg_name, '-') then
            name = string.sub(arg_name, 2)
        end

        local param_model = subject_model.fields[name]
        if param_model == nil then
            return true, nil, nil
        end

        local _, err, errmsg = arg_schema_checker.do_check(
                arg_value, param_model.checker)
        if err ~= nil then
            return nil, 'InvalidArgument', string.format(
                    'failed to check schema of: %s, %s, %s, %s, %s',
                    arg_name, tostring(arg_value),
                    to_str(param_model.checker), err, errmsg)
        end
    end

    return true, nil, nil
end


local function shape_check(args, action_model)
    local args_copy = tableutil.dup(args, true)

    for _, params in pairs(action_model.valid_param) do
        for param_name, required in pairs(params) do
            if required and args_copy[param_name] == nil then
                return nil, 'LackArgumet',
                        'lack argument: ' .. param_name
            end

            args_copy[param_name] = nil
        end
    end

    local remain_arg = next(args_copy)
    if remain_arg ~= nil then
        return nil, 'ExtraArgument',
                'extra argument: ' .. tostring(remain_arg)
    end

    return true, nil, nil
end


function _M.check(api_ctx)
    local args = api_ctx.args
    local subject_model = api_ctx.subject_model
    local action_model = api_ctx.action_model

    --ngx.log(ngx.ERR, 'test------------' .. repr(api_ctx.subject_model.fields))

    local _, err, errmsg = schema_check(args, subject_model)
    if err ~= nil then
        return nil, err, errmsg
    end

    local _, err, errmsg = shape_check(args, action_model)
    if err ~= nil then
        return nil, err, errmsg
    end

    return true, nil, nil
end


return _M
