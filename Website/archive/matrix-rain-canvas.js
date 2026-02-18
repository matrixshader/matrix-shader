// Archived: Canvas-based Matrix rain effect. Replaced by video background. Kept for potential future use.
// Originally in script.js lines 19-86 of the MatrixWebsite class.

function initMatrixRain() {
  const container = document.getElementById('matrix-bg');
  if (!container) return;

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%';
  container.appendChild(canvas);

  const fontSize = 20;
  const chars = 'ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ012345789Z';
  let w, h, cols, drops;

  function init() {
    w = canvas.width = window.innerWidth;
    h = canvas.height = window.innerHeight;
    cols = Math.floor(w / fontSize);
    drops = [];
    for (let i = 0; i < cols; i++) {
      if (Math.random() < 0.5) {
        drops.push({
          x: i * fontSize,
          y: Math.random() * h - h,
          speed: 80 + Math.random() * 100,
          len: 10 + Math.floor(Math.random() * 15)
        });
      }
    }
  }
  init();
  window.addEventListener('resize', init);

  ctx.font = `bold ${fontSize}px monospace`;

  function draw() {
    ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    ctx.fillRect(0, 0, w, h);

    for (const d of drops) {
      for (let i = 0; i < d.len; i++) {
        const y = d.y - i * fontSize;
        if (y < -fontSize || y > h) continue;

        const char = chars[Math.floor(Math.random() * chars.length)];
        const fade = 1 - i / d.len;

        if (i === 0) {
          ctx.shadowBlur = 20;
          ctx.shadowColor = '#0f0';
          ctx.fillStyle = '#cfc';
        } else {
          ctx.shadowBlur = 0;
          ctx.fillStyle = `rgba(0,${Math.floor(255*fade)},${Math.floor(70*fade)},${fade})`;
        }
        ctx.fillText(char, d.x, y);
      }
      ctx.shadowBlur = 0;

      d.y += d.speed * 0.016;
      if (d.y - d.len * fontSize > h) {
        d.y = -fontSize * 3;
        d.speed = 80 + Math.random() * 100;
      }
    }
    requestAnimationFrame(draw);
  }
  draw();
}
