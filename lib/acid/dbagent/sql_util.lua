local strutil = require('acid.strutil')

local to_str = strutil.to_str

local _M = {}


local function quote_binary(value, field)
    if field.no_hex == true then
        return ndk.set_var.set_quote_sql_str(value)
    end

    return string.format('UNHEX("%s")', value)
end


local function quote_string(value, field)
    local _ = field
    return ndk.set_var.set_quote_sql_str(value)
end


local function quote_number(value, field)
    local _ = field
    return value
end


local function quote_bigint(value, field)
    if field.no_string == true then
        return value
    end

    return quote_string(value, field)
end


local function as_it_is(field_name, field)
    local _ = field
    return string.format('`%s`', field_name)
end


local function as_hex(field_name, field)
    if field.no_hex == true then
        return as_it_is(field_name, field)
    end

    return string.format('LOWER(HEX(`%s`)) as `%s`',
                         field_name, field_name)
end


local function as_string(field_name, field)
    local _ = field
    return string.format('CAST(`%s` AS CHAR) as `%s`',
                         field_name, field_name)
end


local function as_bigint(field_name, field)
    if field.no_string == true then
        return as_it_is(field_name, field)
    end

    return as_string(field_name, field)
end


local field_type_model = {
    binary = {
        quote = quote_binary,
        build_as_str = as_hex,
    },
    varbinary = {
        quote = quote_binary,
        build_as_str = as_hex,
    },
    varchar = {
        quote = quote_string,
        build_as_str = as_it_is,
    },
    text = {
        quote = quote_string,
        build_as_str = as_it_is,
    },
    tinyint = {
        quote = quote_number,
        build_as_str = as_it_is,
    },
    int = {
        quote = quote_number,
        build_as_str = as_it_is,
    },
    bigint = {
        quote = quote_bigint,
        build_as_str = as_bigint,
    },
}


local function quote_value(field, value)
    local field_type = field.field_type

    local type_model = field_type_model[field_type]
    if type_model == nil then
        ngx.log(ngx.ERR, 'not type model for: ' .. field_type)
        return
    end
    local quote = type_model.quote

    local ok, r_or_err = pcall(quote, value, field)
    if not ok then
        return nil, 'QuoteError', string.format(
                'failed to quoted value: %s, of field: %s, %s',
                to_str(value), to_str(field), r_or_err)
    end

    return r_or_err
end


function _M.build_field_as_str(field_name, field)
    local field_type = field.field_type
    local type_model = field_type_model[field_type]
    if type_model == nil then
        ngx.log(ngx.ERR, 'not type model for: ' .. field_type)
        return
    end
    local build_as_str = type_model.build_as_str

    field.as_str = build_as_str(field_name, field)
    return
end


local function build_equal_str(fields, column, args, separator)
    if column == nil then
        return '', nil, nil
    end

    separator = separator or ','
    local parts = {}

    for param_name, _ in pairs(column) do
        local field = fields[param_name]
        local value = args[param_name]
        if value ~= nil  then
            local quoted_value, err, errmsg = quote_value(field, value)
            if err ~= nil then
                return nil, err, errmsg
            end
            table.insert(parts, string.format(
                    '%s=%s', field.backticked_name, quoted_value))
        end
    end

    return table.concat(parts, separator), nil, nil
end


local function build_range_str(fields, range, args)
    if range == nil then
        return '', nil, nil
    end

    local parts = {}

    for param_name, _ in pairs(range) do
        local field = fields[param_name]
        local value = args[param_name]
        if value ~= nil  then
            local range_parts = strutil.split(value, ',')

            local quoted_value, err, errmsg = quote_value(
                    field, range_parts[1])
            if err ~= nil then
                return nil, err, errmsg
            end
            table.insert(parts, string.format(
                    '%s>=%s', field.backticked_name, quoted_value))

            local quoted_value, err, errmsg = quote_value(
                    field, range_parts[2])
            if err ~= nil then
                return nil, err, errmsg
            end

            table.insert(parts, string.format(
                    '%s<=%s', field.backticked_name, quoted_value))
        end
    end

    return table.concat(parts, ' AND '), nil, nil
end


local function build_greater_than_str(fields, matched_fields, args)
    if #matched_fields == 0 then
        return '', nil, nil
    end

    local parts = {}

    for i, field_name in ipairs(matched_fields) do
        local field = fields[field_name]
        local value = args[field_name]
        local quoted_value, err, errmsg = quote_value(field, value)
        if err ~= nil then
            return nil, err, errmsg
        end

        if i < #matched_fields then
            table.insert(parts, string.format(
                    '%s=%s', field.backticked_name, quoted_value))
        else
            if args.leftopen == true then
                table.insert(parts, string.format(
                        '%s>%s', field.backticked_name, quoted_value))
            else
                table.insert(parts, string.format(
                        '%s>=%s', field.backticked_name, quoted_value))
            end
        end
    end

    return table.concat(parts, ' AND '), nil, nil
end


local function build_increase_str(fields, column, args)
    if column == nil then
        return '', nil, nil
    end

    local parts = {}
    for param_name, _ in pairs(column) do
        local field = fields[param_name]
        local value = args[param_name]
        if value ~= nil  then
            local quoted_value, err, errmsg = quote_value(field, value)
            if err ~= nil then
                return nil, err, errmsg
            end
            table.insert(parts, string.format(
                    '%s=%s+%s', field.backticked_name,
                    quoted_value, field.backticked_name))
        end
    end

    return table.concat(parts, ','), nil, nil
end


local function build_match_str(fields, match, args)
    if match == nil then
        return '', nil, nil
    end

    local parts = {}
    for param_name, _ in pairs(match) do
        local field = fields[string.sub(param_name, 2)]
        local value = args[param_name]
        if value ~= nil then
            local quoted_value, err, errmsg = quote_value(field, value)
            if err ~= nil then
                return nil, err, errmsg
            end
            table.insert(parts, string.format(
                    '%s=%s', field.backticked_name, quoted_value))
        end
    end

    return table.concat(parts, ' AND '), nil, nil
end


local function build_where_str(conditions)
    local r = ''
    for _, condition_str in ipairs(conditions) do
        if type(condition_str) == 'string' and #condition_str > 0 then
            if r == '' then
                r = condition_str
            else
                r = string.format('%s AND %s', r, condition_str)
            end
        end
    end

    if r ~= '' then
        r = ' WHERE ' .. r
    end

    return r
end


local function build_insert_sql(table_name, fields, action_model, args)
    local names = {}
    local values = {}

    local valid_param = action_model.valid_param

    for field_name, _ in pairs(valid_param.column) do
        if args[field_name] ~= nil then
            local field = fields[field_name]
            table.insert(names, field.backticked_name)

            local value = args[field_name]
            local quoted_value, err, errmsg = quote_value(field, value)
            if err ~= nil then
                return nil, err, errmsg
            end
            table.insert(values, quoted_value)
        end
    end

    local names_str = table.concat(names, ',')
    local values_str = table.concat(values, ',')
    local sql = string.format('INSERT IGNORE INTO `%s` (%s) VALUES (%s)',
                              table_name, names_str, values_str)

    return sql, nil, nil
end


local function build_update_sql(table_name, fields, action_model, args,
                                incremental)
    local valid_param = action_model.valid_param

    local set_str, err, errmsg
    if incremental then
        set_str, err, errmsg = build_increase_str(
                fields, valid_param.column, args)
        if err ~= nil then
            return nil, err, errmsg
        end
    else
        set_str, err, errmsg = build_equal_str(
                fields, valid_param.column, args)
        if err ~= nil then
            return nil, err, errmsg
        end
    end

    if set_str == '' then
        return  nil, 'InvalidArgument', 'no field to set'
    end

    set_str = 'SET ' .. set_str

    local ident_str, err, errmsg = build_equal_str(
            fields, valid_param.ident, args, ' AND ')
    if err ~= nil then
        return nil, err, errmsg
    end

    local match_str, err, errmsg = build_match_str(
            fields, valid_param.match, args)
    if err ~= nil then
        return nil, err, errmsg
    end

    local where_str = build_where_str({ident_str, match_str})

    local sql = string.format('UPDATE IGNORE `%s` %s%s LIMIT 1',
                              table_name, set_str, where_str)
    return sql, nil, nil
end


local function build_delete_sql(table_name, fields, action_model, args)
    local valid_param = action_model.valid_param
    local ident_str, err, errmsg = build_equal_str(
            fields, valid_param.ident, args, ' AND ')
    if err ~= nil then
        return nil, err, errmsg
    end

    local match_str, err, errmsg = build_match_str(
            fields, valid_param.match, args)
    if err ~= nil then
        return nil, err, errmsg
    end

    local where_str = build_where_str({ident_str, match_str})

    local sql = string.format('DELETE IGNORE FROM `%s`%s LIMIT 1',
                              table_name, where_str)
    return sql, nil, nil
end


local function build_select_as_str(fields, select_column)
    local parts = {}

    for _, field_name in ipairs(select_column) do
        local field = fields[field_name]
        table.insert(parts, field.as_str)
    end

    return table.concat(parts, ',')
end


local function build_force_index(indexes, args)
    local index_to_use
    local longest_match_n = 0

    for index_name, index_columns in pairs(indexes) do
        local match_n = 0

        for _, column_name in ipairs(index_columns) do
            if args[column_name] ~= nil then
                match_n = match_n + 1
            else
                break
            end
        end

        if match_n >= longest_match_n then
            longest_match_n = match_n
            index_to_use = index_name
        end
    end

    if index_to_use == nil then
        return {force_index_str='', matched_fields={}}
    end

    local matched_fields = {unpack(indexes[index_to_use], 1, longest_match_n)}

    return {
        force_index_str = string.format(' FORCE INDEX (%s)', index_to_use),
        matched_fields = matched_fields,
    }
end


local function build_select_sql(table_name, fields, action_model, args, opts)
    opts = opts or {}
    local select_as_str = opts.select_as_str
    if select_as_str == nil then
        select_as_str = build_select_as_str(fields,
                                            action_model.select_column)
    end

    local ident_str, err, errmsg = build_equal_str(
            fields, action_model.valid_param.ident, args, ' AND ')
    if err ~= nil then
        return nil, err, errmsg
    end

    local match_str, err, errmsg = build_match_str(
            fields, action_model.valid_param.match, args)
    if err ~= nil then
        return nil, err, errmsg
    end

    local conditions = {}

    if opts.greater_than_str ~= nil then
        table.insert(conditions, opts.greater_than_str)
    elseif opts.range_str ~= nil then
        table.insert(conditions, opts.range_str)
    end

    table.insert(conditions, ident_str)
    table.insert(conditions, match_str)

    local where_str = build_where_str(conditions)

    local force_index_str = opts.force_index_str or ''
    local sql = string.format('SELECT %s FROM `%s`%s%s',
                              select_as_str, table_name,
                              force_index_str, where_str)

    if opts.group_by_str ~= nil then
        sql = sql .. ' ' .. opts.group_by_str
    end

    if type(opts.limit) == 'number' then
        sql = sql .. ' LIMIT ' .. tostring(opts.limit)
    end

    return sql, nil, nil
end


function _M.make_add_sql(api_ctx)
    local sql, err, errmsg = build_insert_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_set_sql(api_ctx)
    local sql, err, errmsg = build_update_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            false)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_increase_sql(api_ctx)
    local sql, err, errmsg = build_update_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            true)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_get_sql(api_ctx)
    local sql, err, errmsg = build_select_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            {limit=1})
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_get_multi_sql(api_ctx)
    local sql, err, errmsg = build_select_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            {})
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_indexed_ls_sql(api_ctx)
    local nlimit = api_ctx.args.nlimit or 1
    local fields = api_ctx.subject_model.fields
    local indexes = api_ctx.action_model.indexes
    local args = api_ctx.args

    local opts = {
        limit = nlimit,
    }

    local force_index = build_force_index(indexes, args)
    if force_index.force_index_str ~= '' then
        local greater_than_str = build_greater_than_str(
                fields, force_index.matched_fields, args)

        opts.force_index_str = force_index.force_index_str
        opts.greater_than_str = greater_than_str
    end

    local sql, err, errmsg = build_select_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            opts)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_count_sql(api_ctx)
    local fields = api_ctx.subject_model.fields
    local args = api_ctx.args
    local valid_param = api_ctx.action_model.valid_param

    local opts = {}

    local group_by_field = fields[args['group_by']]
    if group_by_field == nil then
        return nil, 'InvalidArgument', string.format(
                'the value of arg group_by: %s is not a field name',
                tostring(args['group_by']))
    end

    opts.select_as_str = string.format('%s,COUNT(*) as `count`',
                                       group_by_field.as_str)

    opts.range_str = build_range_str(fields, valid_param.range, args)

    local group_by_str = string.format(' GROUP BY %s',
                                       group_by_field.backticked_name)

    if args.desc ~= nil then
        group_by_str = group_by_str .. ' DESC'
    elseif args.ase ~= nil then
        group_by_str = group_by_str .. ' ASC'
    end

    opts.group_by_str = group_by_str

    local sql, err, errmsg = build_select_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            opts)
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_remove_sql(api_ctx)
    local sql, err, errmsg = build_delete_sql(
            api_ctx.upstream.table_name,
            api_ctx.subject_model.fields,
            api_ctx.action_model,
            api_ctx.args,
            {limit=1})
    if err ~= nil then
        return nil, err, errmsg
    end

    api_ctx.sqls = {sql}

    return sql, nil, nil
end


function _M.make_replace_sql(api_ctx)
    local remove_sql, err, errmsg = _M.make_remove_sql(api_ctx)
    if err ~= nil then
        return nil, 'MakeReplaceSqlError', string.format(
                'failed to make remove sql: %s, %s', err, errmsg)
    end

    local add_sql, err, errmsg = _M.make_add_sql(api_ctx)
    if err ~= nil then
        return nil, 'MakeReplaceSqlError', string.format(
                'failed to make add sql: %s, %s', err, errmsg)
    end

    api_ctx.sqls = {remove_sql, add_sql}

    return {remove_sql, add_sql}, nil, nil
end


_M.sql_maker = {
    add = _M.make_add_sql,
    set = _M.make_set_sql,
    increase = _M.make_increase_sql,
    get = _M.make_get_sql,
    get_multi = _M.make_get_multi_sql,
    indexed_ls = _M.make_indexed_ls_sql,
    ls = _M.make_indexed_ls_sql,
    remove = _M.make_remove_sql,
    count = _M.make_count_sql,
    replace = _M.make_replace_sql,
}


function _M.make_sqls(api_ctx)
    local sql_type = api_ctx.action_model.sql_type
    local sql_maker_func = _M.sql_maker[sql_type]

    if sql_maker_func == nil then
        ngx.log(ngx.ERR, string.format(
                'no sql maker function for subject: action: %s',
                api_ctx.subject, api_ctx.action))

        return nil, 'InternalError', 'no sql maker function'
    end

    local _, err, errmsg = sql_maker_func(api_ctx)
    if err ~= nil then
        return nil, err, errmsg
    end

    ngx.log(ngx.INFO, string.format('made sqls for: %s %s, %s',
                                    api_ctx.subject, api_ctx.action,
                                    to_str(api_ctx.sqls)))
    return true, nil, nil
end


return _M
