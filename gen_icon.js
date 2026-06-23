const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const sizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

const baseDir = 'android/app/src/main/res';

async function genIcon(size) {
  const r = Math.round(size * 0.18); // corner radius
  const cx = size / 2, cy = size / 2;
  const strokeW = Math.round(size * 0.065);

  // 齿轮图标 SVG（简化齿轮）
  const svg = `<svg width="${size}" height="${size}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" style="stop-color:#e8c44a"/>
        <stop offset="50%" style="stop-color:#c4942a"/>
        <stop offset="100%" style="stop-color:#9a6e1a"/>
      </linearGradient>
      <filter id="shadow">
        <feDropShadow dx="0" dy="1" stdDeviation="1.5" flood-color="#5a3a0a" flood-opacity="0.6"/>
      </filter>
    </defs>
    <!-- 圆角金渐变背景 -->
    <rect width="${size}" height="${size}" rx="${r}" fill="url(#bg)" filter="url(#shadow)"/>
    <!-- 齿轮外圈 -->
    <circle cx="${cx}" cy="${cy}" r="${Math.round(size*0.32)}" fill="none" stroke="#3a2a0a" stroke-width="${strokeW}" opacity="0.8"/>
    <!-- 齿轮齿(8个) -->
    ${[0,45,90,135,180,225,270,315].map(a => {
      const rad = a * Math.PI / 180;
      const bx = cx + Math.cos(rad) * size * 0.32;
      const by = cy + Math.sin(rad) * size * 0.32;
      const tx = cx + Math.cos(rad) * size * 0.40;
      const ty = cy + Math.sin(rad) * size * 0.40;
      return `<line x1="${bx.toFixed(1)}" y1="${by.toFixed(1)}" x2="${tx.toFixed(1)}" y2="${ty.toFixed(1)}" stroke="#3a2a0a" stroke-width="${Math.round(strokeW*0.8)}" opacity="0.7"/>`;
    }).join('\n')}
    <!-- 中心圆 -->
    <circle cx="${cx}" cy="${cy}" r="${Math.round(size*0.1)}" fill="#3a2a0a" opacity="0.7"/>
  </svg>`;

  return await sharp(Buffer.from(svg)).resize(size, size).png().toBuffer();
}

(async () => {
  for (const [folder, size] of Object.entries(sizes)) {
    const png = await genIcon(size);
    const dir = path.join(baseDir, folder);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'ic_launcher.png'), png);
    console.log(`  ${folder}: ${size}x${size}`);
  }
  console.log('icon done');
})();
