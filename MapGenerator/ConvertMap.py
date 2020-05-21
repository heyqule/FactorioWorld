import os, sys
from PIL import Image
import math
from helpers import time_s_to_hms, roundb
from chunk import Chunk
import time

# Settings
image_file = 'NE2_LR_LC_SR_W_DR.tif' #change me for different image
output_file = 'map_compressed.lua' #change me for a different output file
chunk_sizes = [32, 8]
resize_width = 500 # or None

# Globals
Image.MAX_IMAGE_PIXELS = 1000000000 #large enough to allow huge map
image_file = os.path.join(sys.path[0], image_file)
image = Image.open(image_file).convert('RGB') # the image to use

output_file = os.path.join(sys.path[0], output_file)
output = open(output_file, 'w')

# Resize image to nearest multiple of largest chunk size
width, height = image.size

resize_width = resize_width or width
resize_width = roundb(resize_width, chunk_sizes[0])

resize_height = int(float(height)*float(resize_width / float(width)))
resize_height = roundb(resize_height, chunk_sizes[0])

image = image.resize((resize_width, resize_height), Image.ANTIALIAS)
width, height = image.size

def convert_with(chunk_sizes):
    start = time.time()

    print(f"Converting image ({width}, {height}) with: {chunk_sizes}", )
    chunk = Chunk(0, width, 0, height)

    print("Dividing...", end="")
    chunk.divide(chunk_sizes)
    print()

    print("Parsing...", end="")
    chunk.parse(image)
    print()

    print("Pruning...", end="")
    chunk.prune()
    print()

    print("Writing...", end="")
    output = open(output_file[:-4] + '---' + '-'.join(str(e) for e in chunk_sizes) + ".lua", 'w')
    output.write("chunk_sizes = %s\n" % chunk_sizes)
    output.write("data = ")
    output.write(chunk.to_lua())
    print()

    end = time.time()

    print(f"Elapsed time: {time_s_to_hms(end - start)}")
    water, ground, mixed, nodes = chunk.info()
    print(f"Water: {water}/{nodes} = {water/nodes*100:.1f}%")
    print(f"Ground: {ground}/{nodes} = {ground/nodes*100:.1f}%")
    print(f"Mixed: {mixed}/{nodes} = {mixed/nodes*100:.1f}%")
    print()

convert_with(chunk_sizes)
convert_with(chunk_sizes[:-1])

# part_1 = [128, 64, 32, 16, 8, 4]
# part_2 = [64, 32, 16, 8, 4]
# part_3 = [32, 16, 8, 4]

# for f in part_1:
#     convert_with([f])
#     for s in part_2:
#         if f > s:
#             convert_with([f, s])
#         for t in part_3:
#             if f > s > t:
#                 convert_with([f, s, t])


