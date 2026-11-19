errors = GameCatalogAudit.call
abort errors.join("\n") unless errors.empty?

puts "Modern Art and Pandemic gameplay reference data verified"
