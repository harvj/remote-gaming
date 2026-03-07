module GameBuild
  class Base
    include ServiceObject

    USER_PASSWORD = 'gitter'.freeze

    DEFAULT_USERS = [
      { name: 'Jim Harvey',       username: 'jim' },
      { name: 'Paul Harvey',      username: 'paul' },
      { name: 'Bob McMurray',     username: 'bob' },
      { name: 'Robert McMurray',  username: 'robert' },
      { name: 'Mark McMurray',    username: 'mark' },
      { name: 'AJ Stoll',         username: 'aj' },
      { name: 'Nolan Harvey',     username: 'nolan' }
    ].freeze

    def call
      create_users
      add_game
    end

    private

    def create_users
      DEFAULT_USERS.each do |params|
        next if User.find_by(username: params[:username]).present?
        log("building User: #{params}")
        User.create!(params.merge(password: USER_PASSWORD))
      end
    end

    def create_game(params)
      log("building Game: #{params}")
      Game.create!(params)
    end

    def create_card(params)
      log("building Card: #{params}")
      Card.create!(params)
    end

    def create_role(params)
      log("building Role: #{params}")
      Role.create!(params)
    end
  end
end
