module MJ
  class OpenAIClient
    include Generator

    def initialize(@api_key : String)
    end

    def name : String
      "openai"
    end

    def generate(request : GenerationRequest) : GenerationResult
      raise "OpenAI generator not yet implemented"
    end
  end
end
