module SimpleLog
  extend ActiveSupport::Concern

  def log(msg, level=:info)
    self.class.log(msg, level)
  end

  module ClassMethods
    def log(msg, level=:info)
      msg = "[#{name}] #{msg}"
      puts msg unless Rails.env.test?
      Rails.logger.send(level, msg)
    end
  end
end
