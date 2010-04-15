module GlobalizeBridge # :nodoc:
  module CoreExtensions # :nodoc:
    module String

      def self.included(base)
        base.class_eval {
          alias_method :format_without_extension, :%
          alias_method :%, :format_with_extension
        }
      end
      
      # Indicates direction of text (usually +ltr+ [left-to-right] or
      # +rtl+ [right-to-left].
      attr_accessor :direction

      # Translates the string into the active language. If there is a
      # quantity involved, it can be set with the +arg+ parameter. In this case
      # string should contain the code <tt>%d</tt>, which will be substituted with
      # the supplied number.
      #
      # To substitute a +string+, give it as the +arg+ parameter. It will be
      # substituted for <tt>%s</dd>.
      #
      # If there is no translation available, +default+ will be returned, or
      # if it's not supplied, the original string will be returned.
      #
      # Note:
      #
      # As most Globalize applications may use human readable translation keys,
      # like "Foo. And Bar.".t, where sentences are separated by periods ("."),
      # we must make sure that those are not mistaken for the scope seperator.
      #
      # E.g.
      #          <tt>"draw".t -> "dibujar"</tt>
      #
      def translate(default = nil, arg = nil, namespace = nil)
        options = {:default => default, :count => arg, :scope => namespace}.reject! {|k,v| v.blank?}
        # there is a namespace and found a scope default separator in the key,
        # so we need to escape the string to e.g. foo."Foo. And Bar."
        if self.index(I18n.default_separator)
          options.delete(:scope)
          I18n.t(I18n.escape_translation_key(self, namespace), options)
        else
          I18n.t(self, options)
        end
      end
      alias :t :translate

      # Translates the string into the active language using the supplied namespace.
      #
      # E.g.
      #
      #          <tt>"draw".tn(:lottery) -> "seleccionar"</tt>
      #
      def translate_with_namespace(namespace, arg = nil, default = nil)
        options = {:default => default, :count => arg, :scope => namespace}.reject! {|k,v| v.blank?}
        if self.index(I18n.default_separator)
          options.delete(:scope)
          I18n.t(I18n.escape_translation_key(self, namespace), options)
        else
          I18n.t(self, options)
        end
      end
      alias :tn :translate_with_namespace

      # Translates the string into the active language using the supplied namespace.
      # This is equivalent to translate_with_namespace(arg).
      #
      # Example:
      #          <tt>"draw".t #-> "dibujar"</tt>
      #          <tt>"draw" >> 'lottery' #-> "seleccionar"</tt>
      def >>(namespace)
        translate_with_namespace(namespace, nil, nil)
      end

      # Translates the string into the active language. This is equivalent
      # to translate(arg).
      #
      # Example: <tt>"There are %d items in your cart" / 1 -> "There is one item in your cart"</tt>
      #
      # Note: In order for this to work in I18n, the %d in the translation string
      #       needs to be replaced with {{count}}
      #
      def /(arg)
        translate(nil, arg)
      end

      # % string format
      #
      # E.g.
      # 
      #   "fox jumps on %{animal}" % {:animal => "chicken"} --> "fox jumps on chicken"
      #
      # Format - Uses str as a format specification, and returns the result of applying it to arg. 
      # If the format specification contains more than one substitution, then arg must be 
      # an Array containing the values to be substituted. See Kernel::sprintf for details of the 
      # format string. This is the default behavior of the String class.
      #
      # * arg: an Array or other class except Hash.
      # * Returns: formatted String
      #
      # E.g.
      #
      #  "%s, %s" % ["Masao", "Mutoh"]  -->  "Masao, Mutoh"
      #
      # Also you can use a Hash as the "named argument". This is recommanded way for Ruby-GetText
      # because the translators can understand the meanings of the msgids easily.
      #
      # * hash: {:key1 => value1, :key2 => value2, ... }
      # * Returns: formatted String
      #
      # E.g.
      #
      #   "%{firstname}, %{familyname}" % {:firstname => "Masao", :familyname => "Mutoh"} --> "Masao Mutoh"
      #   "{firstname}, {familyname}" % {:firstname => "Masao", :familyname => "Mutoh"} --> "Masao Muto"
      #   "{{firstname}}, {{familyname}}" % {:firstname => "Masao", :familyname => "Mutoh"} --> "Masao Muto"
      # 
      # Note: This code was derived from gettext string.rb package and adopted for GlobalizeBridge. 
      #       We allow {arg}, {{arg}}, %{} and ${arg} interpolation.
      #
      def format_with_extension(args)
        if args.kind_of?(Hash)
          ret = dup
          args.each do |key, value|
            # e.g. "%{arg}"
            if ret =~ /\%\{#{key}\}/
              ret.gsub!(/\%\{#{key}\}/, value.to_s)
            end
            # e.g. "{{arg}}"
            if ret =~ /\{\{#{key}\}\}/
              ret.gsub!(/\{\{#{key}\}\}/, value.to_s)
            end
            # e.g. "${arg}"
            if ret =~ /\$\{#{key}\}/
              ret.gsub!(/\$\{#{key}\}/, value.to_s)
            end
            # e.g. "{arg}"
            if ret =~ /\{#{key}\}/
              ret.gsub!(/\{#{key}\}/, value.to_s)
            end
          end
          ret
        else
          ret = gsub(/%\{/, '%%{')
          ret.format_without_extension(args)
        end
      end

    end

    module Symbol

      # Translates the symbol into the active language. Underscores are
      # converted to spaces.
      #
      # If there is no translation available, +default+ will be returned, or
      # if it's not supplied, the original string will be returned.
      def translate(default = nil, namespace = nil)
        I18n.t(self, {:default => default, :scope => namespace}.reject! {|k,v| v.blank?})
      end
      alias :t :translate

    end

    module Object

      # Translates the supplied string into the active language. If there is a
      # quantity involved, it can be set with the +arg+ parameter. In this case
      # string should contain the code <tt>%d</tt>, which will be substituted with
      # the supplied number.
      #
      # If there is no translation available, +default+ will be returned, or
      # if it's not supplied, the original string will be returned.
      #
      # <em>Note: This method is deprectated and is supplied for backward
      # compatibility with other translation packages, notable gettext.</em>
      def _(key, default = nil, arg = nil)
        I18n.t(key, {:default => default, :count => arg}.reject! {|k,v| v.blank?})
      end

    end

    module Integer
      # Returns the integer in String form, according to the rules of the
      # currently active locale.
      def localize(base = 10)
        str = self.to_s(base)
        if (base==10)
          if defined?(I18n) && I18n.locale
            delimiter = I18n.t("number.format.delimiter", :raise => true) rescue ',' 
            number_grouping_scheme = I18n.t("number.format.grouping_scheme", :raise => true) rescue :western
          end
          delimiter ||= ','
          number_grouping_scheme ||= :western
          number_grouping_scheme == :indian ?
            str.gsub(/(\d)(?=((\d\d\d)(?!\d))|((\d\d)+(\d\d\d)(?!\d)))/) {|match|
              match + delimiter} :
            str.gsub(/(\d)(?=(\d\d\d)+(?!\d))/) {|match| match + delimiter}
        else
          str
        end
      end
      alias :loc :localize
    end

    module Float
    
      # Returns the integer in String form, according to the rules of the
      # currently active locale.
      #
      # Example: <tt>123456.localize -> 123.456</tt> (German locale)
      def localize
        str = self.to_s
        if str =~ /^[\d\.]+$/
          if defined?(I18n) && I18n.locale
            delimiter = I18n.t("number.format.delimiter", :raise => true) rescue ','
            decimal   = I18n.t("number.format.separator", :raise => true) rescue '.'
            number_grouping_scheme = I18n.t("number.format.grouping_scheme", :raise => true) rescue :western
          end
          delimiter ||= ','
          decimal   ||= '.'
          number_grouping_scheme ||= :western

          int, frac = str.split('.')
          number_grouping_scheme == :indian ?
            int.gsub!(/(\d)(?=((\d\d\d)(?!\d))|((\d\d)+(\d\d\d)(?!\d)))/) { |match|
              match + delimiter} :
            int.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/) { |match| match + delimiter }
          int + decimal + frac
        else
          str
        end
      end
      alias :loc :localize
    
    end

    module Time
    
      # Acts the same as #strftime, but returns a localized version of the
      # formatted date/time string.
      def localize(format=:default)
        I18n.l(self, :format => format || :default)
      end
      alias :loc :localize
    
    end

    module Date
    
      # Acts the same as #strftime, but returns a localized version of the
      # formatted date/time string.
      def localize(format=:default)
        I18n.l(self, :format => format || :default)
      end
      alias :loc :localize
    
    end

  end
end
