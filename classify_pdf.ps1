# 自动分类 PDF：小于100MB用Git，大于等于100MB用Git LFS
# 支持中文显示

# 解决中文乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$limit = 100MB
$pdfFiles = Get-ChildItem -Recurse -Filter *.pdf

Write-Host "开始分类所有 PDF 文件..."

foreach ($file in $pdfFiles) {
    $size = $file.Length

    if ($size -ge $limit) {
        # 大于等于100MB → Git LFS
        Write-Host "[LFS ] $($file.FullName) 大小=$([math]::Round($size/1MB)) MB"
        git lfs track "*.pdf" | Out-Null
        git add $file.FullName
    }
    else {
        # 小于100MB → 普通 Git
        Write-Host "[GIT ] $($file.FullName) 大小=$([math]::Round($size/1MB)) MB"
        git add $file.FullName
    }
}

# 确保 .gitattributes 被加入提交
git add .gitattributes

Write-Host "`n分类完成！请执行 git commit -m 'update pdf' 提交。"
