local undefined = {
  __class__ = {},
  data = {}
}

setmetatable(undefined, {
  __tostring = function(_)
  return "undefined"
end,
  __len = function(_)
    return false
  end
})

return undefined