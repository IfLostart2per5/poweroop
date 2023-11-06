-- sistema de poo pra lua - poweroop
-- nota:
-- funções expostas começando com "debug_" são pra fins de depuração.


local M = {}
-- variavel que controla o carregamento de classes. (se será preguiçoso ou ansioso)
local lazy_classes = false
local _classes = {}
local _loaded_classes = {}



local function startswith(str, substr)
  return string.sub(str, 1, string.len(substr)) == substr
end

function copy_table(tab)
  local copia = {}
  
  for k, v in pairs(tab) do
    copia[k] = v
  end
  return copia
end

-- construtor padrao usado, caso a classe não forneça um
function _defaultInit(self) end

local function _filter_nonstatic(data)
  for k, v in pairs(data) do
    if startswith(k, "static_") then
      data[k] = nil
    end
  end
  return data
end

function common_alloc(cls)
  local data = cls.data
  local obj = {}
  for k, v in pairs(data) do
    obj[k] = v
  end
  obj.__class__ = cls
  return obj
end


-- tabela que mapeia nomes de operadores pros operadores lua
local _operator_names = {
  plus = "__add",
  minus = "__sub",
  times = "__mul",
  div = "__div",
  rest = "__mod",
  pow = "__pow",
  uminus = "__umn",
  cat = "__concat",
  invoke = "__call",
  toString = "__tostring",
  hash = "__len",
  equals = "__eq",
  lessequal = "__le",
  greatequal = "__ge",
  less = "__lt",
  greater = "__gt",
}


-- metatabela especial que possibilita getters e setters.
local object_metatable = {
  __newindex = function(tab, key, value)
    local message = "This object not have \""..tostring(key).."\" attribute."
    --procura setters
    if tab.__class__.data["static_"..key] then
      error("This attribute \""..key.."\" is static!")
    end
      if tab.__properties then
        if tab.__properties["set_" .. key] then
          tab.__properties["set_" .. key](tab, value)
          return nil
        end
      end
    rawset(tab, key, value)
  end,
  __index = function(tab, key)
    
    if tab.__class__.data["static_"..key] then
      error("This atribute \""..key.."\" is static!")
    end

    --procura getters

    if rawget(tab, "__properties") then
      if tab.__properties["get_" .. key] then
        return tab.__properties["get_" .. key](tab)
      end
    end
    return rawget(tab, key)
  end,
  __tostring = function(tab)
    return tab.__class__.name .. " object"
  end
}
  



--verifica se uma classe é subclasse de outra
function issubclass(cls1, cls2)
  assert(type(cls1) == "table" and type(cls2) == "table", "Ensure that you're using tables")
  
  if cls1 == cls2 then
    return true
  end
  --percorre a cadeia de herança até chegar num ponto onde a classe pai é nil
  local parent = ((cls1) and cls1.extends or nil)
  if parent == cls2 then
    return true
  end
  if parent == nil then
    return false
  end
  while parent ~= nil do
    if parent == cls2 then
      return true
    end
    parent = parent.extends
  end
  return false
end


local function _containsValue(tab, e)
  for _, v in pairs(tab) do
    if v == e then
      return true
    end
  end
  return false
end

--verifica se um objeto é instancia de uma classe
function isinstance(obj, cls)
  if not cls or not obj then
    return false
  end
  
  return issubclass(obj.__class__, cls)
end

-- metatabela pra deixar classes mais intuitivas
local class_metatable = {
  __call = function(cls, ...)
    return new(cls, ...)
  end,
  __tostring = function(cls)
    return "Class-object " .. cls.name
  end,
  __index = function(cls, key)
    return rawget(cls, "data")[key]
  end
}

local function _implements_inheritance(cls)
  for key, value in pairs(cls.extends.data) do
    -- obriga a classe atual a sobrescrever metodos abstratos da classe pai
    if rawget(cls.extends, "isabstract") and startswith(key, "abstract_") then
      if not cls.data["override_" .. string.sub(key, 10, string.len(key))] then
        error("This class \"" .. cls.name .. "\" doesnt implements the abstract method \"" .. string.sub(key, 10, string.len(key)) .. "\" required by \"" .. spec.extends.name .. "\"")
      end
      key = string.sub(key, 10, string.len(key))
    end 

    
    if cls.data["override_" .. key] then
      local v = cls.data["override_" .. key]
      cls.data["override_" .. key] = nil
      cls.data[key] = v
    else
      cls.data[key] = value
    end
    
    if rawget(cls.extends, "__properties") and rawget(cls, "__properties") then
      if cls.__properties["override_"..key] then
        local v = cls.__properties["override_"..key]
        cls.__properties["override_"..key] = nil
        cls.__properties[key] = v
      else
        cls.__properties[key] = value
      end
    end
  end
    if not rawget(cls, "constructor") then
      cls.constructor = cls.extends.constructor
    end
end





--metodo que faz os "retoques" de uma classe. (resolve a herança de classe, implementação de interfaces, sobrescrita de metodos etc.)
function class(name, cls, disable_lazy)
  if cls == nil then
    assert(type(name) == "table", "If you not provide a directly name, provide a class >:/")
    cls = name
  else
    cls.name = name
  end
  
  if lazy_classes and not disable_lazy then
    _classes[cls.name] = cls
    setmetatable(_classes[cls.name], class_metatable)
    return cls
  end
  if rawget(cls, "extends") ~= nil then
    
    if rawget(cls.extends, "isfinal") then
      error("Class \""..cls.extends.name.."\" is a final class!")
    end
    -- se houver herança, a faz
    _implements_inheritance(cls)
  end  
  if not cls.constructor then
    cls.constructor = _defaultInit
  end
  
  if not cls.__alloc then
    if cls.extends and cls.extends.__alloc then
      cls.__alloc = cls.extends.__alloc
    else
      cls.__alloc = common_alloc
    end
  end
  
  if cls.implements and _isArray(cls.implements) then
    for _, v in pairs(cls.implements) do
      if not issubclass(v, Interface) then
        error("O array 'implements' espera somente interfaces!")
      end
      for k, vl in pairs(v.data) do
        if not cls.data[k] then
          if startswith(k, "default_") then
            cls.data[string.sub(k, 9, string.lem(k))] = vl
          else
            error("This class doesnt implements the \"" .. tostring(k) .. "\" method!")
          end
        else
          if debug.getinfo(cls.data[k]).nparams ~= debug.getinfo(vl).nparams then
            error("This class doestnt implements correctly the \""..tostring(k).."\" method!")
          end
        end
      end
    end
  else
    cls.implements = {}
  end
  local datacopy = copy_table(cls.data)
  for ky, vl in pairs(cls.data) do
    --faz a verificação de operadores
    if startswith(ky, "operator_") then
      if type(vl) ~= "function" then
        error("Operators only can be functions!")
      end
      
      local ky2 = string.sub(ky, 10, string.len(ky))
      if not _operator_names[ky2] then
        error('"'..ky2..'" isnt a valid operator!')
      end
      datacopy[ky] = nil
      datacopy[ky2] = vl
    end
    
  end
  
  cls.data = datacopy
  setmetatable(cls, class_metatable)
  setmetatable(cls.data, {
    __index = function(self, key)
      if rawget(self, "static_"..key) then
        return rawget(self, "static_"..key)
      end
    end
  })
  if lazy_classes then
    _loaded_classes[cls.name] = cls
  end
  return cls
end





-- instancia uma classe  
function new(cls, ...)
  if lazy_classes then
    if _loaded_classes[cls.name] then
      cls = _loaded_classes[cls.name]
    else
      cls = class(cls, nil, true)
    end
  end
  if rawget(cls, "isabstract") then
    error('"'..cls.name..'"'.." is a abstract class!")
  end
  
  local obj = cls:__alloc()
  _filter_nonstatic(obj)
  obj.__properties = cls.__properties
  cls.constructor(obj, ...);
  local new_object_metatable = {}
  for k, v in pairs(object_metatable) do
    new_object_metatable[k] = v
  end
  setmetatable(obj, new_object_metatable)
  --realiza a sobrecarga de operadores
  for k, v in pairs(obj) do
    if _operator_names[k] and type(v) == "function" then
      new_object_metatable[_operator_names[k]] = v
    end
  end
  return obj
end

-- classe abstrata que é a classe base pra interfaces
local Interface = {
  name = "Interface",
  isabstract = true,
  constructor = _defaultInit,
  data = {
    
  }
}


-- função pra obter a superclasse atual. (se essa implementação não funcionar direito eu desisto desse sistema >:(, onde ja se viu, poo sem super?)
function super(self)
  if self then
    return self.__class__.extends
  end
  local name, instance = debug.getlocal(2, 1)
  if not name then
    return nil
  end
  return instance.__class__.extends
end


-- função auxiliar
function _isArray(tbl)
  if type(tbl) ~= "table" then
    return false
  end
  local i = 1
  for key, _ in pairs(tbl) do
    if type(key) ~= "number" then
      return false
    end
    if key ~= i then
      return false
    end
    i = i + 1
  end
  return true
end

--verifica se uma classe implementa uma interface
function implements(cls, it)
  if not issubclass(it, Interface) then
    error("The given second class-object is not a interface!")
  end
  if not cls.implements then
    return false
  end
  return _containsValue(cls.implements, it)
end

M.issubclass = issubclass
M.isinstance = isinstance
M.new = new
M.class = class
M.Interface = Interface
M.implements = implements
M.super = super
M.common_alloc = common_alloc
M.enable_lazy_loading = function()
  lazy_classes = true
end
M.debug_force_load = function(cls)
  if not _loaded_classes[cls.name] then
    _loaded_classes[cls.name] = class(cls, nil, true)
  end
  return _loaded_classes[cls.name]
end
  
  
setmetatable(M, {
  __call = function(self, ...)
    return self.class(...)
  end
})
return M
