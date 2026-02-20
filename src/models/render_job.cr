module Minanime
  class RenderJob
    enum Status
      Pending
      Running
      Done
      Error
    end

    property id : String
    property cut_slug : String
    property total_frames : Int32
    property current_frame : Int32 = 0
    property status : Status = Status::Pending
    property error_message : String? = nil

    def initialize(@id, @cut_slug, @total_frames)
    end

    def progress_percent : Int32
      return 0 if total_frames == 0
      ((current_frame.to_f / total_frames) * 100).to_i
    end
  end
end
