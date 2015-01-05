--[[
-- This file serves as a template for new applications
--]]

BaseOS.programs['BaseApp'] = function(self, ...)
    self.BaseApp = {
        data = {
            running = true
        },

        menus = {
            ['main'] = {
                [1] = {
                    name = 'BaseApp',
                    action = function(self)

                    end
                }
            }
        },

        --- Initializes the application
        init = function(self)
            BaseOS:addMenu('BaseApp', self.menus['main']);
            BaseOS:useMenu('BaseApp');
        end,
    }

    self.BaseApp:init();
end