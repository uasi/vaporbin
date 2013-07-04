def files
  Regexp.union(
    %r{app\.rb},
    %r{config\.ru},
  )
end

watch(files) { system('touch tmp/restart.txt') }
