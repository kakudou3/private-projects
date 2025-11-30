class BudgiiiRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :budgiii }
end
