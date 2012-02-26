---------------------
--                 --
--  Cache Manager  --
--                 --
---------------------

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

-- read the response in redis
ngx.log(ngx.NOTICE, "[LUA] Is the response in the redis cache ?")
local redis_read_response = ngx.location.capture("/redis_read", {args = {k = ngx.var.key}})
local res, typ = parser.parse_reply(redis_read_response.body)

if (typ == parser.BULK_REPLY and not(res == nil) and (#res > 0)) then
    -- the content is in redis, just return the content with the good http code
    ngx.log(ngx.NOTICE, "[LUA] YES, cache HIT on cache key: ", ngx.var.key, ", content length: ", #res)
    ngx.print(res)
    ngx.exit(ngx.OK)

else
    -- the content is not in redis, request to the backend
    ngx.log(ngx.NOTICE, "[LUA] NO, cache MISS on cache key: ", ngx.var.key)
    local backend_response = ngx.location.capture("/fallback"..ngx.var.key)

-- @debug
--ngx.say("backend response code :", backend_response.status)
--ngx.say("backend headers :")
--local h = backend_response.header
--for k, v in pairs(h) do
--    ngx.say(k..": "..v)
--end
--ngx.exit(ngx.HTTP_OK)

    -- write the response in redis
    if backend_response.status == ngx.HTTP_OK then

        ngx.log(ngx.NOTICE, "[LUA] got response from /fallback, uri ",ngx.var.key," must be cached")

        -- our header names declaration
        local ttl_header, expireat_header, startdate_header, enddate_header = "X-RedisCache-ttl", "X-RedisCache-expireat", "X-RedisCache-startdate", "X-RedisCache-enddate"

        -- ttl, expiration date or persistent data (default)
        local expire_query = {"PERSIST", ngx.var.key}
        local starttime, endtime = ngx.time(), "never"
        if backend_response.header[ttl_header] ~= nil then
            expire_query = {"EXPIRE", ngx.var.key, backend_response.header[ttl_header]}
            endtime = starttime + backend_response.header[ttl_header]
        elseif backend_response.header[expireat_header] ~= nil then
            expire_query = {"EXPIREAT", ngx.var.key, backend_response.header[expireat_header]}
            endtime = backend_response.header[expireat_header]
        end

        -- add some custome headers
        backend_response.header[startdate_header] = ngx.http_time(starttime)
        backend_response.header[enddate_header]   = ngx.http_time(endtime)

        -- get the backend headers
        local headers = {}
        for k, v in pairs(backend_response.header) do
            table.insert(headers, k..": "..v)
        end

        -- redis transaction
        local queries = {
            {"MULTI"},
            {"HMSET", ngx.var.key, "headers", table.concat(headers, "\\n"), "body", backend_response.body},
            expire_query,
            {"EXEC"}
        }
        -- because of carriage returns in HTML code, we use the redis parser to build the queries
        local raw_queries = {}
        for i, query in ipairs(queries) do
            table.insert(raw_queries, parser.build_query(query))
        end

        -- let's write now
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
        ngx.print(backend_response.body)
        ngx.exit(ngx.OK)
    end
end

-- all is bad, we return a 404 not found
ngx.log(ngx.NOTICE, "[LUA] the content is not found... 404")
ngx.exit(ngx.HTTP_NOT_FOUND)

