class Query::Base
  include ServiceObject

  def initialize(query_name, params = {})
    @query_name = query_name
    @params = params
  end

  attr_reader :query_name, :params

  def call
    send(query_name)
  end
end
