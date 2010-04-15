# Hook up core extenstions (need to define them as main level, hence 
# the :: prefix)
class ::String # :nodoc: 
  include GlobalizeBridge::CoreExtensions::String
end

class ::Symbol # :nodoc:  
  include GlobalizeBridge::CoreExtensions::Symbol
end

class ::Object # :nodoc:  
  include GlobalizeBridge::CoreExtensions::Object
end

class ::Fixnum # :nodoc:
  include GlobalizeBridge::CoreExtensions::Integer 
end

class ::Bignum # :nodoc:
  include GlobalizeBridge::CoreExtensions::Integer
end

class ::Float # :nodoc:
  include GlobalizeBridge::CoreExtensions::Float  
end

class ::Time # :nodoc:
  include GlobalizeBridge::CoreExtensions::Time
end

class ::Date # :nodoc:
  include GlobalizeBridge::CoreExtensions::Date
end
