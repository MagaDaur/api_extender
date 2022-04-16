http = Panorama.LoadString([[
    let requests = {};

    return {
        requestInternal: function(timestamp, url, options)
        {
            requests[timestamp] = {
                complete: false,
                value: null
            };

            options.complete = function(response) { 
                requests[timestamp].complete = true;
                requests[timestamp].value = response;
            };

            $.AsyncWebRequest(url, options);
        },
        getRequest: function(timestamp)
        {
            return requests[timestamp];
        },
        removeRequest: function(timestamp)
        {
            delete requests[timestamp];
        }
    };
]])()

http.requestTable = {}
http.requestCount = 0

function asyncWebRequest(requestType, url, data, complete)
    local options = {}
    
    options.data = data
    options.type = requestType
    options.timeout = 20000

    local timestamp = http.requestCount
    table.insert(http.requestTable, {complete = complete, timestamp = timestamp})
    http.requestInternal(timestamp, url, options)

    http.requestCount = http.requestCount + 1
end

http.updateRequests = function()
    for i = #http.requestTable, 1, -1 do
        local request = http.requestTable[i]
        local requestJS = http.getRequest(request.timestamp)

        if requestJS.complete then
            request.complete(requestJS.value)
            table.remove(http.requestTable, i)
            http.removeRequest(request.timestamp)
        end
    end
end

Http.PostAsync = function (url, data, callback)
    asyncWebRequest("POST", url, data, function (value)
        if(callback) then
            callback(value.responseText)
        end
    end)
end

Http.GetAsync = function (url, callback)
    asyncWebRequest("GET", url, nil, function (value)
        if(callback) then
            callback(value.responseText)
        end
    end)
end