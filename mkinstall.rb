
version = ARGV[0] || "versionUnknown"

cmd = "zip -r -p WortSammler-#{version}.zip cleanupPandoc.rb compileDocuments.rb lib"

system(cmd)