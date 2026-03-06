class ApplicationRecord < ActiveRecord::Base
  include SimpleLog
  self.abstract_class = true
end
