local currentFile = debug.getinfo(1, "S").source:sub(2)
local spoonDir = currentFile:match("(.*/)")
local rootDir = spoonDir:gsub("Spoons/RecursiveBinder%.spoon/$", "")
local target = rootDir .. "RecursiveBinder/init.lua"

local chunk, err = loadfile(target)
if not chunk then
  error("Failed to load RecursiveBinder from " .. target .. ": " .. tostring(err))
end

return chunk()
