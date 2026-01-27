// Matrix Terminal Shader - Website JavaScript
class MatrixWebsite {
    constructor() {
        this.matrixRain = null;
        this.init();
    }

    init() {
        this.initMatrixRain();
        this.initNavigation();
        this.initScrollEffects();
        this.initVideoControls();
        this.initCopyCode();
        this.initMobileMenu();
    }

// Matrix Rain Background Effect - Based on actual Matrix.hlsl shader
    initMatrixRain() {
        const sketch = (p) => {
            let columns = [];
            
            // EXACT parameters from Matrix-1.hlsl
            const RAIN_R = 0.0;
            const RAIN_G = 1.0;
            const RAIN_B = 0.3;
            const RAIN_SPEED = 0.8;
            const CHAR_WIDTH = 10.0;
            const TRAIL_POWER = 8.0;
            const RAIN_DENSITY = 0.4;
            const FONT_SCALE = 2.2; // INCREASED from 1.0 - makes text 2.2x bigger
            
            // 16 Katakana glyphs matching the shader EXACTLY
            const katakana = 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ';
            const glyphSet = katakana.substring(0, 16); // Use first 16 like shader
            
            const getColumns = () => Math.floor(p.width / (CHAR_WIDTH * FONT_SCALE));
            
            // Exact shader random function
            function random(uv) {
                return (Math.sin(uv.x * 12.9898 + uv.y * 78.233) * 43758.5453123) % 1;
            }
            
            class MatrixColumn {
                constructor(x) {
                    this.x = x;
                    this.colRnd = Math.random();
                    this.finalSpeed = ((this.colRnd * 0.5 + 0.2) * 10.0 * RAIN_SPEED) / 1.2;
                    this.active = this.colRnd > RAIN_DENSITY; // EXACT shader logic
                }
            }
            
            p.setup = () => {
                const canvas = p.createCanvas(p.windowWidth, p.windowHeight);
                canvas.parent('matrix-bg');
                p.textFont('Courier New');
                p.textAlign(p.LEFT, p.TOP);
                p.textSize(24 * FONT_SCALE); // INCREASED from 12 - much larger text
                
                // Initialize columns
                const colCount = getColumns();
                for (let i = 0; i < colCount; i++) {
                    columns.push(new MatrixColumn(i * CHAR_WIDTH * FONT_SCALE));
                }
            };

            p.draw = () => {
                // EXACT shader: black background
                p.background(0);
                const time = p.millis() / 1000.0;
                
                // Draw each column exactly like the shader
                for (let col of columns) {
                    if (!col.active) continue;
                    
                    // Grid dimensions from shader
                    const gridDims = {
                        x: p.width / (CHAR_WIDTH * FONT_SCALE),
                        y: p.height / (24.0 * FONT_SCALE) // INCREASED from 14 - match larger text
                    };
                    
                    // Draw characters in a grid like the shader
                    for (let cellY = 0; cellY < Math.ceil(gridDims.y) + 10; cellY++) {
                        const cellId = { x: col.x / (CHAR_WIDTH * FONT_SCALE), y: cellY };
                        
                        // Character seed calculation from shader
                        const charSeed = random({ x: cellId.x, y: cellId.y });
                        const glyphIdx = Math.floor(charSeed * 16) % 16;
                        
                        // Rain position calculation from shader: rain_pos = cell_id.y - (Time * final_speed)
                        const rainPos = cellId.y - (time * col.finalSpeed) + (col.colRnd * 1000.0);
                        const cycle = (rainPos / gridDims.y * 1.5) % 1;
                        
                        if (cycle < 0 || cycle > 1) continue;
                        
                        // Trail and head calculation from shader
                        const trail = Math.pow(cycle, TRAIL_POWER);
                        const isHead = cycle > 0.97;
                        
                        // Colors from shader
                        const userColor = {
                            r: Math.floor(RAIN_R * 255),
                            g: Math.floor(RAIN_G * 255), 
                            b: Math.floor(RAIN_B * 255)
                        };
                        const whiteHead = { r: 230, g: 255, b: 230 };
                        
                        const color = isHead ? whiteHead : userColor;
                        const alpha = trail * 255;
                        
                        // Draw character
                        const y = cellY * 24 * FONT_SCALE; // INCREASED from 14 - match larger text
                        p.fill(color.r, color.g, color.b, alpha);
                        p.text(glyphSet[glyphIdx], col.x, y);
                    }
                }
            };

            p.windowResized = () => {
                p.resizeCanvas(p.windowWidth, p.windowHeight);
                const newColCount = getColumns();
                
                // Reinitialize columns if count changed
                if (newColCount !== columns.length) {
                    columns = [];
                    for (let i = 0; i < newColCount; i++) {
                        columns.push(new MatrixColumn(i * CHAR_WIDTH * FONT_SCALE));
                    }
                }
            };
        };

        this.matrixRain = new p5(sketch);
    }

    // Navigation
    initNavigation() {
        const navbar = document.querySelector('.navbar');
        let lastScroll = 0;

        window.addEventListener('scroll', () => {
            const currentScroll = window.pageYOffset;
            
            // Hide/show navbar on scroll
            if (currentScroll > lastScroll && currentScroll > 100) {
                navbar.style.transform = 'translateY(-100%)';
            } else {
                navbar.style.transform = 'translateY(0)';
            }
            
            lastScroll = currentScroll;
        });

        // Smooth scroll for anchor links
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

        // Observe elements for scroll animations
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
            // Optimize video loading
            video.addEventListener('loadeddata', () => {
                video.play().catch(e => console.log('Auto-play prevented:', e));
            });

            // Pause video when not in viewport
            const videoObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        video.play().catch(e => console.log('Play failed:', e));
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
                    setTimeout(() => {
                        button.textContent = 'Copy';
                        button.style.background = 'rgba(0, 255, 65, 0.2)';
                    }, 2000);
                });
            });

            button.addEventListener('mouseenter', () => {
                button.style.background = 'rgba(0, 255, 65, 0.3)';
            });

            button.addEventListener('mouseleave', () => {
                button.style.background = 'rgba(0, 255, 65, 0.2)';
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
                
                // Animate hamburger to X
                navToggle.querySelector('span:nth-child(1)').style.transform = 'rotate(45deg) translateY(7px)';
                navToggle.querySelector('span:nth-child(2)').style.opacity = '0';
                navToggle.querySelector('span:nth-child(3)').style.transform = 'rotate(-45deg) translateY(-7px)';
            } else {
                navMenu.style.display = 'none';
                
                // Reset hamburger
                navToggle.querySelector('span:nth-child(1)').style.transform = 'none';
                navToggle.querySelector('span:nth-child(2)').style.opacity = '1';
                navToggle.querySelector('span:nth-child(3)').style.transform = 'none';
            }
        };

        navToggle.addEventListener('click', toggleMenu);

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (isOpen && !navToggle.contains(e.target) && !navMenu.contains(e.target)) {
                toggleMenu();
            }
        });

        // Close menu on window resize
        window.addEventListener('resize', () => {
            if (window.innerWidth > 768 && isOpen) {
                toggleMenu();
            }
        });
    }
}

// Performance monitoring
class PerformanceMonitor {
    constructor() {
        this.metrics = {};
        this.init();
    }

    init() {
        // Page load performance
        window.addEventListener('load', () => {
            const loadTime = performance.now();
            console.log(`Page loaded in ${loadTime.toFixed(2)}ms`);
            
            // Track if page load is slow
            if (loadTime > 3000) {
                this.suggestOptimizations();
            }
        });

        // Track scroll performance
        let scrollTimeout;
        window.addEventListener('scroll', () => {
            if (scrollTimeout) {
                window.cancelAnimationFrame(scrollTimeout);
            }
            scrollTimeout = window.requestAnimationFrame(() => {
                // Smooth scroll handling
            });
        });
    }

    suggestOptimizations() {
        console.log('Consider optimizing images or reducing script load for better performance');
    }
}

// Analytics and error tracking
class Analytics {
    constructor() {
        this.events = [];
        this.init();
    }

    init() {
        // Track button clicks
        document.querySelectorAll('.btn').forEach(btn => {
            btn.addEventListener('click', () => {
                this.trackEvent('button_click', {
                    text: btn.textContent.trim(),
                    type: btn.className.includes('primary') ? 'primary' : 'secondary'
                });
            });
        });

        // Track scroll depth
        let maxScroll = 0;
        window.addEventListener('scroll', () => {
            const scrollPercent = Math.round(
                (window.scrollY / (document.documentElement.scrollHeight - window.innerHeight)) * 100
            );
            
            if (scrollPercent > maxScroll) {
                maxScroll = scrollPercent;
                this.trackEvent('scroll_depth', { percent: maxScroll });
            }
        });

        // Error tracking
        window.addEventListener('error', (e) => {
            this.trackEvent('javascript_error', {
                message: e.message,
                line: e.lineno,
                column: e.colno
            });
        });
    }

    trackEvent(event, data) {
        this.events.push({
            event,
            data,
            timestamp: Date.now()
        });
        
        console.log('Event tracked:', event, data);
    }
}

// Initialize everything when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const matrixWebsite = new MatrixWebsite();
    const performanceMonitor = new PerformanceMonitor();
    const analytics = new Analytics();
    
    // Add global error handling
    window.addEventListener('unhandledrejection', (e) => {
        console.error('Unhandled promise rejection:', e.reason);
        analytics.trackEvent('promise_rejection', { reason: e.reason });
    });

    // Console welcome message
    console.log('%c🔥 Matrix Terminal Shader Website Loaded 🔥', 
                'color: #00ff41; font-size: 16px; font-weight: bold;');
    console.log('%cWelcome to the Matrix...', 'color: #00ffff; font-style: italic;');
});

// Utility functions
const Utils = {
    // Debounce function for performance
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    // Check if element is in viewport
    isInViewport(element) {
        const rect = element.getBoundingClientRect();
        return (
            rect.top >= 0 &&
            rect.left >= 0 &&
            rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
            rect.right <= (window.innerWidth || document.documentElement.clientWidth)
        );
    },

    // Smooth scroll to element
    scrollToElement(element, offset = 0) {
        const elementPosition = element.getBoundingClientRect().top + window.pageYOffset;
        const offsetPosition = elementPosition - offset;

        window.scrollTo({
            top: offsetPosition,
            behavior: 'smooth'
        });
    }
};