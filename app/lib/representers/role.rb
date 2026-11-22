module Representers
  class Role < Representers::Base
    include ActionView::Helpers::AssetTagHelper

    def build_object(role)
      @role = role
      {
        id: role.id,
        imagePath: role_image_path,
        name: role.name,
        color: role.color
      }
    end

    attr_reader :role

    private

    def role_image_filename
      "#{[ role.game.key, role.name.parameterize ].join('/')}.png"
    end

    def role_image_path
      if role.game.key == "modern_art"
        return asset_path(role_image_filename) if %w[berlin bilbao new-york paris tokyo].include?(role.name.parameterize)
        return
      end

      return unless File.exist?(File.join(Rails.root, "app/assets/", image_path(role_image_filename)))
      "/assets#{asset_path(role_image_filename)}"
    end
  end
end
