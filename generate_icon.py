import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_icon():
    size = 1024
    # Create gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Gradient: Blue to Purple
    # Simple approach: draw lines with interpolation
    for y in range(size):
        r = int(0 + (138 - 0) * (y / size))
        g = int(122 + (43 - 122) * (y / size))
        b = int(255 + (226 - 255) * (y / size))
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
        
    # Create mask for rounded corners (macOS style roughly continuous curve, but simple rounded rect here)
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    radius = int(size * 0.223) # Standard macOS icon corner radius ratio
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)
    
    # Apply mask
    img.putalpha(mask)
    
    # Draw simple "Waveform" style lines in center white
    center_y = size // 2
    center_x = size // 2
    width = int(size * 0.6)
    height = int(size * 0.4)
    
    # Draw 5 bars
    bar_width = width // 9
    spacing = width // 9
    
    heights = [0.4, 0.7, 1.0, 0.7, 0.4]
    
    start_x = center_x - (width // 2)
    
    for i, h_ratio in enumerate(heights):
        x = start_x + (i * (bar_width + spacing))
        h = int(height * h_ratio)
        y1 = center_y - (h // 2)
        y2 = center_y + (h // 2)
        
        # Draw bar with rounded caps
        draw.rounded_rectangle([(x, y1), (x + bar_width, y2)], radius=bar_width//2, fill=(255, 255, 255, 230))

    # Add shadow/gloss? (Optional, kept simple for now)
    
    img.save("AppIcon.png")
    print("AppIcon.png generated successfully.")

if __name__ == "__main__":
    create_icon()
