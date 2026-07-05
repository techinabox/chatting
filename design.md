---
name: Neon Silence
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#cdc3d4'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#978d9d'
  outline-variant: '#4b4452'
  surface-tint: '#dab9ff'
  primary: '#dab9ff'
  on-primary: '#460283'
  primary-container: '#bb86fc'
  on-primary-container: '#4c0f89'
  inverse-primary: '#7743b5'
  secondary: '#46f5e0'
  on-secondary: '#003731'
  secondary-container: '#00d8c4'
  on-secondary-container: '#005950'
  tertiary: '#ffb2bc'
  on-tertiary: '#600f26'
  tertiary-container: '#ec7d90'
  on-tertiary-container: '#68162b'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#eedbff'
  primary-fixed-dim: '#dab9ff'
  on-primary-fixed: '#2a0053'
  on-primary-fixed-variant: '#5e289b'
  secondary-fixed: '#4ffbe6'
  secondary-fixed-dim: '#17deca'
  on-secondary-fixed: '#00201c'
  on-secondary-fixed-variant: '#005048'
  tertiary-fixed: '#ffd9dd'
  tertiary-fixed-dim: '#ffb2bc'
  on-tertiary-fixed: '#400013'
  on-tertiary-fixed-variant: '#7e273b'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The design system is anchored in **Functional Minimalism** with a **Dark Cyberpunk** edge. It is tailored for a privacy-conscious audience that values anonymity and high-tech utility. The emotional response is one of "calm intensity"—the interface stays out of the way, yet feels like a powerful, encrypted tool.

The visual direction mixes **Minimalism** (stripping away non-essential UI) with **Glassmorphism** and **Neon Glow** effects. Surfaces are predominantly ink-black or deep charcoal, providing a high-contrast stage for vibrant, violet-spectrum accents that indicate action and status. The aesthetic is sharp, digital, and undeniably modern.

## Colors

This design system uses a strictly dark palette optimized for OLED screens and high-privacy environments.

- **Primary (#BB86FC):** A neon purple used for branding, primary actions, and focused states. It should often be accompanied by a subtle outer glow (0px 0px 8px).
- **Secondary (#03DAC6):** A technical teal for secondary information, success states, or encryption indicators.
- **Surface (#1E1E1E):** The base container color, providing enough contrast against the pure black background to define hierarchy.
- **Glassmorphism:** Use semi-transparent layers for message bubbles and overlays with a `16px` backdrop blur and a thin `1px` stroke using `glass_stroke_hex`.

## Typography

The typography system balances the precision of developer tools with the readability of modern SaaS. 

- **Primary Typeface:** **Hanken Grotesk** is used for all UI elements, providing a clean, sharp, and contemporary feel.
- **Technical Accent:** **JetBrains Mono** is utilized for metadata, timestamps, and encryption keys to lean into the "cyberpunk" and "secure" narrative.
- **Styling:** Headlines should remain tight with negative letter-spacing. Labels use uppercase and increased tracking to create a "heads-up display" (HUD) effect.

## Layout & Spacing

The design system employs a **Fluid Grid** for mobile-first messaging. 

- **Grid Model:** 4-column for mobile, 12-column for tablet/desktop. 
- **Rhythm:** An 8px linear scale is the standard, but a 4px "micro-step" is permitted for tight technical data or monospaced labels.
- **Margins:** Generous 20px margins on mobile ensure the content feels cinematic and uncrowded, reinforcing the minimalist philosophy. 
- **Adaptability:** On larger screens, the chat interface is centered within a fixed-width container (max-width: 600px) to prevent long line lengths and maintain focus.

## Elevation & Depth

Hierarchy is established through **Tonal Layers** and **Glassmorphism** rather than traditional shadows.

1. **Base:** Pure Black (#000000) for the absolute background.
2. **Surface:** Deep Charcoal (#121212) for the primary content area.
3. **Floating:** Glassmorphic containers with a 15% opacity primary tint, 16px blur, and a subtle neon inner-glow on the top edge.

Avoid heavy shadows. Instead, use "Glow Elevation": active elements like the primary button should emit a soft `#BB86FC` outer glow to appear "powered on."

## Shapes

The shape language is **Rounded**, providing a sophisticated balance between technical and approachable.

- **Primary Radius:** 0.5rem (8px) for cards, input fields, and message bubbles.
- **Large Radius:** 1.5rem (24px) for bottom sheets and large container overrides.
- **Interactive Elements:** Buttons utilize the primary radius. Icons should be encased in circular or slightly rounded-square containers to maintain a consistent silhouette.

## Components

### Buttons
- **Primary:** Solid `#BB86FC` with black text. On hover/active, add a 12px neon blur.
- **Ghost:** Transparent background with a 1px border of `#BB86FC`. Use for secondary actions like "Cancel" or "Archive."

### Message Bubbles
- **Sent:** Glassmorphic with a `#BB86FC` border (20% opacity). Text is white.
- **Received:** Solid `#1E1E1E`. Text is high-emphasis grey.
- **Shape:** Use asymmetrical rounding (e.g., 12px on three corners, 2px on the sender's corner) to indicate direction.

### Input Fields
- Underlined or fully enclosed in a `#1E1E1E` container. The active state must trigger a 1px `#BB86FC` border and a monospaced "typing..." indicator.

### Chips & Indicators
- Used for "Self-Destruct" timers or "Encrypted" status. These use **JetBrains Mono** and a 1px border.

### Security Visuals
- Use a "Pulse" component (a small glowing dot) next to the user's name to indicate an active, end-to-end encrypted connection.
