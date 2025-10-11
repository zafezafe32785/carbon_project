# -------------------------
# Electricity Bill Extractor (MEA & PEA)
# -------------------------
import fitz, io
from PIL import Image, ImageDraw
import pytesseract
from IPython.display import display

def extract_from_pdf(pdf_path, coords, dpi=300):
    doc = fitz.open(pdf_path)
    page = doc.load_page(0)
    pix = page.get_pixmap(dpi=dpi)
    img = Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")

    print(f"[PEA Extract] Rendered at {dpi} DPI: {img.size[0]}x{img.size[1]} pixels")

    results = {}
    for label, box in coords.items():
        region = img.crop(box)
        text = pytesseract.image_to_string(region, lang="tha+eng").strip()
        results[label] = text
    return results

def visualize_coordinates(pdf_path, coords, dpi=300, output_path=None):
    """
    Visualize the PDF with red boxes showing the crop coordinates

    Args:
        pdf_path: Path to the PDF file
        coords: Dictionary of {label: (x0, y0, x1, y1)} coordinates
        dpi: DPI for rendering (default 300)
        output_path: Optional path to save the image (default: show only)

    Returns:
        PIL Image with red boxes drawn
    """
    # Render PDF to image
    doc = fitz.open(pdf_path)
    page = doc.load_page(0)
    pix = page.get_pixmap(dpi=dpi)
    img = Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")

    print(f"[PEA Visualize] Rendered at {dpi} DPI: {img.size[0]}x{img.size[1]} pixels")

    # Create a drawing context
    draw = ImageDraw.Draw(img)

    # Draw red rectangles for each coordinate
    label_num = 1
    for label, box in coords.items():
        x0, y0, x1, y1 = box
        # Draw rectangle with red outline (width=5 pixels for visibility)
        draw.rectangle([x0, y0, x1, y1], outline="red", width=5)

        # Draw label number instead of Thai text (avoids font encoding issues)
        # Add a small numbered label box in the corner
        label_text = f"{label_num}"
        draw.rectangle([x0, y0 - 30, x0 + 40, y0], fill="red")
        try:
            draw.text((x0 + 5, y0 - 25), label_text, fill="white")
        except:
            # If text drawing fails, just skip the label
            pass

        label_num += 1

    # Save or display
    if output_path:
        img.save(output_path)
        print(f"Saved visualization to: {output_path}")

    return img

if __name__ == "__main__":
    coords = {
        "วันที่อ่านหน่วย": (725, 550, 950, 700),   # Example for PEA
        "จำนวนหน่วย": (800, 745, 1000, 900),     # Example for PEA
    }
    pdf_path = "example.pdf"

    # Extract text
    print("Extraction results:")
    print(extract_from_pdf(pdf_path, coords))

    # Visualize coordinates
    print("\nGenerating visualization...")
    img = visualize_coordinates(pdf_path, coords, output_path="pea_visualization.png")
    print("Done! Check pea_visualization.png to see the red boxes.")
