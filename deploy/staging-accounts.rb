abort "Use the private staging environment" unless Rails.env.production? && ModernArtStaging.enabled?
actual = User.connection.select_rows("SELECT current_database(), current_user")
expected = [ [ ModernArtStaging::DATABASE, ModernArtStaging::DATABASE ] ]
abort "Unexpected database or role" unless actual == expected

accounts = User.transaction do
  if User.exists?(username: ModernArtStaging::ACCOUNTS)
    abort "Staging usernames already exist. Preserve the existing records and use the staged credentials."
  end

  ModernArtStaging::ACCOUNTS.map.with_index(1) do |username, index|
    password = SecureRandom.hex(24)
    User.create!(username: username, name: "Private staging player #{index}", password: password)
    [ username, password ]
  end
end

accounts.each { |username, password| puts "#{username} #{password}" }
