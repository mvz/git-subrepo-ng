# frozen_string_literal: true

SimpleCov.start do
  add_group "Main", "lib"
  add_group "Specs", "spec"
  add_group "Cuke support", "features"
  enable_coverage :branch
end
