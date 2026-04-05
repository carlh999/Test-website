"""Generate NEXUS background image using Gemini Imagen API."""
import os
import sys
from google import genai
from google.genai import types

def main():
    output_path = sys.argv[1] if len(sys.argv) > 1 else "/root/research-app/static/nexus-bg.png"

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

    response = client.models.generate_images(
        model="imagen-3.0-generate-002",
        prompt=(
            "Dark futuristic AI terminal background, deep black with subtle cyan grid lines "
            "forming a perspective grid, glowing cyan data nodes scattered across the grid "
            "intersections, faint blue-cyan light traces connecting nodes, dark sci-fi aesthetic, "
            "no text, no letters, no words, seamless tileable pattern, 1920x1080, digital art"
        ),
        config=types.GenerateImagesConfig(number_of_images=1),
    )

    if not response.generated_images:
        print("ERROR: No images returned from Gemini", file=sys.stderr)
        sys.exit(1)

    image = response.generated_images[0]
    image.image.save(output_path)
    print(f"Saved background image to {output_path}")
    print(f"Size: {os.path.getsize(output_path)} bytes")


if __name__ == "__main__":
    main()
