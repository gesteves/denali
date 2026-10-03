require 'rake'

# Runs a rake task in a spec. Tasks are loaded once, and re-enabled before each
# run so the same task can be invoked by several examples.
module RakeHelpers
  def run_task(name, env = {})
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task[name]
    task.reenable
    output = StringIO.new
    original_env = env.keys.to_h { |key| [key, ENV[key]] }
    env.each { |key, value| ENV[key] = value }
    $stdout = output
    task.invoke
    output.string
  ensure
    $stdout = STDOUT
    original_env&.each { |key, value| ENV[key] = value }
  end
end

RSpec.configure do |config|
  config.include RakeHelpers, type: :task
end
