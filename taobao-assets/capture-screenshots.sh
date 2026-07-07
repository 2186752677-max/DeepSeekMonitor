#!/bin/bash
set -e

HTML="/Users/jcl/Desktop/Claude 项目文件/DeepSeekMonitor/taobao-assets/product-mockups.html"
OUTDIR="/Users/jcl/Desktop/Claude 项目文件/DeepSeekMonitor/taobao-assets"
CANVAS_IDS=("canvas1" "canvas2" "canvas3" "canvas4" "canvas5")
CANVAS_NAMES=("01-cover" "02-menubar" "03-panel" "04-settings" "05-install")

# Create individual HTML files that show only one canvas each
for i in "${!CANVAS_IDS[@]}"; do
  ID="${CANVAS_IDS[$i]}"
  NAME="${CANVAS_NAMES[$i]}"

  cat > "/tmp/taobao-$NAME.html" << EOF
<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{width:800px;height:800px;overflow:hidden}
</style></head><body>
<div id="content"></div>
<script>
  // Load the full HTML and extract just this canvas
  fetch('file://${HTML}')
    .then(r => r.text())
    .then(html => {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      const canvas = doc.getElementById('${ID}');
      // Get all styles
      const styles = doc.querySelectorAll('style');
      let styleText = '';
      styles.forEach(s => styleText += s.outerHTML);
      document.head.innerHTML = styleText;
      document.getElementById('content').innerHTML = canvas.outerHTML;
    });
</script>
</body></html>
EOF
done

echo "Created 5 individual HTML files"
ls -la /tmp/taobao-*.html
