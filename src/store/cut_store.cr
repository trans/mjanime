module MJ
  module CutStore
    record Cut, id : Int64, slug : String, name : String, created_at : String

    def self.cuts_dir : String
      File.join(Config.data_dir, "cuts")
    end

    def self.cut_path(slug : String) : String
      File.join(cuts_dir, slug)
    end

    def self.create_cut(slug : String, name : String) : Cut
      path = cut_path(slug)
      Dir.mkdir_p(path)
      Dir.mkdir_p(File.join(path, "frames"))

      Database.db.exec(
        "INSERT INTO cuts (slug, name) VALUES (?, ?)",
        slug, name
      )

      get_cut(slug).not_nil!
    end

    def self.list_cuts : Array(Cut)
      Database.db.query_all(
        "SELECT id, slug, name, created_at FROM cuts ORDER BY created_at DESC",
        as: {Int64, String, String, String}
      ).map { |row| Cut.new(id: row[0], slug: row[1], name: row[2], created_at: row[3]) }
    end

    def self.get_cut(slug : String) : Cut?
      row = Database.db.query_one?(
        "SELECT id, slug, name, created_at FROM cuts WHERE slug = ?",
        slug,
        as: {Int64, String, String, String}
      )
      return nil unless row
      Cut.new(id: row[0], slug: row[1], name: row[2], created_at: row[3])
    end

    def self.get_cut_id(slug : String) : Int64?
      Database.db.query_one?(
        "SELECT id FROM cuts WHERE slug = ?",
        slug,
        as: Int64
      )
    end
  end
end
