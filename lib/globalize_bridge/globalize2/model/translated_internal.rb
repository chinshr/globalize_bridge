# extends Globalize2 with Globalize1 DB internal (keep_translations_in_model) translations 
module Globalize
  module Model
  
    # set in environment.rb 
    # Globalize::Model.keep_translations_in_model = true|false
    @@keep_translations_in_model = false
    mattr_reader :keep_translations_in_model
    mattr_writer :keep_translations_in_model
  
    module ActiveRecord

      module TranslatedInternal

        def self.included(base)
          raise "Globalize2 ist not installed or not loaded before GlobalizeBridge" unless base.respond_to?(:translates)
          base.extend ActMethods
          base.class_eval {
            class << self
              alias_method_chain :translates, :bridge
            end
          }
        end

        module ActMethods

          attr_accessor :keep_translations_in_model

          # Intersected translates macro triggers Globalize2 translate if 
          # translations are not inside the model, otherwise, uses model
          # internal translations
          def translates_with_bridge(*attr_names)
            return if included_modules.include? InstanceMethods
            
            options = attr_names.extract_options!
            options.reverse_merge!({:base_as_default => false})

            keep_internal = if self.keep_translations_in_model.nil?
              ::Globalize::Model.keep_translations_in_model
            else
              self.keep_translations_in_model
            end
            
            keep_internal ? translates_internal(attr_names, options) : translates_withouth_bridge(attr_names, options)
          end

          protected
      
          # Alternative storage mechanism storing the translations in the models'
          # own tables.
          #
          # E.g.
          #
          #   Globalize::Model.keep_translations_in_model = true
          #
          # or 
          #
          #   class Post < ActiveRecord::Base
          #     ...
          #     self.keep_translations_in_model = true
          #     ...
          #   end
          #
          def translates_internal(facets, options)
            class_inheritable_accessor :translated_attribute_names
            self.translated_attribute_names = facets.map(&:to_sym)

            include InstanceMethods

            #--- define class methods
            class_eval <<-STR
              @@facet_options = {}

              class << self

                alias_method :globalize_facets, :translated_attribute_names
                deprecate :globalize_facets => "Globalize1: You should use translated_attribute_names"

                # Returns the localized column name of the supplied attribute for the
                # current locale
                #
                # Useful when you have to build up sql by hand or for AR::Base::find conditions
                #
                # E.g.
                #
                #   Product.find(:all , :conditions = ["\#{Product.localized_facet(:name)} = ?", name])
                #
                # Note: <i>Used when Globalize::Model.keep_translations_in_model is true</i>
                #
                def translated_attribute_name(facet)
                  unless I18n.base_locale?
                    "\#{facet}_\#{I18n.locale_language}"
                  else
                    facet.to_s
                  end
                end
                alias_method :localized_facet, :translated_attribute_name
                deprecate :localized_facet => "Globalize1: You should use translated_attribute_name"
            
              end

              # Returns all attribute names that are not translated
              def none_translated_attribute_names
                columns.to_a.map {|a| a.name.to_sym} - translated_attribute_names
              end
              alias_method :non_localized_fields, :none_translated_attribute_names
              deprecate :non_localized_fields => "Globalize1: You should use none_translated_attribute_names"
          
              # Is field translated?
              # Returns true if translated
              def translated?(facet, locale_code = nil)
                localized_method = "\#{facet}_\#{I18n.locale_language}"

                I18n.switch_locale(locale_code || I18n.default_locale) do
                  localized_method = "\#{facet}_\#{I18n.locale_language}"
                end if locale_code

                value = send(localized_method.to_sym) if respond_to?(localized_method.to_sym)
                return !value.nil?
              end

              extend Globalize::Model::ActiveRecord::TranslatedInternal::InternalStorageClassMethods
            STR

            #--- define instance methods
            facets.each do |facet|
              bidi = (!(options[facet] && !options[facet][:bidi_embed])).to_s
              class_eval <<-STR

                # Handle facet-specific options (.e.g a bidirectional setting)
                @@facet_options[:#{facet}] ||= {}
                @@facet_options[:#{facet}][:bidi] = #{bidi}

                # Accessor that proxies to the right accessor for the current locale
                def #{facet}
                  value = nil
                  unless I18n.base_locale?
                    localized_method = "#{facet}_\#{I18n.locale_language}"
                    value = send(localized_method.to_sym) if respond_to?(localized_method.to_sym)
                    value = value ? value : read_attribute(["#{facet}".to_sym]) if #{options[:base_as_default]}
                  else
                    value = read_attribute(["#{facet}".to_sym])
                  end
                  value.nil? ? nil : add_bidi(value, "#{facet}".to_sym)
                end

                # Accessor before typecasting that proxies to the right accessor for the current locale
                def #{facet}_before_type_cast
                  unless I18n.base_locale?
                    localized_method = "#{facet}_\#{I18n.locale_language}_before_type_cast"
                    value = send(localized_method.to_sym) if respond_to?(localized_method.to_sym)
                    value = value ? value : read_attribute_before_type_cast("#{facet}".to_sym) if #{options[:base_as_default]}
                    return value
                  else
                    value = read_attribute_before_type_cast("#{facet}".to_sym)
                  end
                  value.nil? ? nil : add_bidi(value, "#{facet}".to_sym)
                end

                # Write to right localized attribute
                def #{facet}=(value)
                  unless I18n.base_locale?
                    localized_method = "#{facet}_\#{I18n.locale_language}"
                    write_attribute(localized_method.to_sym, value) if respond_to?(localized_method.to_sym)
                  else
                    write_attribute("#{facet}".to_sym, value)
                  end
                end

                # Returns true if untranslated
                def #{facet}_is_base?
                  localized_method = "#{facet}_\#{I18n.locale_language}"
                  value = send(localized_method.to_sym) if respond_to?(localized_method.to_sym)
                  return value.nil?
                end

                # Read base language attribute directly
                def _#{facet}
                  value = read_attribute("#{facet}".to_sym)
                  value.nil? ? nil : add_bidi(value, "#{facet}".to_sym)
                end

                # Read base language attribute directly without typecasting
                def _#{facet}_before_type_cast
                  read_attribute_before_type_cast("#{facet}".to_sym)
                end

                # Write base language attribute directly
                def _#{facet}=(value)
                  write_attribute("#{facet}".to_sym, value)
                end

                def add_bidi(value, facet)
                  value.direction = self.send("#{facet}_is_base?".to_sym) ?
                    (I18n.default_locale ? I18n.language_direction : nil) :
                    I18n.language_direction

                  # insert bidi embedding characters, if necessary
                  if @@facet_options[facet][:bidi] && I18n.locale && I18n.language_direction && value.direction
                    if I18n.language_direction == 'ltr' && value.direction == 'rtl'
                      bidi_str = "\xe2\x80\xab" + value + "\xe2\x80\xac"
                      bidi_str.direction = value.direction
                      return bidi_str
                    elsif I18n.language_direction == 'rtl' && value.direction == 'ltr'
                      bidi_str = "\xe2\x80\xaa" + value + "\xe2\x80\xac"
                      bidi_str.direction = value.direction
                      return bidi_str
                    end
                  end
                  return value
                end
                protected :add_bidi
                
              STR
            end

          end
        end

        module InstanceMethods
        end

        module InternalStorageClassMethods

          private

          # This method is deprecated on the latest stable version of Rails. 
          # The last existing version (v2.1.0) is shown here.
          def determine_finder(match)
            match.captures.first == 'all_by' ? :find_every : :find_initial
          end
          
          # This method is deprecated on the latest stable version of Rails. 
          # The last existing version (v2.1.0) is shown here.
          def extract_attribute_names_from_match(match)
            match.captures.last.split('_and_')
          end

          # Overridden to ensure that dynamic finders using localized attributes
          # like find_by_user_name(user_name) or find_by_user_name_and_password(user_name, password)
          # use the appropriately localized column.
          #
          # Note: <i>Used when Globalize::Model.keep_translations_in_model is true</i>
          def method_missing(method_id, *arguments)
            if match = /find_(all_by|by)_([_a-zA-Z]\w*)/.match(method_id.to_s)
              finder = determine_finder(match)

              facets = extract_attribute_names_from_match(match)
              super unless all_attributes_exists?(facets)

              # Overrride facets to use appropriate attribute name for current locale
              facets.collect! {|attr_name| respond_to?(:translated_attribute_names) && translated_attribute_names.include?(attr_name.intern) ? translated_attribute_name(attr_name) : attr_name}

              attributes = construct_attributes_from_arguments(facets, arguments)

              case extra_options = arguments[facets.size]
                when nil
                  options = {:conditions => attributes}
                  set_readonly_option!(options)
                  ActiveSupport::Deprecation.silence { send(finder, options) }
                when Hash
                  finder_options = extra_options.merge(:conditions => attributes)
                  validate_find_options(finder_options)
                  set_readonly_option!(finder_options)

                  if extra_options[:conditions]
                    with_scope(:find => { :conditions => extra_options[:conditions] }) do
                      ActiveSupport::Deprecation.silence { send(finder, finder_options) }
                    end
                  else
                    ActiveSupport::Deprecation.silence { send(finder, finder_options) }
                  end

                else
                  raise ArgumentError, "Unrecognized arguments for #{method_id}: #{extra_options.inspect}"
              end
            elsif match = /find_or_(initialize|create)_by_([_a-zA-Z]\w*)/.match(method_id.to_s)
              instantiator = determine_instantiator(match)
              facets = extract_attribute_names_from_match(match)
              super unless all_attributes_exists?(facets)

              if arguments[0].is_a?(Hash)
                attributes = arguments[0].with_indifferent_access
                find_attributes = attributes.slice(*facets)
              else
                find_attributes = attributes = construct_attributes_from_arguments(facets, arguments)
              end
              options = { :conditions => find_attributes }
              set_readonly_option!(options)

              find_initial(options) || send(instantiator, attributes)
            else
              super
            end
          end
        end
      end
    end
  end
end
ActiveRecord::Base.send(:include, Globalize::Model::ActiveRecord::TranslatedInternal)
