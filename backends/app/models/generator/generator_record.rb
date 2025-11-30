class GeneratorRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :generator }
end
