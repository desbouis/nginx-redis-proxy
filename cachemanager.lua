-- if the method is not GET or HEAD, do not read in redis
ngx.log(ngx.NOTICE, "[LUA] Is the request cacheable ?")
if (ngx.var.request_method ~= "GET" and ngx.var.request_method ~= "HEAD") then
    ngx.log(ngx.NOTICE, "[LUA] NO, skipping uncacheable request method: ", ngx.var.request_method)
    ngx.exit(ngx.HTTP_NOT_FOUND)
else
    ngx.log(ngx.NOTICE, "[LUA] YES, cacheable request found: ", ngx.var.host, ngx.var.uri)
end

-- parser object that will receive redis responses and parse them into lua objects
local parser = require "redis.parser"

ngx.log(ngx.NOTICE, "[LUA] Is the response in the redis cache ?")
local redis_read_response = ngx.location.capture("/redis_read", {args = {k = ngx.var.key}})
local res, typ = parser.parse_reply(redis_read_response.body)

if (typ == parser.BULK_REPLY and not(res == nil) and (#res > 0)) then
    ngx.log(ngx.NOTICE, "[LUA] YES, cache HIT on cache key: ", ngx.var.key, ", content length: ", #res)
    ngx.print(res)
    ngx.exit(ngx.OK)
else
    -- the content is not in redis, request to the backend
    ngx.log(ngx.NOTICE, "[LUA] NO, cache MISS on cache key: ", ngx.var.key)
    local fallback_response = ngx.location.capture("/fallback"..ngx.var.key)

-- @debug
--ngx.say("fallback response code :", fallback_response.status)
--ngx.say("fallback headers :")
--local h = fallback_response.header
--for k, v in pairs(h) do
--    ngx.say(k..": "..v)
--end
--ngx.exit(ngx.HTTP_OK)

    -- write the response in redis
    if fallback_response.status == ngx.HTTP_OK then
        ngx.req.set_header("X-RedisCache-time", ngx.http_time(ngx.time()))
        ngx.log(ngx.NOTICE, "[LUA] got response from /fallback, uri ",ngx.var.key," must be cached")
        -- get the fallback headers
        local headers = {}
        for k, v in pairs(fallback_response.header) do
            table.insert(headers, k..": "..v)
        end
        -- redis transaction
        local queries = {
            {"MULTI"},
            {"HMSET", ngx.var.key, "headers", table.concat(headers, "\\n"), "body", fallback_response.body},
            {"EXPIRE", ngx.var.key, fallback_response.header["X-RedisCache-ttl"]},
            {"EXEC"}
        }
        -- because of carriage returns in HTML code, we use the redis parser to build the queries
        local raw_queries = {}
        for i, query in ipairs(queries) do
            table.insert(raw_queries, parser.build_query(query))
        end
        local queries_response = ngx.location.capture("/redis_write?n="..#queries, { method = ngx.HTTP_POST, body = table.concat(raw_queries, "") })
        if queries_response.status ~= 200 or not queries_response.body then
            ngx.log(ngx.ERR, "[LUA] failed to query redis to store data")
        end

-- @debug
--ngx.print("retour /redis_write : ")
--local replies = parser.parse_replies(queries_response.body, #queries)
--for i, reply in ipairs(replies) do
--    ngx.say(reply[1])
--end
--ngx.exit(ngx.HTTP_OK)

        -- all is good, we return the content with 200 status code
        ngx.print(fallback_response.body)
        ngx.exit(ngx.OK)
    end
end

-- all is bad, we return a 404 not found
ngx.log(ngx.NOTICE, "[LUA] the content is not found... 404")
ngx.exit(ngx.HTTP_NOT_FOUND)

