# This is a helper class to better deal with model translation tools 
# when used in combination with Globalize2 translated internal
class ModelTranslation < ::Translation
  attr_accessor :table_name
  attr_accessor :facet
  attr_accessor :locale
  attr_accessor :record_id
  attr_accessor :value
end

