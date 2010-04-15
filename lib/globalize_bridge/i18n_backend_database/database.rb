# Overrides translate to support locale fallbacks
module I18n
  module Backend
    class Database

      cattr_accessor :cached_db_locales
      @@cached_db_locales = []


      def initialize(options = {})
        store = options.delete(:cache_store)
        text_tag = options.delete(:localize_text_tag)
        @cache_store = if store
          ActiveSupport::Cache.lookup_store(store)
        else
          defined?(I18n.cache_store) && I18n.cache_store ? I18n.cache_store : Rails.cache
        end
        @localize_text_tag = text_tag ? text_tag : '^^'
      end

      # override to fix namespace
      def locale=(code)
        @locale = ::Locale.find_by_code(code)
      end
      
      # Handles the lookup and addition of translations to the database
      #
      # On an initial translation, the locale is checked to determine if
      # this is the default locale.  If it is, we'll create a complete
      # translation record for this locale with both the key and value.
      #
      # If the current locale is checked, and it differs from the default
      # locale, we'll create a translation record with a nil value.  This
      # allows for the lookup of untranslated records in a given locale.
      def translate(locale, key, options = {})
        @locale = locale_in_context(locale)

        options[:scope] = [options[:scope]] unless options[:scope].is_a?(Array) || options[:scope].blank?
        key = "#{options[:scope].join('.')}.#{key}".to_sym if options[:scope] && key.is_a?(Symbol)
        count = options[:count]
        # pull out values for interpolation
        values = options.reject { |name, value| [:scope, :default].include?(name) }

        # lookup value from given locale
        entry = lookup(@locale, key)

        # if no entry and fallbacks are defined, check through the fallback chain
        if !entry && I18n.respond_to?(:fallbacks)
          I18n.fallbacks[locale].reject {|l| l == :root}.each do |fallback_locale|
            @locale = locale_in_context(fallback_locale) and break if entry = lookup(locale_in_context(fallback_locale), key)
          end
        end
        
        cache_lookup = true unless entry.nil?

        # if no entry exists for the current locale and the current locale is not the default locale then lookup translations for the default locale for this key
        unless entry || @locale.default_locale?
          entry = use_and_copy_default_locale_translations_if_they_exist(@locale, key)
        end

        # if we have no entry and some defaults ... start looking them up
        unless entry || key.is_a?(String) || options[:default].blank?
          default = options[:default].is_a?(Array) ? options[:default].shift : options.delete(:default)
          return translate(@locale.code, default, options.dup)
        end

        # this needs to be folded into the above at some point.
        # this handles the case where the default of the string key is a space
        if !entry && key.is_a?(String) && options[:default] == " "
          default = options[:default].is_a?(Array) ? options[:default].shift : options.delete(:default)
          return translate(@locale.code, default, options.dup)
        end

        # The requested key might not be a parent node in a hierarchy of keys instead of a regular 'leaf' node
        #   that would simply result in a string return.  If so, check the database for possible children 
        #   and return them in a nested hash if we find them.
        #   We can safely ignore pluralization indeces here since they should never apply to a hash return
        if !entry && (key.is_a?(String) || key.is_a?(Symbol))
          #We need to escape % and \.  Rails will handle the rest.
          escaped_key = key.to_s.gsub('\\', '\\\\\\\\').gsub(/%/, '\%')
          children = @locale.translations.find :all, :conditions => ["raw_key like ?", "#{escaped_key}.%"]
          if children.size > 0
            entry = hashify_record_array(key.to_s, children)
            @cache_store.write(Translation.ck(@locale, key), entry) unless cache_lookup == true
            return entry
          end
        end

        # we check the database before creating a translation as we can have translations with nil values
        # if we still have no blasted translation just go and create one for the current locale!
        unless entry 
          pluralization_index = (options[:count].nil? || options[:count] == 1) ? 1 : 0
          translation =  @locale.translations.find_by_key_and_pluralization_index(Translation.hk(key), pluralization_index) ||
            @locale.create_translation(key, I18n.unescape_translation_key_without_scope(key), pluralization_index)
          entry = translation.value_or_default
        end

        # write to cache unless we've already had a successful cache hit
        @cache_store.write(Translation.ck(@locale, key), entry) unless cache_lookup == true

        entry = pluralize(@locale, entry, count)
        entry = interpolate(@locale.code, entry, values)
        entry.is_a?(Array) ? entry.dup : entry # array's can get frozen with cache writes
      end

      # override to fix Locale namespace
      def available_locales
        ::Locale.available_locales
      end
      
      protected

      # override from I18n::Backend::Database to cache DB locales
      def locale_in_context(locale)
        unless db_locale = @@cached_db_locales.find {|record| record.code == locale.to_s}
          # TODO: Locale should be scoped to I18n::Backend::Database::Locale to avoid 
          #       naming conflict with I18n::Locale module
          db_locale = ::Locale.find_by_code(locale.to_s)
          raise InvalidLocale.new(locale) unless db_locale
          @@cached_db_locales << db_locale
        end
        db_locale
      end

      # looks up translations for the default locale, and if they exist untranslated records are created for the locale and the default locale values are returned 
      def use_and_copy_default_locale_translations_if_they_exist(locale, key)
        default_locale_entry = lookup(::Locale.default_locale, key)
        return unless default_locale_entry

        if default_locale_entry.is_a?(Array)
          default_locale_entry.each_with_index do |entry, index|
            locale.create_translation(key, nil, index) if entry
          end
        else
          locale.create_translation(key, nil) 
        end

        return default_locale_entry
      end

      # override database backend
      #
      #  * add unescaping of namespace key syntax 
      #  * fix fetch nil values from cache
      #
      # e.g.
      #
      #   foo."Foo. And Bar."
      #
      def lookup(locale, key, scope=[], options={})
        cache_key = ::Translation.ck(locale, key)
        if @cache_store.exist?(cache_key)
          value = @cache_store.read(cache_key)
          return value.nil? ? nil : I18n.unescape_translation_key_without_scope(value)
        else
          translations = locale.translations.find_all_by_key(::Translation.hk(key))
          case translations.size
          when 0
            value = nil
          when 1
            value = translations.first.value_or_default
          else
            value = translations.inject([]) do |values, t| 
              values[t.pluralization_index] = t.value_or_default
              values
            end
          end
          @cache_store.write(cache_key, (value.nil? ? nil : value))
          return I18n.unescape_translation_key_without_scope(value)
        end
      end
      
    end
  end
end

