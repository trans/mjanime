module MJ
  class Renderer
    def initialize(@generator : Generator, @store : FrameStore)
      @chain = FrameChain.new(@generator, @store)
    end

    def start_render(cut_slug : String, script : MotionScript) : String
      cut_id = CutStore.get_cut_id(cut_slug)
      raise "Cut not found: #{cut_slug}" unless cut_id

      job_id = UUID.random.to_s

      Database.db.exec(
        "INSERT INTO render_jobs (id, cut_id, total_frames, status) VALUES (?, ?, ?, ?)",
        job_id, cut_id, script.total_frames, "running"
      )

      spawn do
        begin
          cut_path = CutStore.cut_path(cut_slug)
          STDERR.puts "[render] Starting job #{job_id} for #{cut_slug} (#{script.total_frames} frames)"
          @store.clear_frames(cut_path, cut_id)
          STDERR.puts "[render] Cleared old frames"
          @chain.render(cut_path, cut_id, script) do |current, total|
            STDERR.puts "[render] Frame #{current}/#{total} complete"
            Database.db.exec(
              "UPDATE render_jobs SET current_frame = ? WHERE id = ?",
              current, job_id
            )
          end
          Database.db.exec(
            "UPDATE render_jobs SET status = 'done' WHERE id = ?",
            job_id
          )
          STDERR.puts "[render] Job #{job_id} done"
        rescue ex
          STDERR.puts "[render] Job #{job_id} error: #{ex.message}"
          Database.db.exec(
            "UPDATE render_jobs SET status = 'error', error_message = ? WHERE id = ?",
            ex.message, job_id
          )
        end
      end

      job_id
    end

    def get_job(job_id : String) : RenderJob?
      row = Database.db.query_one?(
        <<-SQL,
          SELECT rj.id, c.slug, rj.total_frames, rj.current_frame, rj.status, rj.error_message
          FROM render_jobs rj
          JOIN cuts c ON c.id = rj.cut_id
          WHERE rj.id = ?
        SQL
        job_id,
        as: {String, String, Int32, Int32, String, String?}
      )
      return nil unless row

      job = RenderJob.new(row[0], row[1], row[2])
      job.current_frame = row[3]
      job.status = RenderJob::Status.parse(row[4])
      job.error_message = row[5]
      job
    end
  end
end
