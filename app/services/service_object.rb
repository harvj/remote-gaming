module ServiceObject
  extend ActiveSupport::Concern
  include SimpleLog

  class_methods do
    def call(*args)
      new(*args).()
    end
  end

  attr_reader :subject, :errors

  def error(message)
    @errors ||= []
    log(message)
    @errors << message
  end

  def ok?
    @errors.blank?
  end
end
