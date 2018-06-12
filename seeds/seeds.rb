require 'rainbow'
require 'csv'
require 'activerecord-import/base'
require 'activerecord-import/active_record/adapters/postgresql_adapter'

module Seeds
  module_function

  def populate(klass, with:, dynamic_attributes: {}, exclude_from_search: [])

    header(klass.to_s.pluralize)

    with.map! do |attributes|
      puts attributes.reject { |k, v| v.is_a?(ActiveRecord::Base) }

      klass.find_by(attributes.except(*exclude_from_search)) ||
        klass.create!(attributes.merge(dynamic_attributes))
    end
  end

  def header(title)
    puts "\n\n#{separator}\n#{Rainbow(title).yellow}\n#{separator}"
  end

  def finish
    message = Rainbow('Success! c(^.^c)').green

    puts "\n\n#{message}\n\n"
  end

  def separator
    Rainbow('=' * 60).blue
  end

  def import_from_csv(dataset)
    file = Rails.root.join('datasets', "#{dataset}.csv")
    klass = dataset.classify.constantize

    return if klass.count > 0

    print "\rImporting #{dataset.pluralize}..."

    klass.transaction do
      rows = CSV.read(file)
      headers = rows.delete_at(0)
      klass.import(headers, rows, validate: false)
    end

    puts "\rImported #{dataset.pluralize}: #{klass.count}"
  end

  def find_or_create_user(attributes)
    puts attributes.slice(:email, :username, :password)

    User.find_by(attributes.except(:password, :password_confirmation)) ||
      User.create!(attributes)
  end

  def run_development_seeds?
    Rails.env.development? || ENV['RUN_DEVELOPMENT_SEEDS']
  end

  def database_stats
    non_user_tables = ['schema_migrations', 'ar_internal_metadata']

    print_table = proc do |table, count|
      table_name = Rainbow((table + ':').ljust(35, ' ')).yellow
      count = count > 0 ? Rainbow(count).green : Rainbow(count).red

      puts "\t#{table_name} #{count}\n"
    end

    header "Database Statistics"

    ActiveRecord::Base.connection
                      .tables
                      .reject { |x| non_user_tables.include?(x) }
                      .reduce({}) { |mem, x| mem.update(x => count_table(x)) }
                      .sort_by { |x| x[1] }
                      .reverse
                      .to_h
                      .map(&print_table)
  end

  def count_table(table)
    ActiveRecord::Base.connection
                      .exec_query("SELECT count(1) FROM #{table}")
                      .rows
                      .first[0]
  end
end

include Seeds

ActiveRecord::Base.logger.level = Logger::INFO

require_relative 'seeds/production'
require_relative 'seeds/development' if run_development_seeds?

database_stats
finish
