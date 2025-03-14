# frozen_string_literal: true

Scheduler::Defer.stop!(finish_work: false)
Discourse::Application.load_tasks

begin
  redis = TemporaryRedis.new
  redis.start
  Discourse.redis = redis.instance
  db = TemporaryDb.new
  db.start
  db.migrate

  db.with_env do
    if ENV["THEME_ARCHIVE"]
      puts "installing theme"
      Rake::Task["themes:install:archive"].invoke

      theme = Theme.last
      manager = Stylesheet::Manager.new(theme_id: theme.id)

      puts "checking deprecations"

      Stylesheet::Importer::THEME_TARGETS.each do |target|
        builder = Stylesheet::Manager::Builder.new(target: target.to_sym, theme:, manager:)
        builder.compile(force: true)[...100]
      end
    else
      name = ENV["PLUGIN_NAME"].strip

      [nil, :desktop, :mobile, :color_definitions].each do |target|
        next if !DiscoursePluginRegistry.stylesheets_exists?(name, target)

        builder =
          Stylesheet::Manager::Builder.new(
            target: target ? "#{name}_#{target}" : name,
            manager: nil,
          )
        builder.compile(force: true)[...100]
      end

      if DiscoursePluginRegistry.color_definition_stylesheets.keys.include?(name)
        Stylesheet::Compiler.compile_asset(Stylesheet::Manager::COLOR_SCHEME_STYLESHEET)
      end
    end
  end
ensure
  Scheduler::Defer.stop!(finish_work: false)
  db&.stop
  db&.remove
  redis&.remove
end
