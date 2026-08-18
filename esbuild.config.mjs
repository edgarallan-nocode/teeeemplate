// esbuild is deliberately the whole JavaScript build. No bundler config beyond
// this file, no framework runtime — just ESM modules that npm can extend when a
// real dependency shows up.
import * as esbuild from "esbuild"
import path from "node:path"

const watch = process.argv.includes("--watch")

const config = {
  entryPoints: [path.join("app", "javascript", "application.js")],
  bundle: true,
  format: "esm",
  outdir: path.join("app", "assets", "builds"),
  publicPath: "/assets",
  sourcemap: true,
  minify: process.env.RAILS_ENV === "production",
  logLevel: "info",
  // Stimulus controllers are registered explicitly in controllers/index.js so
  // the bundle stays predictable and tree-shakeable.
  loader: { ".woff2": "file", ".png": "file", ".svg": "file" }
}

if (watch) {
  const ctx = await esbuild.context(config)
  await ctx.watch()
  console.log("[esbuild] watching…")
} else {
  await esbuild.build(config)
}
