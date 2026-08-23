module MJ
  # Cost ledger for paid API calls. Runware reports a per-task `cost` (USD) when a
  # task asks for it with `includeCost`; every billed call is tallied for the run and
  # appended as one JSONL row to a persistent ledger, so spend is visible per-call,
  # per-run and over time (`mj spend`).
  #
  #   ledger  $MJ_SPEND_LOG, else $XDG_DATA_HOME/mj/spend.jsonl
  #   off     MJ_SPEND_LOG=0 — no ledger row is written (the run tally still prints)
  #
  # A row: {"t","cmd","provider","task","model","cost","w","h"} — cost may be null if
  # the provider returned none (never silently counted as free; see `unpriced`).
  module Spend
    extend self

    struct Entry
      getter time : Time
      getter command : String
      getter provider : String
      getter task : String
      getter model : String
      getter cost : Float64?

      def initialize(@time, @command, @provider, @task, @model, @cost)
      end
    end

    @@session_cost = 0.0
    @@session_calls = 0
    @@session_unpriced = 0
    @@hooked = false

    def session_cost : Float64
      @@session_cost
    end

    def session_calls : Int32
      @@session_calls
    end

    def session_unpriced : Int32
      @@session_unpriced
    end

    def ledger_path : String
      ENV["MJ_SPEND_LOG"]? || File.join(Config.xdg_data_home, "mj", "spend.jsonl")
    end

    def logging? : Bool
      ENV["MJ_SPEND_LOG"]? != "0"
    end

    # The mj subcommand this process is running, for attribution in the ledger.
    def command : String
      cmd = ARGV[0]?
      cmd && !cmd.starts_with?("-") ? cmd : "mj"
    end

    # Record one billed call. `cost` nil = the provider reported none.
    def record(task : String, model : String, cost : Float64?,
               width : Int32? = nil, height : Int32? = nil,
               provider : String = "runware") : Nil
      @@session_calls += 1
      if c = cost
        @@session_cost += c
      else
        @@session_unpriced += 1
      end
      install_summary!
      append(task, model, cost, width, height, provider) if logging?
    end

    # Print the run tally once, on exit. Armed lazily by the first recorded call.
    def install_summary! : Nil
      return if @@hooked
      @@hooked = true
      at_exit { print_summary }
    end

    def print_summary(io : IO = STDERR) : Nil
      return if @@session_calls == 0
      line = String.build do |s|
        s << "[spend] " << @@session_calls << (@@session_calls == 1 ? " call" : " calls")
        s << " this run — " << money(@@session_cost)
        s << " (#{@@session_unpriced} unpriced)" if @@session_unpriced > 0
        if logging?
          today = total(entries.select { |e| e.time.to_local >= Time.local.at_beginning_of_day })
          s << ", today " << money(today)
        end
      end
      io.puts line
    end

    # ---- ledger I/O ----------------------------------------------------------

    private def append(task : String, model : String, cost : Float64?,
                       width : Int32?, height : Int32?, provider : String) : Nil
      path = ledger_path
      Dir.mkdir_p(File.dirname(path))
      row = JSON.build do |json|
        json.object do
          json.field "t", Time.utc.to_rfc3339
          json.field "cmd", command
          json.field "provider", provider
          json.field "task", task
          json.field "model", model
          json.field "cost", cost
          json.field "w", width if width
          json.field "h", height if height
        end
      end
      File.open(path, "a") { |f| f.puts row }
    rescue ex
      STDERR.puts "[spend] could not write ledger (#{ex.message})"
    end

    # Every ledger row, oldest first. Unparseable lines are skipped, not fatal.
    def entries : Array(Entry)
      path = ledger_path
      rows = [] of Entry
      return rows unless File.exists?(path)
      File.each_line(path) do |line|
        next if line.blank?
        begin
          j = JSON.parse(line)
          rows << Entry.new(
            time: Time.parse_rfc3339(j["t"].as_s),
            command: j["cmd"]?.try(&.as_s) || "?",
            provider: j["provider"]?.try(&.as_s) || "?",
            task: j["task"]?.try(&.as_s) || "?",
            model: j["model"]?.try(&.as_s) || "?",
            cost: j["cost"]?.try(&.as_f?),
          )
        rescue
          next
        end
      end
      rows
    end

    def total(rows : Array(Entry)) : Float64
      rows.sum { |e| e.cost || 0.0 }
    end

    def money(v : Float64) : String
      sprintf("$%.4f", v)
    end

    # ---- reporting -----------------------------------------------------------

    # Human summary of the ledger since `since` (nil = everything): a per-day table,
    # then breakdowns by model and by command.
    def report(io : IO = STDOUT, since : Time? = nil) : Nil
      rows = entries
      rows = rows.select { |e| e.time.to_local >= since } if since
      if rows.empty?
        io.puts "No spend recorded#{since ? " in that window" : ""} (#{ledger_path})."
        return
      end

      io.puts "ledger: #{ledger_path}"
      io.puts "window: #{since ? since.to_s("%Y-%m-%d") : rows.first.time.to_local.to_s("%Y-%m-%d")} .. #{rows.last.time.to_local.to_s("%Y-%m-%d")}"
      io.puts

      io.puts "By day"
      group(rows) { |e| e.time.to_local.to_s("%Y-%m-%d") }.each { |k, v| io.puts row_line(k, v) }
      io.puts
      io.puts "By model"
      group(rows) { |e| e.model }.each { |k, v| io.puts row_line(k, v) }
      io.puts
      io.puts "By command"
      group(rows) { |e| e.command }.each { |k, v| io.puts row_line(k, v) }
      io.puts

      unpriced = rows.count { |e| e.cost.nil? }
      io.puts "TOTAL  #{rows.size} #{rows.size == 1 ? "call" : "calls"}  #{money(total(rows))}#{unpriced > 0 ? "  (#{unpriced} unpriced)" : ""}"
    end

    # JSON form of the same window, for scripts.
    def report_json(io : IO = STDOUT, since : Time? = nil) : Nil
      rows = entries
      rows = rows.select { |e| e.time.to_local >= since } if since
      JSON.build(io, indent: 2) do |json|
        json.object do
          json.field "ledger", ledger_path
          json.field "calls", rows.size
          json.field "unpriced", rows.count { |e| e.cost.nil? }
          json.field "total", total(rows)
          {"by_day"     => ->(e : Entry) { e.time.to_local.to_s("%Y-%m-%d") },
           "by_model"   => ->(e : Entry) { e.model },
           "by_command" => ->(e : Entry) { e.command }}.each do |label, fn|
            json.field label do
              json.object do
                group(rows) { |e| fn.call(e) }.each do |k, v|
                  json.field k do
                    json.object do
                      json.field "calls", v.size
                      json.field "cost", total(v)
                    end
                  end
                end
              end
            end
          end
        end
      end
      io.puts
    end

    private def group(rows : Array(Entry), &block : Entry -> String) : Array({String, Array(Entry)})
      rows.group_by { |e| yield e }.to_a.sort_by { |k, _| k }
    end

    private def row_line(key : String, rows : Array(Entry)) : String
      "  #{key.ljust(24)} #{rows.size.to_s.rjust(5)} #{rows.size == 1 ? "call " : "calls"}  #{money(total(rows)).rjust(11)}"
    end
  end
end
