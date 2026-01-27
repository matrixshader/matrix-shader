# Matrix Terminal Shader Website

A modern, responsive website showcasing the Matrix Terminal Shader product - real-time GPU-powered Matrix rain effects for Windows Terminal.

## Features

- **Modern Design**: Matrix-themed UI with green/cyan color scheme
- **Responsive**: Works perfectly on desktop, tablet, and mobile
- **Interactive Elements**:
  - Live Matrix rain background effect using p5.js
  - Smooth scroll navigation
  - Video demonstrations
  - Copy-to-clipboard for code blocks
  - Mobile-friendly hamburger menu

## Sections

1. **Hero**: Compelling introduction with demo video
2. **Features**: Real-time shader controls and capabilities
3. **Multi-Agent Workflow**: The killer feature for AI development
4. **Installation**: Step-by-step setup guide
5. **Download**: Package downloads and GitHub links
6. **Footer**: Resources and community links

## Technical Stack

- **HTML5**: Semantic markup with accessibility in mind
- **CSS3**: Modern styling with Grid/Flexbox, CSS variables, animations
- **JavaScript (ES6+)**: Interactive features, performance optimization
- **p5.js**: Matrix rain background effect

## Performance Optimizations

- Lazy loading for images and videos
- Intersection Observer for scroll animations
- Debounced scroll handlers
- Optimized video playback (pause when not in viewport)
- CSS animations instead of JavaScript where possible

## Browser Support

- Chrome/Edge 88+
- Firefox 85+
- Safari 14+
- Mobile browsers (iOS Safari, Android Chrome)

## File Structure

```
Website/
├── index.html          # Main HTML file
├── styles.css          # Complete CSS styling
├── script.js           # JavaScript functionality
├── assets/             # Visual assets
│   ├── logo.jpg        # Product logo
│   ├── favicon.ico     # Site favicon
│   ├── hero-bg.jpg     # Background image
│   ├── screenshot-*.png # Screenshots
│   └── agents*.mp4     # Demo videos
└── README.md           # This file
```

## Deployment

This website is designed to be:
- **Static**: Can be hosted on any static hosting service
- **CDN-ready**: All assets are relative paths
- **SEO-optimized**: Meta tags, semantic HTML, structured content

### Quick Deployment Options

1. **GitHub Pages**: Free hosting from the repository
2. **Netlify/Vercel**: Deploy with one click
3. **AWS S3 + CloudFront**: Scalable hosting
4. **Traditional web server**: Upload files directly

## Customization

### Colors
Edit CSS variables in `styles.css`:
```css
:root {
  --matrix-green: #00ff41;
  --matrix-cyan: #00ffff;
  --matrix-red: #ff0040;
  /* etc */
}
```

### Content
All text content is in `index.html`. Key sections to customize:
- Hero title and subtitle
- Feature descriptions
- Installation instructions
- Download links

### Assets
Replace files in `assets/` folder:
- `logo.jpg` - Product logo
- `screenshot-*.png` - Product screenshots  
- `agents*.mp4` - Demo videos

## Analytics Integration

The website includes a basic Analytics class that can be extended to integrate with:
- Google Analytics
- Plausible
- Fathom
- Custom analytics

Example integration:
```javascript
// Replace the Analytics class constructor
init() {
  // Initialize Google Analytics
  gtag('config', 'GA_MEASUREMENT_ID');
  
  // Track events as before
  this.trackEvent = (event, data) => {
    gtag('event', event, data);
  };
}
```

## Development

### Local Development
1. Start a local web server (required for video playback):
```bash
# Python 3
python -m http.server 8000

# Node.js (if you have http-server installed)
npx http-server
```

2. Open `http://localhost:8000` in browser

### Monitoring Performance
Open browser DevTools and check:
- Network tab for asset loading
- Performance tab for runtime metrics
- Console for performance logs

## License

This website is part of the Matrix Terminal Shader project and follows the same open source license as the main product.