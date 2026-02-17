// Website functionality - Matrix shader-accurate background
class MatrixWebsite {
  constructor() {
    this.init();
  }

  init() {
    // Video background used instead of JS effect
    this.initNavigation();
    this.initScrollEffects();
    this.initVideoControls();
    this.initCopyCode();
    this.initMobileMenu();
    this.initInteractiveElements();
    this.initLightbox();
  }

  // Matrix Rain - Simple & performant
  initMatrixRain() {
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

  // Navigation
  initNavigation() {
    const navbar = document.querySelector('.navbar');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
      const currentScroll = window.pageYOffset;
      
      if (currentScroll > lastScroll && currentScroll > 100) {
        navbar.style.transform = 'translateY(-100%)';
      } else {
        navbar.style.transform = 'translateY(0)';
      }
      
      lastScroll = currentScroll;
    });

    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(anchor.getAttribute('href'));
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });
    });
  }

  // Scroll Effects
  initScrollEffects() {
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -100px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, observerOptions);

    document.querySelectorAll('.feature-card, .download-card, .step').forEach(el => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(30px)';
      el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
      observer.observe(el);
    });
  }

  // Video Controls
  initVideoControls() {
    const video = document.getElementById('demo-video');
    if (video) {
      video.addEventListener('loadeddata', () => {
        video.play().catch(e => {});
      });

      const videoObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            video.play().catch(e => {});
          } else {
            video.pause();
          }
        });
      }, { threshold: 0.5 });

      videoObserver.observe(video);
    }
  }

  // Copy Code Functionality
  initCopyCode() {
    document.querySelectorAll('.code-block').forEach(block => {
      const button = document.createElement('button');
      button.className = 'copy-button';
      button.textContent = 'Copy';
      button.style.cssText = `
        position: absolute;
        top: 10px;
        right: 10px;
        background: rgba(0, 255, 65, 0.2);
        border: 1px solid var(--matrix-green);
        color: var(--matrix-green);
        padding: 5px 10px;
        border-radius: 4px;
        cursor: pointer;
        font-family: monospace;
        font-size: 12px;
        transition: all 0.3s ease;
      `;

      block.style.position = 'relative';
      block.appendChild(button);

      button.addEventListener('click', () => {
        const code = block.querySelector('code').textContent;
        navigator.clipboard.writeText(code).then(() => {
          button.textContent = 'Copied!';
          button.style.background = 'rgba(0, 255, 65, 0.4)';
          // Track install script copy
          if (code.includes('matrixshader.com/install')) {
            navigator.sendBeacon('/api/track?event=install');
            if (window.va) window.va.track('copy_install_script');
          }
          setTimeout(() => {
            button.textContent = 'Copy';
            button.style.background = 'rgba(0, 255, 65, 0.2)';
          }, 2000);
        });
      });
    });
  }

  // Mobile Menu
  initMobileMenu() {
    const navToggle = document.querySelector('.nav-toggle');
    const navMenu = document.querySelector('.nav-menu');
    
    if (!navToggle || !navMenu) return;

    let isOpen = false;

    const toggleMenu = () => {
      isOpen = !isOpen;
      
      if (isOpen) {
        navMenu.style.display = 'flex';
        navMenu.style.position = 'absolute';
        navMenu.style.top = '100%';
        navMenu.style.left = '0';
        navMenu.style.right = '0';
        navMenu.style.background = 'rgba(10, 10, 10, 0.98)';
        navMenu.style.flexDirection = 'column';
        navMenu.style.padding = '1rem';
        navMenu.style.borderBottom = '2px solid var(--matrix-green)';
        
        navToggle.querySelector('span:nth-child(1)').style.transform = 'rotate(45deg) translateY(7px)';
        navToggle.querySelector('span:nth-child(2)').style.opacity = '0';
        navToggle.querySelector('span:nth-child(3)').style.transform = 'rotate(-45deg) translateY(-7px)';
      } else {
        navMenu.style.display = 'none';
        
        navToggle.querySelector('span:nth-child(1)').style.transform = 'none';
        navToggle.querySelector('span:nth-child(2)').style.opacity = '1';
        navToggle.querySelector('span:nth-child(3)').style.transform = 'none';
      }
    };

    navToggle.addEventListener('click', toggleMenu);

    document.addEventListener('click', (e) => {
      if (isOpen && !navToggle.contains(e.target) && !navMenu.contains(e.target)) {
        toggleMenu();
      }
    });

    window.addEventListener('resize', () => {
      if (window.innerWidth > 768 && isOpen) {
        toggleMenu();
      }
    });
  }

  // Interactive Elements
  initInteractiveElements() {
    const interactiveElements = document.querySelectorAll('a, button, .btn, .feature-card, .download-card');
    
    interactiveElements.forEach(element => {
      element.addEventListener('mouseenter', () => {
        element.style.transition = 'all 0.3s ease';
        element.style.boxShadow = '0 0 25px rgba(0, 255, 65, 0.6)';
        element.style.transform = 'translateY(-2px)';
      });
      
      element.addEventListener('mouseleave', () => {
        element.style.boxShadow = '';
        element.style.transform = '';
      });
    });

    const heroTitle = document.querySelector('.hero-title');
    if (heroTitle) {
      heroTitle.style.opacity = '0';
      setTimeout(() => {
        heroTitle.style.transition = 'opacity 1s ease';
        heroTitle.style.opacity = '1';
      }, 500);
    }
  }

  // Lightbox for layout screenshots
  initLightbox() {
    const lightbox = document.getElementById('lightbox');
    const lightboxImg = document.getElementById('lightbox-img');
    if (!lightbox || !lightboxImg) return;

    document.querySelectorAll('.layout-screenshot').forEach(img => {
      img.addEventListener('click', () => {
        lightboxImg.src = img.src;
        lightboxImg.alt = img.alt;
        lightbox.classList.add('active');
      });
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') lightbox.classList.remove('active');
    });
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  const matrixWebsite = new MatrixWebsite();
});

// Export for external control
window.MatrixWebsite = MatrixWebsite;