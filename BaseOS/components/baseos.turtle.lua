BaseOS.Turtle = {
    --- Sends a rednet message on protocol 'turtle' containing a JSON-encoded table of data
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
    end
};