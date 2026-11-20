module NavigationLogin
  AUTH_URL = "https://auth.harvj.com/login"
  RETURN_PATH = %r{\A(?:/|/staging/(?:directory|pandemic)|/s/[a-zA-Z0-9_-]+(?:/replay)?)\z}

  def self.return_path(value)
    value if value.is_a?(String) && RETURN_PATH.match?(value)
  end
end
