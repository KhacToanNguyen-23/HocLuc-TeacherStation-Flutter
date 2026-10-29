import { build } from 'esbuild';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function runBuild() {
  const outdir = path.resolve(__dirname, 'ui/dist');
  if (!fs.existsSync(outdir)) {
    fs.mkdirSync(outdir, { recursive: true });
  }

  // Clean old fonts directory if present
  const destFonts = path.resolve(outdir, 'fonts');
  if (fs.existsSync(destFonts)) {
    fs.rmSync(destFonts, { recursive: true, force: true });
  }

  const res = await build({
    entryPoints: {
      app: path.resolve(__dirname, 'src/app/main.jsx'),
    },
    bundle: true,
    minify: true,
    format: 'iife',
    outdir: path.resolve(__dirname, 'ui/dist'),
    conditions: ['production'],
    loader: {
      '.woff2': 'file',
      '.woff': 'file',
      '.ttf': 'file',
      '.svg': 'dataurl',
      '.png': 'dataurl',
      '.css': 'css',
    },
    define: {
      'process.env.NODE_ENV': '"production"',
      'import.meta.env': '{}',
    },
    metafile: true,
    logLevel: 'info',
  });

  const outs = Object.entries(res.metafile.outputs).map(([k, v]) => ({
    file: k,
    kb: Math.round(v.bytes / 1024),
  }));
  outs.sort((a, b) => b.kb - a.kb);
  const total = outs.reduce((s, o) => s + o.kb, 0);
  console.log(`\n=== MATH STUDIO ULTRA-LIGHTWEIGHT PRODUCTION BUILD ===`);
  console.log(`Total output size: ${total} KB across ${outs.length} files`);
  for (const o of outs) {
    console.log(`  - ${o.file}: ${o.kb} KB`);
  }

  // Aggregate input sizes by package
  const pkgSizes = {};
  for (const [file, info] of Object.entries(res.metafile.inputs)) {
    const m = file.match(/node_modules\/((?:@[^/]+\/)?[^/]+)/);
    const pkg = m ? m[1] : 'local-source';
    pkgSizes[pkg] = (pkgSizes[pkg] || 0) + info.bytes;
  }
  const sortedPkgs = Object.entries(pkgSizes)
    .map(([pkg, bytes]) => ({ pkg, kb: Math.round(bytes / 1024) }))
    .sort((a, b) => b.kb - a.kb);

  console.log(`\n=== INPUT PACKAGES BREAKDOWN ===`);
  for (const p of sortedPkgs.slice(0, 8)) {
    console.log(`  - ${p.pkg}: ${p.kb} KB raw`);
  }
}

runBuild().catch((err) => {
  console.error('Build failed:', err);
  process.exit(1);
});
