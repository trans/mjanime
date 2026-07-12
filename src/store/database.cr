require "db"
require "sqlite3"

module MJ
  module Database
    @@db : DB::Database? = nil

    def self.db : DB::Database
      @@db.not_nil!
    end

    def self.setup!
      Dir.mkdir_p(Config.data_dir)
      db_path = File.join(Config.data_dir, "mj.db")
      @@db = DB.open("sqlite3://#{db_path}?journal_mode=wal&synchronous=normal&foreign_keys=on")
      migrate!
      cleanup_stale_jobs!
    end

    private def self.cleanup_stale_jobs!
      db.exec(
        "UPDATE render_jobs SET status = 'error', error_message = 'Server restarted' WHERE status IN ('pending', 'running')"
      )
    end

    private def self.migrate!
      db.exec <<-SQL
        CREATE TABLE IF NOT EXISTS cuts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          slug TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL

      db.exec <<-SQL
        CREATE TABLE IF NOT EXISTS frames (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cut_id INTEGER NOT NULL REFERENCES cuts(id),
          frame_number INTEGER NOT NULL,
          scene TEXT NOT NULL,
          prompt TEXT NOT NULL,
          seed_image TEXT NOT NULL,
          model TEXT NOT NULL,
          strength REAL NOT NULL,
          width INTEGER NOT NULL,
          height INTEGER NOT NULL,
          task_uuid TEXT,
          api_response_id TEXT,
          generated_at TEXT NOT NULL,
          generation_time_ms INTEGER NOT NULL,
          UNIQUE(cut_id, frame_number)
        )
      SQL

      db.exec <<-SQL
        CREATE TABLE IF NOT EXISTS render_jobs (
          id TEXT PRIMARY KEY,
          cut_id INTEGER NOT NULL REFERENCES cuts(id),
          total_frames INTEGER NOT NULL,
          current_frame INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          error_message TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      SQL
    end
  end
end
