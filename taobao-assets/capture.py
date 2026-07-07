#!/usr/bin/env python3
"""
Extracts each canvas from product-mockups.html into standalone HTML files,
then opens them in Safari and takes screenshots.
"""
import re, os, subprocess, time

SRC = "/Users/jcl/Desktop/Claude 项目文件/DeepSeekMonitor/taobao-assets/product-mockups.html"
OUT = "/Users/jcl/Desktop/Claude 项目文件/DeepSeekMonitor/taobao-assets"

with open(SRC) as f:
    html = f.read()

# Extract <style> blocks
styles = re.findall(r'<style>.*?</style>', html, re.DOTALL)

# Extract each canvas div by id
canvas_ids = ['canvas1', 'canvas2', 'canvas3', 'canvas4', 'canvas5']
file_names = ['01-cover', '02-menubar', '03-panel', '04-settings', '05-install']

for cid, fname in zip(canvas_ids, file_names):
    # Find the canvas div
    pattern = rf'(<div class="canvas[^"]*" id="{cid}">.*?</div>\s*</div>)'
    match = re.search(pattern, html, re.DOTALL)
    if not match:
        print(f"WARNING: Could not find {cid}")
        continue

    canvas_html = match.group(1)

    standalone = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head><meta charset="UTF-8">
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ width: 800px; height: 800px; overflow: hidden; background: #0f0c29; }}
</style>
"""
    for s in styles:
        standalone += s + "\n"
    standalone += "</head><body>\n"
    standalone += canvas_html + "\n"
    standalone += "</body></html>"

    path = os.path.join(OUT, f"{fname}.html")
    with open(path, 'w') as f:
        f.write(standalone)
    print(f"Created {path}")

print("\nDone! 5 standalone HTML files ready.")
print("Now open each in Safari at exact 800x800 and screenshot...")
