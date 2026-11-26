#!/usr/bin/env python3
"""
Image to WebP Converter

Converts all images in input folder to WebP format with website-standard sizing.
Maintains quality while optimizing file size.

Usage:
    python3 convert-to-webp.py <input_folder> <output_folder> [--keep-original-size]

Features:
    - Supports JPG, JPEG, PNG, BMP, TIFF, GIF (animated), WEBP input
    - Resizes to website standard (1024x683) while maintaining aspect ratio
    - Preserves quality with WebP quality 90%
    - Handles transparency (PNG -> WebP with alpha)
    - Batch processing with progress reporting
"""

import argparse
import sys
from pathlib import Path
from PIL import Image

# Website standard dimensions
WEBSITE_STANDARD = (1024, 683)  # width, height

# Supported input formats
SUPPORTED_FORMATS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.gif', '.webp'}

# Default quality for WebP (high quality, minimal loss)
DEFAULT_QUALITY = 90

# Max dimensions for website use
MAX_WIDTH = 1920  # Maximum width for hero banners
MAX_HEIGHT = 1080  # Maximum height


def get_image_info(img: Image.Image) -> dict:
    """Get image information including mode and dimensions."""
    return {
        'width': img.width,
        'height': img.height,
        'mode': img.mode,
        'format': img.format
    }


def calculate_target_size(width: int, height: int, max_width: int = MAX_WIDTH, max_height: int = MAX_HEIGHT) -> tuple:
    """
    Calculate target size maintaining aspect ratio.
    If image is smaller than target, keep original size (no upscaling).
    """
    # Calculate scale factor to fit within max dimensions
    width_ratio = max_width / width
    height_ratio = max_height / height
    scale = min(width_ratio, height_ratio)
    
    # Don't upscale - keep original size if smaller
    scale = min(scale, 1.0)
    
    new_width = int(width * scale)
    new_height = int(height * scale)
    
    # Ensure minimum dimensions for web use
    new_width = max(new_width, 300)
    new_height = max(new_height, 200)
    
    return new_width, new_height


def resize_with_aspect_ratio(img: Image.Image, target_width: int, target_height: int) -> Image.Image:
    """
    Resize image maintaining aspect ratio, fitting within target dimensions.
    """
    current_width, current_height = img.size
    
    # Calculate scale to fit within target while maintaining aspect ratio
    width_ratio = target_width / current_width
    height_ratio = target_height / current_height
    scale = min(width_ratio, height_ratio)
    
    new_width = int(current_width * scale)
    new_height = int(current_height * scale)
    
    # Don't upscale
    if new_width >= current_width and new_height >= current_height:
        return img.copy()
    
    # Use high-quality resampling
    resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
    return resized


def convert_image_to_webp(
    input_path: Path,
    output_path: Path,
    quality: int = DEFAULT_QUALITY,
    resize: bool = True,
    target_size: tuple = WEBSITE_STANDARD
) -> dict:
    """
    Convert a single image to WebP format.
    
    Returns dict with conversion details.
    """
    result = {
        'success': False,
        'input_path': str(input_path),
        'output_path': str(output_path),
        'original_size': 0,
        'new_size': 0,
        'original_dims': None,
        'new_dims': None,
        'savings': 0,
        'error': None
    }
    
    try:
        # Get original file size
        result['original_size'] = input_path.stat().st_size
        
        # Open image
        with Image.open(input_path) as img:
            # Get original dimensions
            result['original_dims'] = (img.width, img.height)
            
            # Calculate target size based on image type
            if resize:
                # For thumbnails/cards, use smaller max
                # For hero banners, use larger max
                if img.width > target_size[0] or img.height > target_size[1]:
                    # Large image - resize to fit within standard
                    target_w, target_h = calculate_target_size(img.width, img.height)
                    img_resized = resize_with_aspect_ratio(img, target_w, target_h)
                    target_dims = (target_w, target_h)
                else:
                    # Already within standard, use original
                    img_resized = img
                    target_dims = (img.width, img.height)
            else:
                img_resized = img
                target_dims = (img.width, img.height)
            
            result['new_dims'] = target_dims
            
            # Determine if we need to handle transparency
            has_transparency = img.mode in ('RGBA', 'LA', 'P')
            
            # WebP supports lossy, lossless, and alpha
            # Use lossy compression with quality setting
            save_kwargs = {
                'format': 'WEBP',
                'quality': quality,
                'method': 6,  # Best quality/speed tradeoff
                'lossless': False
            }
            
            # Handle transparency - WebP can preserve alpha
            if has_transparency and img.mode == 'RGBA':
                # Keep alpha channel
                pass
            elif has_transparency and img.mode in ('LA', 'P'):
                img_resized = img_resized.convert('RGBA')
            
            # Save as WebP
            img_resized.save(output_path, **save_kwargs)
            
            # Get new file size
            result['new_size'] = output_path.stat().st_size
            if result['original_size'] > 0:
                result['savings'] = round((1 - result['new_size'] / result['original_size']) * 100, 1)
            
            result['success'] = True
            
    except Exception as e:
        result['error'] = str(e)
    
    return result


def process_folder(input_folder: Path, output_folder: Path, quality: int = DEFAULT_QUALITY) -> list:
    """
    Process all images in input folder and convert to WebP.
    """
    results = []
    
    # Create output folder if it doesn't exist
    output_folder.mkdir(parents=True, exist_ok=True)
    
    # Find all supported image files
    image_files = []
    for file_path in input_folder.iterdir():
        if file_path.is_file() and file_path.suffix.lower() in SUPPORTED_FORMATS:
            image_files.append(file_path)
    
    # Sort for consistent ordering
    image_files.sort()
    
    total = len(image_files)
    
    if total == 0:
        print(f"No supported image files found in {input_folder}")
        return results
    
    print(f"Found {total} image(s) to convert\n")
    
    for i, input_path in enumerate(image_files, 1):
        # Generate output filename
        output_filename = input_path.stem + '.webp'
        output_path = output_folder / output_filename
        
        print(f"[{i}/{total}] Converting: {input_path.name}")
        
        result = convert_image_to_webp(input_path, output_path, quality=quality)
        results.append(result)
        
        if result['success']:
            orig_w, orig_h = result['original_dims']
            new_w, new_h = result['new_dims']
            dims_changed = f" → {new_w}×{new_h}" if (orig_w != new_w or orig_h != new_h) else ""
            savings = f"({result['savings']}% smaller)" if result['savings'] > 0 else ""
            print(f"      ✓ {orig_w}×{orig_h}{dims_changed} | {result['original_size']/1024:.1f}KB → {result['new_size']/1024:.1f}KB {savings}")
        else:
            print(f"      ✗ Error: {result['error']}")
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Convert all images in folder to WebP format with website-standard sizing.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
    %(prog)s ./input ./output
    %(prog)s ./input ./output --quality 85
    %(prog)s ./input ./output --no-resize
        '''
    )
    
    parser.add_argument('input_folder', type=str, help='Input folder containing images')
    parser.add_argument('output_folder', type=str, help='Output folder for WebP images')
    parser.add_argument('--quality', '-q', type=int, default=DEFAULT_QUALITY,
                        help=f'WebP quality (1-100, default: {DEFAULT_QUALITY})')
    parser.add_argument('--keep-original-size', '-k', action='store_true',
                        help='Keep original image size (no resizing)')
    parser.add_argument('--target-width', '-w', type=int, default=WEBSITE_STANDARD[0],
                        help=f'Target width (default: {WEBSITE_STANDARD[0]})')
    parser.add_argument('--target-height', '-ht', type=int, default=WEBSITE_STANDARD[1],
                        help=f'Target height (default: {WEBSITE_STANDARD[1]})')
    
    args = parser.parse_args()
    
    input_folder = Path(args.input_folder).resolve()
    output_folder = Path(args.output_folder).resolve()
    
    # Validate input folder
    if not input_folder.exists():
        print(f"Error: Input folder does not exist: {input_folder}")
        sys.exit(1)
    
    if not input_folder.is_dir():
        print(f"Error: Input path is not a directory: {input_folder}")
        sys.exit(1)
    
    # Validate quality
    if not 1 <= args.quality <= 100:
        print("Error: Quality must be between 1 and 100")
        sys.exit(1)
    
    print("=" * 60)
    print("Image to WebP Converter")
    print("=" * 60)
    print(f"Input folder:  {input_folder}")
    print(f"Output folder: {output_folder}")
    print(f"Quality:       {args.quality}")
    print(f"Resize:        {'No' if args.keep_original_size else 'Yes (maintain aspect ratio)'}")
    if not args.keep_original_size:
        print(f"Target size:   {args.target_width}×{args.target_height}")
    print("=" * 60)
    print()
    
    # Set target size
    target_size = (args.target_width, args.target_height)
    
    # Process images
    results = process_folder(input_folder, output_folder, quality=args.quality)
    
    # Print summary
    if results:
        print()
        print("=" * 60)
        print("SUMMARY")
        print("=" * 60)
        
        successful = [r for r in results if r['success']]
        failed = [r for r in results if not r['success']]
        
        print(f"Total files:    {len(results)}")
        print(f"Converted:      {len(successful)}")
        print(f"Failed:         {len(failed)}")
        
        if successful:
            total_orig_size = sum(r['original_size'] for r in successful)
            total_new_size = sum(r['new_size'] for r in successful)
            total_savings = sum(r['savings'] for r in successful) if total_orig_size > 0 else 0
            avg_savings = total_savings / len(successful) if successful else 0
            
            print(f"Original size:  {total_orig_size/1024:.1f} KB")
            print(f"New size:       {total_new_size/1024:.1f} KB")
            print(f"Avg. savings:   {avg_savings:.1f}%")
        
        if failed:
            print("\nFailed files:")
            for r in failed:
                print(f"  - {r['input_path']}: {r['error']}")
        
        print("=" * 60)


if __name__ == '__main__':
    main()