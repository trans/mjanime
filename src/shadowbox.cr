require "kemal"

module MJ
  # Shadowbox: compose mj's props/backdrops into a parallax depth-layer scene, then play it.
  # See notes/shadowbox-plan.md.
  #
  # NAME IS CENTRALISED HERE. The URL slug and display title live in these two constants and nowhere
  # else — routes and the nav derive from them. Renaming the tool (e.g. to "Diorama") is a one-line
  # change here plus renaming the .ecr/.js files; there is no hardcoded "shadowbox" scattered through
  # the routes or templates.
  module Shadowbox
    SLUG  = "shadowbox" # URL base + asset/scene namespace
    TITLE = "Shadowbox" # display name in the nav

    def self.slug : String
      SLUG
    end

    def self.title : String
      TITLE
    end

    def self.register
      # Editor (P0 stub — full editor lands in P2).
      get "/#{SLUG}" do |env|
        render "src/views/shadowbox.ecr", "src/views/layout.ecr"
      end
    end
  end
end
