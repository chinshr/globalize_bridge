require 'csv'
require 'active_record'

def inject(columns, row)
  injected = {}
  columns.each_with_index do |column, index|
    injected[column.to_sym] = row[index] if column
  end
  injected
end

module Globalize1
  class Language < ::ActiveRecord::Base
    set_table_name "globalize_languages"
    def code; iso_639_1 || iso_639_3 || rfc_3066; end
  end
  class Translation < ::ActiveRecord::Base  # :nodoc:
    set_table_name "globalize_translations"    
    belongs_to :language, :class_name => "::Globalize1::Language"
    self.store_full_sti_class = false if defined?(ActiveRecord::Base.store_full_sti_class)
  end
  class ViewTranslation < Globalize1::Translation # :nodoc:
  end
end unless defined?(Globalize1::Language) || defined?(Globalize1::Translation)

namespace :globalize do

  #--- exporting
  
  desc "Export globalize view translations to CSV file"
  task :export do
    Rake::Task['globalize:export:languages'].invoke
    Rake::Task['globalize:export:translations'].invoke
  end

  namespace :export do

    desc "Export globalize languages to CSV"
    task :languages => :environment do 
      file_name = "db/globalize_languages.csv"
      puts "exporting globalize languages to #{file_name}..."

      translations = Globalize1::ViewTranslation.find(:all, :conditions => ["built_in = ?", false], :group => "language_id")
      file = File.open("#{RAILS_ROOT}/#{file_name}", 'wb')
      CSV::Writer.generate(file) do |csv|
        # header
        csv << ['language_code', 'english_name', 'native_name']

        # body
        translations.each do |translation|
          row = []
          row << translation.language.iso_639_1
          row << translation.language.english_name
          row << translation.language.native_name
          csv << row

          puts "* exporting code '#{translation.language.iso_639_1}' language '#{translation.language.english_name}'"
        end
      end
      file.close
      puts "done."
    end

    desc "Export globalize translations to CSV"
    task :translations => :environment do 
      file_name = "db/globalize_translations.csv"
      puts "exporting globalize translations to #{file_name}..."
      
      translations = Globalize1::ViewTranslation.find(:all, :conditions => ["built_in = ?", false],
        :order => 'language_id')
      file = File.open("#{RAILS_ROOT}/#{file_name}", 'wb')
      CSV::Writer.generate(file) do |csv|
        # header
        csv << ['tr_key', 'language_code', 'pluralization_index', 'text', 'namespace', 'built_in']

        # body
        translations.each do |translation|
          if translation.tr_key && !translation.tr_key.match(/---.\n/)
            row = []
            row << translation.tr_key
            row << translation.language.code
            row << translation.pluralization_index
            row << translation.text
            row << translation.namespace
            row << translation.built_in ? '1' : '0'

            csv << row
            puts "* exporting code #{translation.language.code} -> tr_key #{translation.tr_key} -> value #{translation.text} -> pluralization #{translation.pluralization_index}"
          else
            puts "** invalid translation key #{translation.tr_key}"
          end
        end
      end
      file.close
      puts "done."
    end

  end

  #--- importing
    
  desc "Import globalize CSV data to I18n::Backend::Database"
  task :import => :environment do
    Rake::Task['globalize:import:languages'].invoke
    Rake::Task['globalize:import:translations'].invoke
  end
  
  namespace :import do 
    desc "Import globalize languages to local"
    task :languages => :environment do
      file_name = "db/globalize_languages.csv"
      puts "importing from #{file_name}..."
      
      reader = CSV::Reader.parse(File.open("#{RAILS_ROOT}/#{file_name}", 'rb'), ',')
      columns = reader.shift.map {|column_name| column_name}

      reader.each_with_index do |row, index|
        next if row.first.nil? # skip blank lines
        row = inject(columns, row)
        
        unless @locale = ::Locale.find_by_code(row[:language_code])
          @locale = ::Locale.create!({:code => row[:language_code], :name => row[:native_name] || row[:english_name]})
          puts "* code '#{row[:language_code]}' language '#{row[:english_name]}' added"
        else
          puts "** code '#{row[:language_code]}' language '#{row[:english_name]}' already exists"
        end
      end
      puts "done."
    end
    
    desc "Import globalize translations to local"
    task :translations => :environment do
      file_name = "db/globalize_translations.csv"
      puts "importing from #{file_name}..."
      
      reader = CSV::Reader.parse(File.open("#{RAILS_ROOT}/#{file_name}", 'rb'), ',')
      columns = reader.shift.map {|column_name| column_name}

      reader.each_with_index do |row, index|
        next if row.first.nil? # skip blank lines
        row = inject(columns, row)

        # ['tr_key', 'language_code', 'pluralization_index', 'text', 'namespace', 'built_in']
        if @locale = ::Locale.find_by_code(row[:language_code])
          raw_key = row[:tr_key]

=begin          
          # convert %{foo} to {{foo}}
          while raw_key.match(/%\{([a-z,0-9,_]*)\}/i) {}
            raw_key.gsub!(/%\{([a-z,0-9,_]*)\}/i, "{{#{$1}}}")
          end
=end

          # converting globalize pluralization syntax %d to {{count}}
          while raw_key.match(/%d/)
            raw_key.gsub!(/%d/, '{{count}}')
          end

          # setup values 
          pluralization_index = row[:pluralization_index] ? row[:pluralization_index].to_i : 1
          value = row[:text].blank? ? nil : row[:text]
          namespace = row[:namespace].blank? ? nil : row[:namespace]
          
          # escape to key
          key = if namespace
            I18n.escape_translation_key(raw_key, namespace)
          elsif raw_key.index(I18n.default_separator)
            I18n.escape_translation_key(raw_key)
          else
            raw_key
          end
          
          if !raw_key.blank? && !value.blank?
            unless @locale.translations.find_by_raw_key_and_pluralization_index(key, pluralization_index)
              @locale.translations.create!({:key => key, :raw_key => key.to_s, 
                :value => value, :pluralization_index => pluralization_index})
              puts "* added code -> #{@locale.code} raw_key -> #{raw_key} -> key: #{key} -> value #{value} -> pluralization: #{pluralization_index}"
            else
              puts "** translation exists code -> #{@locale.code} raw_key -> #{raw_key} -> pluralization -> #{pluralization_index}"
            end
          end
        else
          puts "** missing locale '#{row[:language_code]}'"
        end
      end
      puts "done."
    end
  end
  
end