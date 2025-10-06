# Design Document

## Overview

This design restructures the homepage header section to create a horizontal layout with two squared buttons flanking a centered image. The design maintains the existing Docusaurus structure while enhancing the visual presentation with hover effects and proper sizing relationships.

## Architecture

The solution will modify the existing `HomepageHeader` component in `index.tsx` and update the corresponding CSS module to achieve the desired layout. The architecture follows React functional component patterns with CSS modules for styling.

### Component Structure
```
HomepageHeader
├── Container (existing)
│   ├── Title (existing)
│   ├── Subtitle (existing)
│   └── ButtonImageLayout (new)
│       ├── SquaredButton (EKS)
│       ├── CenteredImage
│       └── SquaredButton (SLURM)
```

## Components and Interfaces

### ButtonImageLayout Component
- **Purpose**: Container for the horizontal layout of buttons and image
- **Props**: None (uses existing context)
- **Styling**: Flexbox layout with proper spacing and alignment

### SquaredButton Component
- **Purpose**: Squared button with hover zoom effect
- **Props**: 
  - `to`: Navigation link
  - `children`: Button content
- **Styling**: Square aspect ratio, smooth zoom transition

### CenteredImage Component
- **Purpose**: Centered image with blurred boundaries
- **Props**:
  - `src`: Image source
  - `alt`: Alt text
- **Styling**: 10% smaller than buttons, blurred edges

## Data Models

### CSS Custom Properties
```css
:root {
  --button-size: 200px;
  --image-size: calc(var(--button-size) * 0.9); /* 10% smaller */
  --hover-scale: 1.1;
  --transition-duration: 0.3s;
}
```

### Button Dimensions
- Base size: 200px × 200px
- Hover scale: 110% (1.1x)
- Transition: 0.3s ease-in-out

### Image Dimensions
- Size: 180px × 180px (10% smaller than buttons)
- Border radius: 50% for circular appearance
- Blur effect: box-shadow with blur radius

## Error Handling

### Responsive Breakpoints
- **Desktop (>996px)**: Horizontal layout maintained
- **Tablet (768px-996px)**: Reduced spacing, maintained layout
- **Mobile (<768px)**: Vertical stacking with adjusted sizes

### Image Loading
- Fallback alt text for accessibility
- Proper image optimization for web delivery
- Graceful degradation if image fails to load

## Testing Strategy

### Visual Testing
1. **Layout Verification**: Ensure proper horizontal alignment
2. **Sizing Relationships**: Verify image is 10% smaller than buttons
3. **Hover Effects**: Test smooth zoom transitions
4. **Responsive Behavior**: Test across different screen sizes

### Accessibility Testing
1. **Keyboard Navigation**: Ensure buttons are keyboard accessible
2. **Screen Reader**: Verify proper alt text and button labels
3. **Color Contrast**: Maintain sufficient contrast ratios
4. **Focus Indicators**: Ensure visible focus states

### Cross-Browser Testing
1. **Modern Browsers**: Chrome, Firefox, Safari, Edge
2. **Mobile Browsers**: iOS Safari, Chrome Mobile
3. **Hover Support**: Graceful degradation on touch devices

## Implementation Details

### CSS Flexbox Layout
```css
.buttonImageLayout {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 2rem;
  margin: 2rem 0;
}
```

### Button Styling
```css
.squaredButton {
  width: var(--button-size);
  height: var(--button-size);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform var(--transition-duration) ease-in-out;
}

.squaredButton:hover {
  transform: scale(var(--hover-scale));
}
```

### Image Styling
```css
.centeredImage {
  width: var(--image-size);
  height: var(--image-size);
  border-radius: 50%;
  filter: blur(1px);
  box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
}
```

### Responsive Design
```css
@media screen and (max-width: 768px) {
  .buttonImageLayout {
    flex-direction: column;
    gap: 1.5rem;
  }
  
  :root {
    --button-size: 150px;
  }
}
```