--[[
--  The Turtle component contains methods for interacting with turtles and interacting with TurtleOS.
--]]

BaseOS.Turtle = {
    --- Sends a rednet message on 'turtle' protocol containing a JSON-encoded table of data
    -- @param receiverID    ID of recipient computer or turtle
    -- @param data          A table of data
    -- @param getResponse   (Optional) If true, the method will wait for a response message from the recipient and return a table of data
    -- @param token         (Optional) A token provided by a prior request. Tokens associate a request with a response.
    -- @return              If a response message was received, a table of data is returned. If not, nothing is returned.
    request = function(self, receiverID, data, getResponse, token)
        if (getResponse == nil) then getResponse = true; end
        token = token or math.random(999999);
        data['token'] = token;
        local json = JSON:encode(data);

        -- send message to the target ID
        rednet.send(receiverID, json, 'turtle');

        -- if getResponse is true, wait for a response
        while (getResponse) do
            local senderID, response, protocol = rednet.receive('turtle', 3);

            if (senderID ~= nil) then
                response = JSON:decode(response);

                if (response.token == token) then return response end
            else
                return false;
            end
        end
    end,

    --- Broadcasts a rednet message on 'turtle' protocol containing a JSON-encoded table of data
    -- @param data          A table of data
    -- @param getResponses  (Optional) If true, any responses will be returned as a numerically-indexed table of tables containing response data
    -- @return              Returns table of responses if responses were received or nil
    broadcast = function(self, data, getResponses)
        if (getResponses == nil) then getResponses = true; end
        local token = token or math.random(999999);
        data['token'] = token;
        local json = JSON:encode(data);
        local responses = {};

        rednet.broadcast(json, 'turtle');

        local i = 1;
        while (getResponses) do
            local senderID, response, protocol = rednet.receive('turtle', 1);

            if (senderID ~= nil) then
                -- add table to responses table
                responses[i] = JSON:decode(response);
                i = i + 1;
            else
                break;
            end
        end

        if (BaseOS:tableSize(responses) > 0) then return responses; end
    end
};