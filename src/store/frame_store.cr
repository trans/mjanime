module Minanime
  class FrameStore
    def save_frame(cut_path : String, cut_id : Int64, frame_number : Int32,
                   image_data : Bytes, metadata : FrameMetadata) : String
      frames_dir = File.join(cut_path, "frames")
      Dir.mkdir_p(frames_dir)

      padded = "%04d" % frame_number
      png_path = File.join(frames_dir, "#{padded}.png")

      File.write(png_path, image_data)

      Database.db.exec(
        <<-SQL,
          INSERT OR REPLACE INTO frames
            (cut_id, frame_number, scene, prompt, seed_image, model, strength,
             width, height, task_uuid, api_response_id, generated_at, generation_time_ms)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        cut_id, metadata.frame_number, metadata.scene, metadata.prompt,
        metadata.seed_image, metadata.model, metadata.strength,
        metadata.width, metadata.height, metadata.task_uuid,
        metadata.api_response_id, metadata.generated_at.to_s, metadata.generation_time_ms
      )

      png_path
    end

    def load_frame_metadata(cut_id : Int64, frame_number : Int32) : FrameMetadata?
      row = Database.db.query_one?(
        <<-SQL,
          SELECT frame_number, scene, prompt, seed_image, model, strength,
                 width, height, task_uuid, api_response_id, generated_at, generation_time_ms
          FROM frames WHERE cut_id = ? AND frame_number = ?
        SQL
        cut_id, frame_number,
        as: {Int32, String, String, String, String, Float64,
             Int32, Int32, String?, String?, String, Int64}
      )
      return nil unless row
      FrameMetadata.new(
        frame_number: row[0], scene: row[1], prompt: row[2], seed_image: row[3],
        model: row[4], strength: row[5], width: row[6], height: row[7],
        task_uuid: row[8] || "", generated_at: Time.parse_utc(row[10], "%F %T"),
        generation_time_ms: row[11], api_response_id: row[9]
      )
    end

    def list_frames(cut_id : Int64) : Array(Int32)
      Database.db.query_all(
        "SELECT frame_number FROM frames WHERE cut_id = ? ORDER BY frame_number",
        cut_id,
        as: Int32
      )
    end

    def clear_frames(cut_path : String, cut_id : Int64)
      Database.db.exec("DELETE FROM frames WHERE cut_id = ?", cut_id)
      frames_dir = File.join(cut_path, "frames")
      if Dir.exists?(frames_dir)
        Dir.each_child(frames_dir) do |child|
          File.delete(File.join(frames_dir, child)) if child.ends_with?(".png")
        end
      end
    end
  end
end
