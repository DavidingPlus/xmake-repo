-- Find all directories in the current list directory
local dirs = os.dirs("*")

-- Iterate over directories and check if xmake.lua and .buildme exist
for _, dir in ipairs (dirs) do
    local xmakeFile = path.join(dir, "xmake.lua")
    
    if os.isdir(dir) and os.isfile(xmakeFile) then
        includes (dir)
    end
end
