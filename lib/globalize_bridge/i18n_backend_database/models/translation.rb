# Extends Backend Database to deal with escaped key values
Translation.class_eval do 
  class << self
  
    # returns "Foo. And Bar." for value 'foo."Foo. And Bar."'
    def unescape(key)
      I18n.unescape_translation_key_without_scope(key)
    end
    
  end

  def unescape(key)
    self.class.unescape(key)
  end

  # returns unescaped default key value correctly, if necessary
  def default_locale_value(rescue_value='No default locale value')
    begin
      ::Locale.default_locale.translations.find_by_key_and_pluralization_index(self.key, self.pluralization_index).value
    rescue
      self.unescape(rescue_value)
    end
  end
  
  protected
    
  def generate_hash_key
    self.raw_key = key.to_s
    self.key = ::Translation.hk(key)
  end

  def update_cache
    new_cache_key = ::Translation.ck(self.locale, self.key, false)
    I18n.cache_store.write(new_cache_key, self.value) if I18n.cache_store
  end
    
end
