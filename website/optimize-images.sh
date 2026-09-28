#!/bin/bash

# Image Optimization Script for Homepage Performance
# This script optimizes large images to improve Largest Contentful Paint (LCP)

echo "🖼️  Starting image optimization..."
echo ""

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "⚠️  ImageMagick not found. Installing via Homebrew..."
    brew install imagemagick
fi

# Navigate to image directory
cd /Users/paragao/dev/2026/ai-on-sagemaker-hyperpod/website/static/img

echo "📦 Creating backups..."
mkdir -p .originals
cp central-intro-image.jpg .originals/ 2>/dev/null
cp 99-front-page/*.png .originals/ 2>/dev/null

echo ""
echo "🔧 Optimizing hero image (central-intro-image.jpg)..."
# Resize and optimize hero image from 3.4MB to ~100KB
convert central-intro-image.jpg \
  -resize 400x400 \
  -quality 85 \
  -strip \
  central-intro-image-optimized.jpg

echo "   Original: $(du -h central-intro-image.jpg | cut -f1)"
echo "   Optimized: $(du -h central-intro-image-optimized.jpg | cut -f1)"

echo ""
echo "🎨 Optimizing feature icons..."
cd 99-front-page

# Optimize feature icons from 1.2-1.5MB each to ~50-100KB
for file in resilience-robot.png scale-with-accelerators.png state-of-the-art.png reduce-costs-governance.png; do
    if [ -f "$file" ]; then
        echo "   Processing $file..."
        convert "$file" \
          -resize 400x400 \
          -quality 85 \
          -strip \
          "${file%.png}-optimized.png"
        echo "     Before: $(du -h $file | cut -f1) → After: $(du -h ${file%.png}-optimized.png | cut -f1)"
    fi
done

echo ""
echo "📊 Optimizing carousel images..."
for file in whats-news.png whats-news-card-1.png; do
    if [ -f "$file" ]; then
        echo "   Processing $file..."
        convert "$file" \
          -resize 600x400 \
          -quality 85 \
          -strip \
          "${file%.png}-optimized.png"
        echo "     Before: $(du -h $file | cut -f1) → After: $(du -h ${file%.png}-optimized.png | cut -f1)"
    fi
done

cd ../..

echo ""
echo "✅ Image optimization complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Update component files to use -optimized versions"
echo "   2. Test the site"
echo "   3. Run Lighthouse again"
echo ""
echo "💾 Original files backed up to: static/img/.originals/"
