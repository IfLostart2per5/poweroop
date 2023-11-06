package = "poweroop"
version = "1.0-1"
source = {
   url = "https://github.com/IfLostart2per5/poweroop"
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
     ["poweroop.undefinedobject"] = "src/undefinedobject.lua",
     poweroop = "src/poweroop.lua",
   }
}
