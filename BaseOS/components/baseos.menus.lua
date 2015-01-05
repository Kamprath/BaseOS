BaseOS.Menus = {
    ['BaseOS'] = {
        [1] = {
            name = 'Programs',
            action = function(self)
                BaseOS.Menus['programs'] = {};

                -- build a menu containing all program names and display it
                local i = 1;
                for key, val in pairs(BaseOS.programs) do
                    BaseOS.Menus['programs'][i] = {};
                    BaseOS.Menus['programs'][i]['name'] = key;
                    BaseOS.Menus['programs'][i]['action'] = val;
                    i = i + 1;
                end
                BaseOS:useMenu('programs');
            end
        },
        [2] = {
            name = 'Terminal',
            action = function(self)
                BaseOS.data.promptMode = true;
                BaseOS:prompt();
            end
        },
        [3] = {
            name = 'Shutdown',
            exit = true,
            action = function(self)
                os.shutdown();
            end
        }
    }
};