# I18n extensions of functionality formerly available in Globalize1
module I18n

  class << self

    # Allows you to switch the current locale while within the block.
    # The previously current locale is reset after the block is finished.
    #
    # E.g
    #
    #     I18n.locale = :'en-US'
    #     I18n.switch_locale :'es-ES' do
    #       product.name = 'esquis'
    #     end
    #
    #     product.name #   --> skis
    #
    def switch_locale(code)
      current_locale = I18n.locale
      I18n.locale = code
      result = yield
      I18n.locale = current_locale
      result
    end
    alias_method :with_locale, :switch_locale   # make it more Globalize2 like

    # Returns true if the currently set locale is the default_locale
    # this is analogous to Globalize Locale.base?
    def default_locale?
      I18n.default_locale == I18n.locale
    end
    alias_method :base_locale?, :default_locale?

    # Returns the language specific portion of the locale as code symbol
    #
    # E.g.
    #
    #   :de-DE     I18n.locale_language -> :de
    #   :en        I18n.locale_language -> :en
    #   :"it-IT"   I18n.locale_language -> :it
    #
    def locale_language(locale=nil)
      "#{locale || I18n.locale}"[0, 2].to_sym
    end

    # Returns the country specific portion of locale as code symbol
    #
    # E.g.
    #
    #   :de-DE     I18n.locale_country_code  -> :DE
    #   :en        I18n.locale_country_code  -> nil
    #   :"it-IT"   I18n.locale_country_code -> :IT
    #
    def locale_country(locale=nil)
      "#{locale || I18n.locale}".match(/-([a-zA-Z]{2})/) ? $1.to_sym : nil
    end

    # dummy for now, but should be configured using locale
    # 'ltr' --> left to right, or bidi 'rtl' --> right to left
    def language_direction
      "ltr"
    end

    # escape translation keys to make globalize namespace possible
    #
    # e.g.
    #
    #   :'Foo. And Bar.', :foo -> ' foo."Foo. And Bar."
    #   
    #
    def escape_translation_key(key, scope=nil, separator=nil)
      scope ? "#{scope}#{separator || I18n.default_separator}\"#{key}\"" : "\"#{key}\""
    end

    # inverse of escape, returns and array of scope and value or if not escaped, 
    #
    # e.g.
    #
    #   'foo."Foo. And Bar."' -> ['foo', 'Foo. And Bar.']
    #   '"Foo. And Bar."' -> [nil, 'Foo. And Bar.']
    #   'foo.bar' -> false -> [nil, 'foo.bar']
    #
    def unescape_translation_key(key, separator=nil)
      # 'foo."Foo. And Bar."'.match /((.*)\."(.*)"$)|(^"(.*)"$)/
      if key && key.is_a?(String) && key.match(unescape_translation_key_regexp(separator)) 
        if $1 
          return $2, $3
        else
          return nil, $5
        end
      else
        return nil, key
      end
    end
    
    # returns true if the key is escaped
    #
    # e.g.
    #
    #   'foo."Foo. And Bar."' -> true
    #   '"And Bar."' -> true
    #   'foo.bar' -> false
    #
    def translation_key_escaped?(key, separator=nil)
      key && key.is_a?(String) ? !!key.match(unescape_translation_key_regexp(separator)) : false
    end

    # simply returns the escaped portion of an escaped translation key
    #
    # e.g.
    #
    #   foo."Foo. And Bar." -> Foo. And Bar.
    #
    def unescape_translation_key_without_scope(key, separator=nil)
      unescape_translation_key(key, separator)[1]
    end

    # for I18n > 0.2.0 overrides standard method, otherwise, defines it
    # handles the unescaping of strings that contain a separator character
    def normalize_keys(locale, key, scope, separator = nil)
      keys = [locale] + Array(scope) + Array(key)
      keys = keys.map {|k| I18n.translation_key_escaped?(k) ? I18n.unescape_translation_key(k) : k.to_s.split(separator || I18n.default_separator)}
      keys = (keys.flatten - ['']).reject {|k| !k}
      keys.map {|k| k.to_sym if k}
    end
    
    private

    # regular expression to match escaped keys
    def unescape_translation_key_regexp(separator=nil)
      Regexp.new("((.*)#{'\\' + (separator || I18n.default_separator)}\"(.*)\"$)|(^\"(.*)\"$)")
    end
    
    # Overload 
    # Note: Will be deprecated, overload I18n.normalize_keys instead in the future.
    def normalize_translation_keys(locale, key, scope, separator = nil)
      normalize_keys(locale, key, scope, separator)
    end
    
  end
  
end
