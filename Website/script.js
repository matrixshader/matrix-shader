// Website functionality - Matrix Terminal Shader
class MatrixWebsite {
  constructor() {
    this.init();
  }

  init() {
    this.initNavigation();
    this.initScrollEffects();
    this.initVideoControls();
    this.initCopyCode();
    this.initMobileMenu();
    this.initInteractiveElements();
    this.initLightbox();
    this.initAnalytics();
    this.initSmithForm();
    this.initGitHubStars();
    this.initEmailGate();
    this.initPlatformTabs();
  }

  // Vercel Analytics helper
  track(name, data) {
    if (window.va) window.va.track(name, data);
  }

  // Navigation (hide on scroll down, show on scroll up)
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
  }

  // Scroll-triggered fade-in effects
  initScrollEffects() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -100px 0px' });

    document.querySelectorAll('.feature-card, .download-card, .step').forEach(el => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(30px)';
      el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
      observer.observe(el);
    });
  }

  // Demo video play/pause based on visibility
  initVideoControls() {
    const video = document.getElementById('demo-video');
    if (!video) return;

    video.addEventListener('loadeddata', () => {
      video.play().catch(() => {});
    });

    const videoObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          video.play().catch(() => {});
        } else {
          video.pause();
        }
      });
    }, { threshold: 0.5 });

    videoObserver.observe(video);
  }

  // Copy-to-clipboard buttons on code blocks
  initCopyCode() {
    document.querySelectorAll('.code-block').forEach(block => {
      const button = document.createElement('button');
      button.className = 'copy-button';
      button.textContent = 'Copy';
      button.style.cssText = `
        position: absolute;
        top: 8px;
        right: 8px;
        background: rgba(0, 255, 65, 0.2);
        border: 1px solid var(--matrix-green);
        color: var(--matrix-green);
        padding: 4px 10px;
        border-radius: 4px;
        cursor: pointer;
        font-family: var(--font-mono);
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
          if (code.includes('matrixshader.com/install')) {
            navigator.sendBeacon('/api/track?event=install');
            this.track('copy_install_script');
          }
          setTimeout(() => {
            button.textContent = 'Copy';
            button.style.background = 'rgba(0, 255, 65, 0.2)';
          }, 2000);
        });
      });
    });
  }

  // Mobile menu with CSS class toggle and smooth animation
  initMobileMenu() {
    const navToggle = document.querySelector('.nav-toggle');
    const navMenu = document.querySelector('.nav-menu');

    if (!navToggle || !navMenu) return;

    navToggle.addEventListener('click', () => {
      navMenu.classList.toggle('nav-menu-open');
      navToggle.classList.toggle('nav-toggle-active');
    });

    document.addEventListener('click', (e) => {
      if (navMenu.classList.contains('nav-menu-open') &&
          !navToggle.contains(e.target) &&
          !navMenu.contains(e.target)) {
        navMenu.classList.remove('nav-menu-open');
        navToggle.classList.remove('nav-toggle-active');
      }
    });

    // Close menu on link click (mobile)
    navMenu.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        navMenu.classList.remove('nav-menu-open');
        navToggle.classList.remove('nav-toggle-active');
      });
    });
  }

  // Hero title fade-in
  initInteractiveElements() {
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

  // Analytics event tracking
  initAnalytics() {
    // Skip all tracking if owner is logged into admin (same browser)
    if (sessionStorage.getItem('zion_session')) return;

    // Capture UTM source on arrival (which platform sent this visitor?)
    var params = new URLSearchParams(window.location.search);
    var utmSource = params.get('utm_source');
    var utmContent = params.get('utm_content');
    if (utmSource) {
      localStorage.setItem('ms_utm_source', utmSource);
      if (utmContent) localStorage.setItem('ms_utm_content', utmContent);
      var tag = utmContent ? utmSource + ':' + utmContent : utmSource;
      navigator.sendBeacon('/api/track?event=visit_' + tag);
    }

    // Page view (once per visitor per day — dedup via localStorage)
    const today = new Date().toISOString().slice(0, 10);
    const lastView = localStorage.getItem('ms_last_view');
    if (lastView !== today) {
      navigator.sendBeacon('/api/track?event=page_view');
      localStorage.setItem('ms_last_view', today);
    }

    // Download button clicks
    document.querySelectorAll('[data-umami-event="Download Click"]').forEach(el => {
      el.addEventListener('click', () => {
        navigator.sendBeacon('/api/track?event=download');
        this.track('download_click', { source: 'homepage' });
      });
    });

    // Red Pill link clicks
    document.querySelectorAll('a[href="/redpill"], a[href="#redpill"]').forEach(el => {
      el.addEventListener('click', () => {
        navigator.sendBeacon('/api/track?event=redpill_click');
        this.track('redpill_click', { source: el.closest('nav') ? 'nav' : 'page' });
      });
    });

    // GitHub link clicks
    document.querySelectorAll('a[href*="github.com/matrixshader"]').forEach(el => {
      el.addEventListener('click', () => {
        navigator.sendBeacon('/api/track?event=github_click');
        this.track('github_click');
      });
    });
  }

  // Agent Smith email subscribe form
  initSmithForm() {
    const form = document.getElementById('smith-form');
    if (!form) return;

    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const email = document.getElementById('smith-email').value.trim();
      const status = document.getElementById('smith-status');
      const btn = document.querySelector('.smith-btn');

      if (!email) return;

      btn.disabled = true;
      btn.textContent = '...';
      status.textContent = '';

      fetch('/api/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email, source: 'website' })
      })
      .then(res => res.json())
      .then(data => {
        if (data.subscribed) {
          status.textContent = 'Welcome to MatrixShader, Mr. Anderson.';
          status.style.color = '#00ff41';
          this.track('email_subscribe', { source: 'agent_smith' });
          document.getElementById('smith-email').value = '';
        } else {
          status.textContent = data.error || 'Something went wrong.';
          status.style.color = '#ff0040';
        }
      })
      .catch(() => {
        status.textContent = 'Connection error. Try again.';
        status.style.color = '#ff0040';
      })
      .finally(() => {
        btn.disabled = false;
        btn.textContent = 'Subscribe';
      });
    });
  }

  // Email gate for free downloads
  initEmailGate() {
    const overlay = document.getElementById('email-gate');
    const form = document.getElementById('gate-form');
    const closeBtn = document.getElementById('gate-close');
    if (!overlay || !form) return;

    const emailInput = document.getElementById('gate-email');
    const submitBtn = document.getElementById('gate-btn');
    const status = document.getElementById('gate-status');
    const downloads = document.getElementById('gate-downloads');

    // Check if user already passed the gate this session
    const gateCleared = sessionStorage.getItem('matrixshader_gate_cleared');

    // Selectors for all free download links (hero, get-started section, blue pill card)
    const downloadSelectors = [
      'a[href*="MatrixShaderSetup.exe"]:not(.gate-download-links a)',
      '.btn-bluepill-outline'
    ];

    // If gate already cleared, let links work normally
    if (gateCleared) return;

    // Intercept free download clicks
    downloadSelectors.forEach(sel => {
      document.querySelectorAll(sel).forEach(link => {
        link.addEventListener('click', (e) => {
          if (sessionStorage.getItem('matrixshader_gate_cleared')) return;
          e.preventDefault();
          overlay.classList.add('active');
          emailInput.focus();
        });
      });
    });

    // Also intercept the hero "Download Free" button that scrolls to #get-started
    const heroDownloadBtn = document.querySelector('.hero-buttons a[href="#get-started"]');
    if (heroDownloadBtn) {
      heroDownloadBtn.addEventListener('click', (e) => {
        if (sessionStorage.getItem('matrixshader_gate_cleared')) return;
        e.preventDefault();
        overlay.classList.add('active');
        emailInput.focus();
      });
    }

    // Skip link — download without email, track it
    const skipLink = document.getElementById('gate-skip');
    if (skipLink) {
      skipLink.addEventListener('click', () => {
        sessionStorage.setItem('matrixshader_gate_cleared', '1');
        navigator.sendBeacon('/api/track?event=gate_skip');
        overlay.classList.remove('active');
      });
    }

    // Close modal — track bounce
    const closeGate = () => {
      if (overlay.classList.contains('active')) {
        navigator.sendBeacon('/api/track?event=gate_close');
      }
      overlay.classList.remove('active');
    };
    closeBtn.addEventListener('click', closeGate);
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) closeGate();
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeGate();
    });

    // Form submit
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const email = emailInput.value.trim();
      if (!email) return;

      submitBtn.disabled = true;
      submitBtn.textContent = '...';
      status.textContent = '';

      fetch('/api/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email, source: 'download_gate' })
      })
      .then(res => res.json())
      .then(data => {
        if (data.subscribed) {
          // Gate cleared
          sessionStorage.setItem('matrixshader_gate_cleared', '1');
          status.textContent = 'Welcome, Operator.';
          status.style.color = '#00ff41';
          form.style.display = 'none';
          downloads.style.display = 'block';
          navigator.sendBeacon('/api/track?event=download');
          navigator.sendBeacon('/api/track?event=gate_email');
          this.track('email_gate_complete', { email: email });
        } else {
          status.textContent = data.error || 'Something went wrong.';
          status.style.color = '#ff0040';
        }
      })
      .catch(() => {
        status.textContent = 'Connection error. Try again.';
        status.style.color = '#ff0040';
      })
      .finally(() => {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Download Free';
      });
    });
  }

  // Platform tabs (Windows / Linux / macOS)
  initPlatformTabs() {
    const tabs = document.querySelectorAll('.platform-tab');
    const contents = document.querySelectorAll('.platform-content');
    if (!tabs.length) return;

    tabs.forEach(tab => {
      tab.addEventListener('click', () => {
        if (tab.classList.contains('disabled')) return;
        const platform = tab.dataset.platform;

        tabs.forEach(t => t.classList.remove('active'));
        contents.forEach(c => c.classList.remove('active'));

        tab.classList.add('active');
        const target = document.getElementById(`platform-${platform}`);
        if (target) target.classList.add('active');

        navigator.sendBeacon?.(`/api/track?event=platform_tab_${platform}`);
      });
    });
  }

  // Fetch GitHub stars count
  initGitHubStars() {
    const badge = document.getElementById('github-stars');
    if (!badge) return;

    fetch('https://api.github.com/repos/matrixshader/matrix-shader')
      .then(res => res.json())
      .then(data => {
        if (data.stargazers_count !== undefined) {
          badge.innerHTML = `<img src="./assets/icons/github.svg" alt="" class="icon-svg-sm"> ${data.stargazers_count} stars`;
        }
      })
      .catch(() => {});
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  new MatrixWebsite();
});

// Export for external control
window.MatrixWebsite = MatrixWebsite;
