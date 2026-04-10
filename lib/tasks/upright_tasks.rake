namespace :playwright do
  desc "Sync trace viewer from npm playwright-core package"
  task :sync do
    require_relative "../upright/version"

    source = "node_modules/playwright-core/lib/vite/traceViewer"
    dest = "public/trace-viewer"

    system("npm install") || abort("npm install failed")

    unless Dir.exist?(source)
      abort "Trace viewer not found at #{source}. Is playwright-core installed?"
    end

    FileUtils.rm_rf(dest)
    FileUtils.cp_r(source, dest)

    # Remove files not needed by index.html (unused entry points with security issues)
    %w[snapshot.html uiMode.html].each { |f| FileUtils.rm_f(File.join(dest, f)) }
    Dir.glob(File.join(dest, "uiMode.*")).each { |f| FileUtils.rm_f(f) }

    puts "Synced trace viewer v#{Upright::PLAYWRIGHT_VERSION} to #{dest}"
    puts "Files:"
    Dir.glob("#{dest}/**/*").sort.each { |f| puts "  #{f}" if File.file?(f) }
  end
end
