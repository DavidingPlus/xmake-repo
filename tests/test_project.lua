local luaunit = require("luaunit")

TestProject = {}

function TestProject:testLuaUnitConfiguration()
    local xmake_file = io.open(PROJECT_DIR .. "\\xmake.lua", "rb")
    local template_file = io.open(PROJECT_DIR .. "\\scripts\\template.lua", "rb")

    luaunit.assertNotNil(xmake_file)
    luaunit.assertNotNil(template_file)

    xmake_file:close()
    template_file:close()
end

function TestProject:testPackageTemplatePlaceholders()
    local file = assert(io.open(PROJECT_DIR .. "\\scripts\\template.lua", "rb"))
    local template = file:read("*a")
    file:close()

    luaunit.assertTrue(template:find("{{PACKAGE_NAME}}", 1, true) ~= nil)
    luaunit.assertTrue(template:find("{{GITHUB_OWNER}}", 1, true) ~= nil)
end
