package = "neoop"
version = "1.0-1"
source = {
   url = "..." -- We don't have one yet
}
description = {
   summary = "An simple, but powerful OO system.",
   detailed = [[
      no long desc... yet
   ]],
   homepage = "http://...", -- We don't have one yet
   license = "MIT/X11" -- or whatever you like
}
dependencies = {
   "lua >= 5.1"
   -- If you depend on other rocks, add them here
}
build = {
   type = "builtin",
   modules = {
     undefinedobject = "src/undefinedobject.lua",
     neoop = "src/neoop.lua",
     Class = "src/Class.lua"
   }
}
