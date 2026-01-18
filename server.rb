#!/usr/bin/env ruby
# Minimal preview server for Hidden Gems articles

require "webrick"
require "kramdown"
require "rouge"
require "yaml"
require "cgi"
require "rbconfig"
require "securerandom"
require "date"

# Try to use GitHub-style Markdown if available
begin
  require "kramdown-parser-gfm"
  KRAMDOWN_INPUT = "GFM"
rescue LoadError
  KRAMDOWN_INPUT = "kramdown"
end

PORT = 4000
cache_buster = SecureRandom.hex(8)

# --- CLI handling -------------------------------------------------------------

if ARGV.empty?
  warn "Usage: ruby #{File.basename($PROGRAM_NAME)} PATH_TO_ARTICLE_DIR"
  exit 1
end

path = File.expand_path(ARGV.first)
path = File.dirname(path) unless File.directory?(path)
ARTICLE_DIR   = path
MARKDOWN_FILE = File.join(ARTICLE_DIR, "index.md")

unless File.file?(MARKDOWN_FILE)
  warn "index.md not found in #{ARTICLE_DIR}"
  exit 1
end

# --- Rouge helpers ------------------------------------------------------------

def highlight_code(lang, code)
  formatter = Rouge::Formatters::HTMLTable.new(Rouge::Formatters::HTML.new)
  lexer     = Rouge::Lexer.find_fancy(lang, code) || Rouge::Lexers::PlainText
  formatter.format(lexer.lex(code.scrub))
end

# --- front matter / blogmeta --------------------------------------------------

def extract_blogmeta(markdown)
  meta = {}

  # Fallback date from directory name (YYYY-MM-DD-title-of-article)
  dirname = File.basename(ARTICLE_DIR)
  if dirname && dirname =~ /\A(\d{4}-\d{2}-\d{2})/
    begin
      meta["date"] = Date.parse($1)
    rescue ArgumentError
      # ignore
    end
  end

  cleaned = markdown

  # 1) Try YAML front matter: --- ... ---
  if markdown =~ /\A---\s*\n(.*?)\n---\s*\n/m
    raw_meta = Regexp.last_match(1)
    begin
      yaml_meta = YAML.safe_load(raw_meta, permitted_classes: [Date, Time], aliases: true) || {}
      meta.merge!(yaml_meta) if yaml_meta.is_a?(Hash)
    rescue StandardError => e
      warn "Could not parse YAML front matter: #{e.message}"
    end
    cleaned = markdown.sub(/\A---\s*\n(.*?)\n---\s*\n/m, "")
  else
    # 2) Fallback: old <blogmeta>…</blogmeta> block (if you still have any)
    cleaned = markdown.sub(/<blogmeta>\s*(.*?)\s*<\/blogmeta>/m) do
      raw_meta = Regexp.last_match(1)
      begin
        yaml_meta = YAML.safe_load(raw_meta, permitted_classes: [Date, Time], aliases: true) || {}
        meta.merge!(yaml_meta) if yaml_meta.is_a?(Hash)
      rescue StandardError => e
        warn "Could not parse <blogmeta>: #{e.message}"
      end
      ""
    end
  end

  # Map old/new keys to the names we use later
  meta["author_description"] ||= meta["author_bio"] if meta["author_bio"]
  meta["avatar"]             ||= meta["author_image"] if meta["author_image"]

  [cleaned, meta]
end

# --- ```include blocks --------------------------------------------------------

def expand_includes(markdown, root_dir)
  markdown.gsub(/```include\s*\n(.+?)\n```/m) do
    rel_path = Regexp.last_match(1).strip
    full     = File.join(root_dir, rel_path)

    unless File.file?(full)
      warn "Include file not found: #{full}"
      "```text\n[missing include: #{rel_path}]\n```"
    else
      code = File.read(full, encoding: "UTF-8")
      ext  = File.extname(rel_path).delete(".").downcase
      lang = ext.empty? ? "text" : ext
      %(<div class="code-block">#{highlight_code(lang, code)}</div>)
    end
  end
end

# --- ```replay blocks ---------------------------------------------------------

def transform_replays(markdown)
  markdown.gsub(/```replay\s*\n(.+?)\n```/m) do
    filename = Regexp.last_match(1).strip
    escaped  = CGI.escapeHTML(filename)
    <<~END_OF_STRING
    <div class='f ansi-player-auto-pickup' data-url='#{escaped}'>
        <div class='ansi-player-screen'></div>
    </div>
    END_OF_STRING
  end
end

# --- Markdown → HTML ----------------------------------------------------------

def render_article
  raw = File.read(MARKDOWN_FILE, encoding: "UTF-8")

  md1, meta = extract_blogmeta(raw)
  md2       = expand_includes(md1, ARTICLE_DIR)
  processed = transform_replays(md2)

  html_body = Kramdown::Document.new(
    processed,
    input:              KRAMDOWN_INPUT,
    math_engine:        nil,         # leave $$…$$ to MathJax
    syntax_highlighter: "rouge",
    syntax_highlighter_opts: {
      formatter: Rouge::Formatters::HTMLTable.new(Rouge::Formatters::HTML.new)
    }
  ).to_html

  [html_body, meta]
end

def content_type_for(path)
  if path.end_with?(".json.gz")
    "application/gzip"
  elsif path.end_with?(".jpg")
    "image/jpeg"
  elsif path.end_with?(".png")
    "image/png"
  elsif path.end_with?(".svg")
    "image/svg+xml"
  elsif path.end_with?(".gif")
    "image/gif"
  elsif path.end_with?(".webp")
    "image/webp"
  elsif path.end_with?(".css")
    "text/css; charset=utf-8"
  elsif path.end_with?(".js")
    "application/javascript; charset=utf-8"
  elsif path.end_with?(".mp4")
    "video/mp4"
  else
    WEBrick::HTTPUtils.mime_type(
      File.extname(path),
      WEBrick::HTTPUtils::DefaultMimeTypes
    )
  end
end

# Insert meta HTML right after the first heading (h1–h6)
def insert_meta_after_first_heading(html, meta_html)
  return html if meta_html.nil? || meta_html.strip.empty?

  if html =~ /(<h[1-6][^>]*>.*?<\/h[1-6]>)/m
    html.sub(/(<h[1-6][^>]*>.*?<\/h[1-6]>)/m) do |match|
      "#{match}\n#{meta_html}"
    end
  else
    # no heading found → just prepend
    "#{meta_html}\n#{html}"
  end
end

# --- WEBrick server -----------------------------------------------------------

server = WEBrick::HTTPServer.new(
  Port: PORT,
  AccessLog: [],
  Logger: WEBrick::Log.new(IO::NULL)
)

trap("INT") { server.shutdown }

server.mount_proc "/" do |req, res|
  # Static files (images, json.gz, etc.)
  if req.path != "/" && req.path != "/index.html"
    local = File.join(ARTICLE_DIR, req.path.sub(%r{\A/}, ""))
    if req.path.index('/include/') == 0
        local = File.join('include', File.dirname(__FILE__), req.path.sub(%r{\A/include/}, ""))
        STDERR.puts local
    end

    if File.file?(local)
      res.status = 200
      res["Content-Type"] = content_type_for(local)
      res.body = File.binread(local)
      next
    else
      res.status = 404
      res["Content-Type"] = "text/plain; charset=utf-8"
      res.body = "Not found: #{req.path}"
      next
    end
  end

  html_body, meta = render_article

  title  = meta["title"]  || "Hidden Gems Blog"
  author = meta["author"] ? CGI.escapeHTML(meta["author"].to_s) : nil
  author_description = meta["author_description"] ? CGI.escapeHTML(meta["author_description"].to_s) : nil
  date_value = meta["date"]
  date =
    if date_value.respond_to?(:strftime)
      date_value.strftime("%d.%m.%Y")
    elsif date_value
      begin
        Date.parse(date_value.to_s).strftime("%d.%m.%Y")
      rescue ArgumentError
        date_value.to_s
      end
    end
  date = CGI.escapeHTML(date.to_s) if date
  avatar = meta["avatar"] ? CGI.escapeHTML(meta["avatar"].to_s) : nil
  tags   = meta["tags"].is_a?(Array) ? meta["tags"].map(&:to_s) : []

  # Build author meta block (to be injected after first heading)
  meta_html = +""
  if author || date || author_description || avatar || !tags.empty?
    meta_html << %(<section class="post-meta">)

    if avatar
      meta_html << %(<div class="post-meta__avatar">)
      alt = author ? "Foto von #{author}" : "Autorbild"
      meta_html << %(<img src="#{avatar}" alt="#{CGI.escapeHTML(alt)}">)
      meta_html << %(</div>)
    end

    meta_html << %(<div class="post-meta__content">)

    if author || date
      meta_html << %(<div class="post-meta__row">)
      meta_html << %(<span class="post-meta__author">#{author}</span>) if author
      if author && date
        meta_html << %(<span class="post-meta__separator">·</span>)
      end
      meta_html << %(<time class="post-meta__date">#{date}</time>) if date
      meta_html << %(</div>)
    end

    if author_description
      meta_html << %(<p class="post-meta__bio">#{author_description}</p>)
    end

    unless tags.empty?
      meta_html << %(<div class="post-meta__tags">)
      tags.each do |t|
        meta_html << %(<span class="post-meta__tag">#{CGI.escapeHTML(t)}</span>)
      end
      meta_html << %(</div>)
    end

    meta_html << %(</div></section>)
  end

  full_html_body = insert_meta_after_first_heading(html_body, meta_html)

  res.status = 200
  res["Content-Type"] = "text/html; charset=utf-8"
  res.body = <<~HTML
    <!DOCTYPE html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{CGI.escapeHTML(title)}</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Exo+2:ital,wght@0,100..900;1,100..900&family=IBM+Plex+Mono:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;1,100;1,200;1,300;1,400;1,500;1,600;1,700&family=IBM+Plex+Sans:ital,wght@0,100..700;1,100..700&display=swap" rel="stylesheet">

        <link href="https://hiddengems.gymnasiumsteglitz.de/include/bootstrap-5.3.3/dist/css/bootstrap.min.css?#{cache_buster}" rel="stylesheet">
        <link href="https://hiddengems.gymnasiumsteglitz.de/include/bootstrap-icons-1.11.3/font/bootstrap-icons.min.css?#{cache_buster}" rel="stylesheet">

        <link href="https://hiddengems.gymnasiumsteglitz.de/include/default.css?#{cache_buster}" rel="stylesheet">
        <link href="https://hiddengems.gymnasiumsteglitz.de/include/dark.css?#{cache_buster}" rel="stylesheet">
        <link href="/include/bootstrap-icons-1.11.3/font/bootstrap-icons.min.css?#{cache_buster}" rel="stylesheet">

        <script src="https://hiddengems.gymnasiumsteglitz.de/include/code.js?#{cache_buster}"></script>
        <script src="https://hiddengems.gymnasiumsteglitz.de/include/ansi-player.js?#{cache_buster}"></script>
        <script src="https://hiddengems.gymnasiumsteglitz.de/include/bootstrap-5.3.3/dist/js/bootstrap.bundle.min.js?#{cache_buster}"></script>
      <style>
        #{Rouge::Theme.find('gruvbox').render(scope: 'pre')}

        pre table td {
            padding: 0;
            border-radius: 0;
        }
        .rouge-gutter {
            opacity: 0.5;
            text-align: right;
        }
        h1, h2, h3, h4, h5, h6 {
            font-family: 'Exo 2', sans-serif;
        }

        img {
            max-width: 100%;
            border-radius: 4px;
        }

        pre code {
            background-color: transparent !important;
            padding: 0 !important;
        }

        .post-meta {
            margin: 1rem 0 2rem;
            display: flex;
            align-items: flex-start;
            gap: 1rem;
            font-size: 0.95rem;
            color: #444;
            border-top: 1px solid rgba(0,0,0,0.1);
            border-bottom: 1px solid rgba(0,0,0,0.1);
            padding: 1rem 0;
        }

        .post-meta__avatar img {
            width: 56px;
            height: 56px;
            border-radius: 999px;
            object-fit: cover;
            display: block;
        }

        .post-meta__content {
            flex: 1;
        }

        .post-meta__row {
            display: flex;
            align-items: baseline;
            flex-wrap: wrap;
            gap: 0.4rem;
        }

        .post-meta__author {
            font-weight: 600;
        }

        .post-meta__separator {
            opacity: 0.6;
        }

        .post-meta__date {
            color: #666;
        }

        .post-meta__bio {
            margin: 0.25rem 0 0.5rem;
            color: #555;
        }

        .post-meta__tags {
            display: flex;
            flex-wrap: wrap;
            gap: 0.35rem;
        }

        .post-meta__tag {
            padding: 0.1rem 0.6rem;
            border-radius: 999px;
            background: #f3f0e6;
            color: #5c4b3a;
            font-size: 0.8rem;
        }

      </style>

      <script>
        window.MathJax = {
          tex: {
            inlineMath: [['$', '$']],
            displayMath: [['$$', '$$']]
          },
        };
        var brightness = 'auto';
        var system_brightness = 'light';
        var dark_css_element = null;

        function update_dark_mode() {
            let dark = false;
            if (brightness === 'auto') dark = (system_brightness === 'dark');
            if (brightness === 'light') dark = false;
            if (brightness === 'dark') dark = true;
            console.log("Dark mode:", dark);
            if (dark) {
                document.getElementsByTagName('html')[0].setAttribute('data-bs-theme', 'dark');
            } else {
                document.getElementsByTagName('html')[0].setAttribute('data-bs-theme', 'light');
            }
        }

        window.addEventListener('DOMContentLoaded', function() {
            if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
                system_brightness = 'dark';
            }
            update_dark_mode();
            window.matchMedia('(prefers-color-scheme: dark)')
            .addEventListener('change',({ matches }) => {
                if (matches) {
                    system_brightness = 'dark';
                    update_dark_mode();
                } else {
                    system_brightness = 'light';
                    update_dark_mode();
                }
            });
        });
      </script>
      <script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js" async></script>
    </head>
    <body>
        <div class="container">
        #{full_html_body}
        </div>
    </body>
    </html>
  HTML
end

puts "Serving #{MARKDOWN_FILE} at http://localhost:#{PORT}"
server.start
