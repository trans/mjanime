module MJ
  # Stage 2 of template-guided generation: a plain "bed" master -> a decorated variation.
  # The master is passed as a reference image and Nano Banana 2 redraws it in the requested
  # style/theme. An optional style-reference image steers the look (the two-reference recipe:
  # subject + style). This is the seam that turns one master into many themed venues.
  module Decorate
    def self.build_prompt(spec : DecorateSpec) : String
      if spec.keep_structure
        "Keeping the same overall structure, silhouette, proportions and layout, redraw " \
        "this decorated in the following style and theme: #{spec.prompt}"
      else
        spec.prompt
      end
    end

    # master_bytes = the image to decorate; style_ref = optional style-reference image.
    def self.generate(client : RunwareClient, master_bytes : Bytes, spec : DecorateSpec,
                      style_ref : Bytes? = nil) : Bytes
      refs = style_ref ? [master_bytes, style_ref] : [master_bytes]
      client.edit_references(refs, build_prompt(spec), spec.width, spec.height, spec.model).image_data
    end
  end
end
