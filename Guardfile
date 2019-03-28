# Guardfile for flex_hash

directories %w(lib spec) \
  .select{|d| Dir.exist?(d) ? d : UI.warning("Directory #{d} does not exist")}

guard :rspec, cmd: "CODE_COVERAGE=1 bundle exec rspec" do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  # Feel free to open issues for suggestions and improvements

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files)

  # Ruby files
  ruby = dsl.ruby
  dsl.watch_spec_files_for(ruby.lib_files)
end

guard 'yard' do
  watch(%r{lib\/.+\.rb})
  watch('README.md')
end
