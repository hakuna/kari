# frozen_string_literal: true

BEFORE = %w(db:drop)
AFTER = %w(db:migrate db:create db:seed db:rollback db:migrate:up db:migrate:down)

Rake::Task.tasks.each do |task|
  next unless task.scope.path == 'db'
  task.enhance(['saloon:init'])
end

def inserted_task_name(task_name)
  "saloon:#{task_name.split(':', 2).last}"
end

BEFORE.each do |task_name|
  task = Rake::Task[task_name]
  task.enhance([inserted_task_name(task_name)])
end

AFTER.each do |task_name|
  task = Rake::Task[task_name]
  task.enhance do
    Rake::Task[inserted_task_name(task_name)].invoke
  end
end

namespace :saloon do
  desc 'Initialize'
  task :init do
    Saloon.current_schema = Saloon.configuration.global_schema
  end

  desc 'Create all schemas'
  task :create do
    Saloon.each_schema do |schema|
      unless Saloon.schema_exists?(schema)
        puts "Create schema #{schema}"
        Saloon.create_schema(schema)
      else
        puts "Schema #{schema} does already exist, cannot create"
      end
    end
  end

  desc 'Drop all schemas'
  task :drop do
    Saloon.each_schema do |schema|
      if Saloon.schema_exists?(schema)
        puts "Drop schema #{schema}"
        Saloon.drop_schema(schema)
      else
        puts "Schema #{schema} does not exist, cannot drop"
      end
    end
  end

  desc 'Migrate all schemas'
  task :migrate do
    Saloon.each_schema do |schema|
      if Saloon.schema_exists?(schema)
        puts "Migrate schema #{schema}"
        Saloon.process(schema) do
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      else
        puts "Schema #{schema} does not exist, cannot migrate"
      end
    end
  end

  desc 'Seed all schemas'
  task :seed do
    Saloon.each_schema do |schema|
      if Saloon.schema_exists?(schema)
        puts "Seed schema #{schema}"
        Saloon.seed_schema(schema)
      else
        puts "Schema #{schema} does not exist, cannot seed"
      end
    end
  end

  desc 'Rolls schemas back to the previous version (specify steps w/ STEP=n)'
  task :rollback do
    step = ENV['STEP']&.to_i || 1

    Saloon.each_schema do |schema|
      if Saloon.schema_exists?(schema)
        puts "Rolling back schema #{schema}"
        Saloon.process(schema) do
          ActiveRecord::Base.connection.migration_context.rollback(step)
        end
      else
        puts "Schema #{schema} does not exist, cannot rollback"
      end
    end
  end

  namespace :migrate do
    desc 'Runs the "up" for a given migration VERSION across all schemas'
    task :up do
      version = ActiveRecord::Tasks::DatabaseTasks.target_version

      Saloon.each_schema do |schema|
        if Saloon.schema_exists?(schema)
          puts "Migrate schema #{schema} up to #{version}"
          Saloon.process(schema) do
            ActiveRecord::Base.connection.migration_context.run(:up, version)
          end
        else
          puts "Schema #{schema} does not exist, cannot migrate up"
        end
      end
    end

    desc 'Runs the "down" for a given migration VERSION across all schemas'
    task :down do
      version = ActiveRecord::Tasks::DatabaseTasks.target_version

      Saloon.each_schema do |schema|
        if Saloon.schema_exists?(schema)
          puts "Migrate schema #{schema} down to #{version}"
          Saloon.process(schema) do
            ActiveRecord::Base.connection.migration_context.run(:down, version)
          end
        else
          puts "Schema #{schema} does not exist, cannot migrate down"
        end
      end
    end
  end
end
