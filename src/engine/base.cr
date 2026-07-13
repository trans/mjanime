module MJ
  # Stage 1 of template-guided generation: a rudimentary flat-colour template -> a plain,
  # structurally-faithful "base" (the master). img2img off the template; strength is the
  # plain<->rich-structure knob. No ControlNet (optional future addition per the decision
  # rule: only needed if a denoise sweep shows *local* warping, not just global drift).
  module Base
    def self.generate(client : RunwareClient, template_path : String, spec : BaseSpec) : GenerationResult
      raise "Template not found: #{template_path}" unless File.exists?(template_path)
      tmpl = CanvasUtil.from_png_file(template_path)
      request = GenerationRequest.new(
        prompt: spec.prompt,
        seed_image: template_path,
        seed_is_uuid: false,
        width: tmpl.width,
        height: tmpl.height,
        model: spec.model,
        strength: spec.strength,
        steps: spec.steps,
        cfg_scale: spec.cfg_scale,
        negative_prompt: spec.negative_prompt
      )
      client.generate(request)
    end
  end
end
