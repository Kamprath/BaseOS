BaseOS.programs['test'] = function(self, args)
	print('it\'s a test. did it work?');
	for key, val in pairs(args) do
		print('arg: ' .. val);
	end
end