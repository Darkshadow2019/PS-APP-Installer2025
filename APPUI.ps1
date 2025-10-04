Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# Global variables for selected apps
$selectedApps = @()
$checkBoxes = @()

# Function to install Chocolatey
function Install-Chocolatey {
    $statusLabel.Text = "Installing Chocolatey... Please wait."
    $form.Refresh()
    
    try {
        # Set execution policy
        Set-ExecutionPolicy Bypass -Scope Process -Force
        
        # Download and install Chocolatey
        $installScript = Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" -UseBasicParsing
        Invoke-Expression $installScript.Content
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        Start-Sleep -Seconds 3
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $statusLabel.Text = "Chocolatey installed successfully! Optimizing..."
            Optimize-Chocolatey
            return $true
        } else {
            throw "Chocolatey installation verification failed"
        }
    }
    catch {
        $statusLabel.Text = "Chocolatey installation failed!"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to install Chocolatey. Please install manually.`nError: $($_.Exception.Message)",
            "Installation Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

# Chocolatey Speed Optimization Function
function Optimize-Chocolatey {
    try {
        & choco feature enable -n allowGlobalConfirmation -r
        & choco feature enable -n skipIntegrityChecksForDownloads -r
        & choco feature disable -n virusCheck -r
        & choco cache remove --all -r
        return $true
    }
    catch {
        return $false
    }
}

# Function to load image from URL with fallback
function Get-ImageFromUrl {
    param([string]$Url, [int]$Width, [int]$Height)
    
    try {
        $httpClient = New-Object System.Net.Http.HttpClient
        $stream = $httpClient.GetStreamAsync($Url).Result
        $originalImage = [System.Drawing.Image]::FromStream($stream)
        
        # Resize image
        $resizedImage = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($originalImage, 0, 0, $Width, $Height)
        
        $stream.Dispose()
        $httpClient.Dispose()
        
        return $resizedImage
    }
    catch {
        # Create fallback image
        $fallbackImage = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($fallbackImage)
        $graphics.Clear([System.Drawing.Color]::FromArgb(70, 130, 180))
        
        $font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $text = "ICON"
        $textSize = $graphics.MeasureString($text, $font)
        $x = ($Width - $textSize.Width) / 2
        $y = ($Height - $textSize.Height) / 2
        $graphics.DrawString($text, $font, $brush, $x, $y)
        
        return $fallbackImage
    }
}

# Function to create app panel with checkbox
function Create-AppPanel {
    param($AppName, $PackageName, $ToolTip, $IconUrl, $Location)
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(200, 60)
    $panel.Location = $Location
    $panel.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panel.Tag = @{Name=$AppName; Package=$PackageName}

    # CheckBox
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.Size = New-Object System.Drawing.Size(20, 20)
    $checkBox.Location = New-Object System.Drawing.Point(10, 20)
    $checkBox.BackColor = [System.Drawing.Color]::Transparent
    $checkBox.ForeColor = [System.Drawing.Color]::White

    # App Icon
    $iconPicture = New-Object System.Windows.Forms.PictureBox
    $iconPicture.Size = New-Object System.Drawing.Size(32, 32)
    $iconPicture.Location = New-Object System.Drawing.Point(40, 14)
    $iconPicture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
    
    try {
        if ($IconUrl) {
            $iconPicture.Image = Get-ImageFromUrl -Url $IconUrl -Width 32 -Height 32
        }
    }
    catch {
        Write-Host "Failed to load icon for $AppName" -ForegroundColor Yellow
    }

    # App Name Label
    $appLabel = New-Object System.Windows.Forms.Label
    $appLabel.Text = $AppName
    $appLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $appLabel.Size = New-Object System.Drawing.Size(140, 20)
    $appLabel.Location = New-Object System.Drawing.Point(80, 12)
    $appLabel.ForeColor = [System.Drawing.Color]::White

    # Package Name Label
    $packageLabel = New-Object System.Windows.Forms.Label
    $packageLabel.Text = $PackageName
    $packageLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7)
    $packageLabel.Size = New-Object System.Drawing.Size(140, 15)
    $packageLabel.Location = New-Object System.Drawing.Point(80, 32)
    $packageLabel.ForeColor = [System.Drawing.Color]::LightGray

    # ToolTip
    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($panel, $ToolTip)
    $toolTip.SetToolTip($appLabel, $ToolTip)
    $toolTip.SetToolTip($iconPicture, $ToolTip)

    # Add controls to panel
    $panel.Controls.Add($checkBox)
    $panel.Controls.Add($iconPicture)
    $panel.Controls.Add($appLabel)
    $panel.Controls.Add($packageLabel)

    # Panel click event (toggles checkbox)
    $panel.Add_Click({
        $checkBox.Checked = -not $checkBox.Checked
        Update-SelectedApps
    })

    # Checkbox change event
    $checkBox.Add_CheckedChanged({
        Update-SelectedApps
    })

    # Hover effects
    $panel.Add_MouseEnter({
        $this.BackColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    })

    $panel.Add_MouseLeave({
        if (-not $checkBox.Checked) {
            $this.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 70)
        } else {
            $this.BackColor = [System.Drawing.Color]::FromArgb(0, 100, 180)
        }
    })

    # Store checkbox reference
    $checkBoxes += @{CheckBox=$checkBox; Package=$PackageName; Name=$AppName}

    return $panel
}

# Function to update selected apps list
function Update-SelectedApps {
    $selectedApps.Clear()
    $selectedCount = 0
    
    foreach ($item in $checkBoxes) {
        if ($item.CheckBox.Checked) {
            $selectedApps += @{
                Name = $item.Name
                Package = $item.Package
            }
            $selectedCount++
        }
    }
    
    $selectedLabel.Text = "Selected: $selectedCount app(s)"
    
    # Update install button
    if ($selectedCount -gt 0) {
        $installSelectedBtn.Enabled = $true
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
        $installSelectedBtn.Text = "Install Selected ($selectedCount)"
    } else {
        $installSelectedBtn.Enabled = $false
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
        $installSelectedBtn.Text = "Install Selected"
    }
}

# Function to install selected applications
function Install-SelectedApplications {
    if ($selectedApps.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one application to install.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if (-not (Check-Chocolatey)) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey not found! It is required to install applications.`n`nDo you want to install Chocolatey now?",
            "Chocolatey Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            if (Install-Chocolatey) {
                $installChocoBtn.Visible = $false
                Update-UIForChocolatey
            } else {
                return
            }
        } else {
            return
        }
    }
    
    $appList = ($selectedApps | ForEach-Object { "• $($_.Name) ($($_.Package))" }) -join "`n"
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Install the following $($selectedApps.Count) applications?`n`n$appList",
        "Confirm Bulk Installation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $statusLabel.Text = "Installing $($selectedApps.Count) applications... Please wait."
        $form.Refresh()
        
        $successCount = 0
        $failCount = 0
        
        foreach ($app in $selectedApps) {
            try {
                $statusLabel.Text = "Installing $($app.Name)... ($($successCount + $failCount + 1)/$($selectedApps.Count))"
                $form.Refresh()
                
                $process = Start-Process -FilePath "choco" -ArgumentList "install $($app.Package) -y --force" -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0) {
                    $successCount++
                } else {
                    $failCount++
                }
                
                Start-Sleep -Milliseconds 500
            }
            catch {
                $failCount++
            }
        }
        
        if ($failCount -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("All $successCount applications installed successfully!", "Installation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $statusLabel.Text = "All $successCount applications installed successfully!"
        } else {
            [System.Windows.Forms.MessageBox]::Show("Installation completed with results:`n`nSuccessful: $successCount`nFailed: $failCount", "Installation Results", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $statusLabel.Text = "Installation completed: $successCount success, $failCount failed"
        }
        
        # Clear selection after installation
        foreach ($item in $checkBoxes) {
            $item.CheckBox.Checked = $false
        }
        Update-SelectedApps
    }
}

# Function to install single application
function Install-Application {
    param($PackageName, $AppName)
    
    if (-not (Check-Chocolatey)) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Chocolatey not found! It is required to install applications.`n`nDo you want to install Chocolatey now?",
            "Chocolatey Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            if (Install-Chocolatey) {
                $installChocoBtn.Visible = $false
                $statusLabel.Text = "Chocolatey installed! Now installing $AppName..."
                Update-UIForChocolatey
                Start-Sleep -Seconds 2
            } else {
                return
            }
        } else {
            return
        }
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Install $AppName using Chocolatey?`n`nPackage: $PackageName",
        "Confirm Installation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $statusLabel.Text = "Installing $AppName... Please wait."
        $form.Refresh()
        
        try {
            $process = Start-Process -FilePath "choco" -ArgumentList "install $PackageName -y --force" -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("$AppName installed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                $statusLabel.Text = "$AppName installed successfully!"
            } else {
                throw "Installation failed with exit code: $($process.ExitCode)"
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to install $AppName`nError: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            $statusLabel.Text = "Installation failed!"
        }
    }
}

# Check Chocolatey availability
function Check-Chocolatey {
    return [bool](Get-Command choco -ErrorAction SilentlyContinue)
}

# Function to update UI based on Chocolatey availability
function Update-UIForChocolatey {
    if (Check-Chocolatey) {
        $installChocoBtn.Visible = $false
        $statusLabel.Text = "Chocolatey optimized and ready! Select apps to install."
        $statusLabel.ForeColor = [System.Drawing.Color]::LightGreen
        
        # Enable install selected button if apps are selected
        if ($selectedApps.Count -gt 0) {
            $installSelectedBtn.Enabled = $true
            $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
        }
    } else {
        $installChocoBtn.Visible = $true
        $statusLabel.Text = "Chocolatey not found! Click 'Install Chocolatey First' to continue."
        $statusLabel.ForeColor = [System.Drawing.Color]::Orange
        
        # Disable install selected button
        $installSelectedBtn.Enabled = $false
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    }
}

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "🚀 Application Package Manager"
$form.Size = New-Object System.Drawing.Size(900, 750)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false

# Set form icon from URL
try {
    $iconUrl = "https://cdn-icons-png.flaticon.com/512/3093/3093463.png"
    $iconImage = Get-ImageFromUrl -Url $iconUrl -Width 32 -Height 32
    
    # Convert to icon
    $stream = New-Object System.IO.MemoryStream
    $iconImage.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $form.Icon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap($stream)).GetHicon())
    $stream.Dispose()
}
catch {
    Write-Host "Failed to load form icon" -ForegroundColor Yellow
}

# Menu Strip
$menuStrip = New-Object System.Windows.Forms.MenuStrip
$menuStrip.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$menuStrip.ForeColor = [System.Drawing.Color]::White

# File Menu
$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&File")

$installChocoMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&Install Chocolatey")
$optimizeMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&Optimize Chocolatey")
$selectAllMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Select &All")
$deselectAllMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&Deselect All")
$exitMenu = New-Object System.Windows.Forms.ToolStripMenuItem("E&xit")

$installChocoMenu.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Install Chocolatey package manager?`n`nThis will download and install the latest Chocolatey.",
        "Install Chocolatey",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Install-Chocolatey
    }
})

$optimizeMenu.Add_Click({
    if (Check-Chocolatey) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Optimize Chocolatey for faster performance?",
            "Optimize",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            if (Optimize-Chocolatey) {
                [System.Windows.Forms.MessageBox]::Show("Chocolatey optimized successfully!", "Success")
            } else {
                [System.Windows.Forms.MessageBox]::Show("Optimization failed!", "Error")
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Chocolatey not found! Please install Chocolatey first.", "Error")
    }
})

$selectAllMenu.Add_Click({
    foreach ($item in $checkBoxes) {
        $item.CheckBox.Checked = $true
    }
    Update-SelectedApps
})

$deselectAllMenu.Add_Click({
    foreach ($item in $checkBoxes) {
        $item.CheckBox.Checked = $false
    }
    Update-SelectedApps
})

$exitMenu.Add_Click({ $form.Close() })

$fileMenu.DropDownItems.Add($installChocoMenu)
$fileMenu.DropDownItems.Add($optimizeMenu)
$fileMenu.DropDownItems.Add($selectAllMenu)
$fileMenu.DropDownItems.Add($deselectAllMenu)
$fileMenu.DropDownItems.Add($exitMenu)

# Help Menu
$helpMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&Help")
$aboutMenu = New-Object System.Windows.Forms.ToolStripMenuItem("&About")
$aboutMenu.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Application Package Manager v6.0`nWith Checkbox Selection + Bulk Install", "About")
})
$helpMenu.DropDownItems.Add($aboutMenu)

$menuStrip.Items.Add($fileMenu)
$menuStrip.Items.Add($helpMenu)

# Header with Logo
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(880, 80)
$headerPanel.Location = New-Object System.Drawing.Point(10, 35)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 38)

# Logo PictureBox
$logoPictureBox = New-Object System.Windows.Forms.PictureBox
$logoPictureBox.Size = New-Object System.Drawing.Size(64, 64)
$logoPictureBox.Location = New-Object System.Drawing.Point(10, 8)
$logoPictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage

try {
    $logoUrl = "https://cdn-icons-png.flaticon.com/512/3093/3093463.png"
    $logoPictureBox.Image = Get-ImageFromUrl -Url $logoUrl -Width 64 -Height 64
}
catch {
    # Create simple logo
    $bitmap = New-Object System.Drawing.Bitmap(64, 64)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb(0, 120, 215))
    $font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $graphics.DrawString("APP", $font, $brush, 15, 22)
    $logoPictureBox.Image = $bitmap
}

# Header Title
$headerTitle = New-Object System.Windows.Forms.Label
$headerTitle.Text = "Application Package Manager"
$headerTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$headerTitle.Size = New-Object System.Drawing.Size(400, 35)
$headerTitle.Location = New-Object System.Drawing.Point(85, 15)
$headerTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

# Header Subtitle
$headerSubtitle = New-Object System.Windows.Forms.Label
$headerSubtitle.Text = "Select multiple apps and install them all at once"
$headerSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$headerSubtitle.Size = New-Object System.Drawing.Size(400, 25)
$headerSubtitle.Location = New-Object System.Drawing.Point(85, 45)
$headerSubtitle.ForeColor = [System.Drawing.Color]::LightGray

# Install Chocolatey Button
$installChocoBtn = New-Object System.Windows.Forms.Button
$installChocoBtn.Text = "Install Chocolatey First"
$installChocoBtn.Size = New-Object System.Drawing.Size(180, 35)
$installChocoBtn.Location = New-Object System.Drawing.Point(680, 20)
$installChocoBtn.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$installChocoBtn.ForeColor = [System.Drawing.Color]::White
$installChocoBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$installChocoBtn.FlatAppearance.BorderSize = 0
$installChocoBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$installChocoBtn.Visible = $false

$installChocoBtn.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Install Chocolatey package manager?`n`nThis is required to install applications.`nIt will download and install the latest Chocolatey.",
        "Install Chocolatey",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        if (Install-Chocolatey) {
            $installChocoBtn.Visible = $false
            $statusLabel.Text = "Chocolatey installed and optimized! Select apps to install."
            $statusLabel.ForeColor = [System.Drawing.Color]::LightGreen
            Update-UIForChocolatey
        }
    }
})

$installChocoBtn.Add_MouseEnter({
    $installChocoBtn.BackColor = [System.Drawing.Color]::FromArgb(200, 35, 51)
})

$installChocoBtn.Add_MouseLeave({
    $installChocoBtn.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
})

$headerPanel.Controls.Add($logoPictureBox)
$headerPanel.Controls.Add($headerTitle)
$headerPanel.Controls.Add($headerSubtitle)
$headerPanel.Controls.Add($installChocoBtn)

# Selection Panel
$selectionPanel = New-Object System.Windows.Forms.Panel
$selectionPanel.Size = New-Object System.Drawing.Size(880, 50)
$selectionPanel.Location = New-Object System.Drawing.Point(10, 125)
$selectionPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 38)

# Selected Apps Label
$selectedLabel = New-Object System.Windows.Forms.Label
$selectedLabel.Text = "Selected: 0 app(s)"
$selectedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$selectedLabel.Size = New-Object System.Drawing.Size(200, 25)
$selectedLabel.Location = New-Object System.Drawing.Point(20, 12)
$selectedLabel.ForeColor = [System.Drawing.Color]::LightGreen

# Install Selected Button
$installSelectedBtn = New-Object System.Windows.Forms.Button
$installSelectedBtn.Text = "Install Selected"
$installSelectedBtn.Size = New-Object System.Drawing.Size(150, 35)
$installSelectedBtn.Location = New-Object System.Drawing.Point(710, 7)
$installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$installSelectedBtn.ForeColor = [System.Drawing.Color]::White
$installSelectedBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$installSelectedBtn.FlatAppearance.BorderSize = 0
$installSelectedBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$installSelectedBtn.Enabled = $false

$installSelectedBtn.Add_Click({
    Install-SelectedApplications
})

$installSelectedBtn.Add_MouseEnter({
    if ($installSelectedBtn.Enabled) {
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(52, 140, 75)
    }
})

$installSelectedBtn.Add_MouseLeave({
    if ($installSelectedBtn.Enabled) {
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
    } else {
        $installSelectedBtn.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
    }
})

$selectionPanel.Controls.Add($selectedLabel)
$selectionPanel.Controls.Add($installSelectedBtn)

# Tab Control for Categories
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 185)
$tabControl.Size = New-Object System.Drawing.Size(865, 500)
$tabControl.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

# ========== BROWSER TAB ==========
$browserTab = New-Object System.Windows.Forms.TabPage
$browserTab.Text = "🌐 Browsers"
$browserTab.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

# Browser Category Header
$browserHeader = New-Object System.Windows.Forms.Label
$browserHeader.Text = "Web Browsers - Surf the internet with speed and security"
$browserHeader.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$browserHeader.Size = New-Object System.Drawing.Size(500, 30)
$browserHeader.Location = New-Object System.Drawing.Point(20, 15)
$browserHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

# Browser Apps with Checkboxes
$chromePanel = Create-AppPanel "Google Chrome" "googlechrome" "Fast and secure web browser" "https://cdn-icons-png.flaticon.com/512/3004/3004788.png" (New-Object System.Drawing.Point(30, 60))
$firefoxPanel = Create-AppPanel "Mozilla Firefox" "firefox" "Privacy-focused browser" "https://cdn-icons-png.flaticon.com/512/732/732025.png" (New-Object System.Drawing.Point(30, 130))
$edgePanel = Create-AppPanel "Microsoft Edge" "microsoft-edge" "Modern browser from Microsoft" "https://cdn-icons-png.flaticon.com/512/732/732221.png" (New-Object System.Drawing.Point(30, 200))
$operaPanel = Create-AppPanel "Opera Browser" "opera" "Browser with built-in VPN" "https://cdn-icons-png.flaticon.com/512/3004/3004881.png" (New-Object System.Drawing.Point(30, 270))
$bravePanel = Create-AppPanel "Brave Browser" "brave" "Privacy-focused browser with ad-blocker" "https://cdn-icons-png.flaticon.com/512/3004/3004878.png" (New-Object System.Drawing.Point(30, 340))

$vivaldiPanel = Create-AppPanel "Vivaldi Browser" "vivaldi" "Customizable browser" "https://cdn-icons-png.flaticon.com/512/3004/3004882.png" (New-Object System.Drawing.Point(250, 60))
$torPanel = Create-AppPanel "Tor Browser" "tor-browser" "Anonymous browsing" "https://cdn-icons-png.flaticon.com/512/825/825540.png" (New-Object System.Drawing.Point(250, 130))
$waterfoxPanel = Create-AppPanel "Waterfox" "waterfox" "Firefox fork for performance" "https://cdn-icons-png.flaticon.com/512/825/825526.png" (New-Object System.Drawing.Point(250, 200))
$palemoonPanel = Create-AppPanel "Pale Moon" "palemoon" "Firefox derivative browser" "https://cdn-icons-png.flaticon.com/512/825/825515.png" (New-Object System.Drawing.Point(250, 270))
$slimjetPanel = Create-AppPanel "SlimJet Browser" "slimjet" "Fast and smart browser" "https://cdn-icons-png.flaticon.com/512/3004/3004879.png" (New-Object System.Drawing.Point(250, 340))

$browserTab.Controls.Add($browserHeader)
$browserTab.Controls.AddRange(@($chromePanel, $firefoxPanel, $edgePanel, $operaPanel, $bravePanel, $vivaldiPanel, $torPanel, $waterfoxPanel, $palemoonPanel, $slimjetPanel))

# ========== KEYBOARD TAB ==========
$keyboardTab = New-Object System.Windows.Forms.TabPage
$keyboardTab.Text = "⌨️ Keyboard & Input"
$keyboardTab.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

# Keyboard Category Header
$keyboardHeader = New-Object System.Windows.Forms.Label
$keyboardHeader.Text = "Keyboard Tools - Enhance your typing and productivity"
$keyboardHeader.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$keyboardHeader.Size = New-Object System.Drawing.Size(500, 30)
$keyboardHeader.Location = New-Object System.Drawing.Point(20, 15)
$keyboardHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

# Keyboard Apps with Checkboxes
$keypirinhaPanel = Create-AppPanel "Keypirinha" "keypirinha" "Fast keyboard launcher" "https://cdn-icons-png.flaticon.com/512/2942/2942807.png" (New-Object System.Drawing.Point(30, 60))
$autohotkeyPanel = Create-AppPanel "AutoHotkey" "autohotkey" "Keyboard automation" "https://cdn-icons-png.flaticon.com/512/2942/2942812.png" (New-Object System.Drawing.Point(30, 130))
$sharpkeysPanel = Create-AppPanel "SharpKeys" "sharpkeys" "Keyboard remapper" "https://cdn-icons-png.flaticon.com/512/2942/2942823.png" (New-Object System.Drawing.Point(30, 200))
$powertoysPanel = Create-AppPanel "PowerToys" "powertoys" "Microsoft PowerToys" "https://cdn-icons-png.flaticon.com/512/2942/2942822.png" (New-Object System.Drawing.Point(30, 270))

$keyboardTab.Controls.Add($keyboardHeader)
$keyboardTab.Controls.AddRange(@($keypirinhaPanel, $autohotkeyPanel, $sharpkeysPanel, $powertoysPanel))

# ========== SOCIAL MEDIA TAB ==========
$socialTab = New-Object System.Windows.Forms.TabPage
$socialTab.Text = "📱 Social Media"
$socialTab.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

# Social Media Category Header
$socialHeader = New-Object System.Windows.Forms.Label
$socialHeader.Text = "Social Apps - Connect and communicate"
$socialHeader.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$socialHeader.Size = New-Object System.Drawing.Size(500, 30)
$socialHeader.Location = New-Object System.Drawing.Point(20, 15)
$socialHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

# Social Media Apps with Checkboxes
$discordPanel = Create-AppPanel "Discord" "discord" "Chat for gamers" "https://cdn-icons-png.flaticon.com/512/5968/5968756.png" (New-Object System.Drawing.Point(30, 60))
$telegramPanel = Create-AppPanel "Telegram" "telegram" "Secure messaging" "https://cdn-icons-png.flaticon.com/512/5968/5968804.png" (New-Object System.Drawing.Point(30, 130))
$whatsappPanel = Create-AppPanel "WhatsApp" "whatsapp" "Facebook messaging" "https://cdn-icons-png.flaticon.com/512/5968/5968841.png" (New-Object System.Drawing.Point(30, 200))
$skypePanel = Create-AppPanel "Skype" "skype" "Video calls and chat" "https://cdn-icons-png.flaticon.com/512/5968/5968843.png" (New-Object System.Drawing.Point(30, 270))

$socialTab.Controls.Add($socialHeader)
$socialTab.Controls.AddRange(@($discordPanel, $telegramPanel, $whatsappPanel, $skypePanel))

# ========== MEDIA PLAYER TAB ==========
$playerTab = New-Object System.Windows.Forms.TabPage
$playerTab.Text = "🎵 Media Players"
$playerTab.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)

# Media Player Category Header
$playerHeader = New-Object System.Windows.Forms.Label
$playerHeader.Text = "Media Players - Enjoy music and videos"
$playerHeader.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$playerHeader.Size = New-Object System.Drawing.Size(500, 30)
$playerHeader.Location = New-Object System.Drawing.Point(20, 15)
$playerHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215)

# Media Player Apps with Checkboxes
$vlcPanel = Create-AppPanel "VLC Player" "vlc" "Versatile media player" "https://cdn-icons-png.flaticon.com/512/3004/3004886.png" (New-Object System.Drawing.Point(30, 60))
$potplayerPanel = Create-AppPanel "PotPlayer" "potplayer" "Lightweight media player" "https://cdn-icons-png.flaticon.com/512/3004/3004885.png" (New-Object System.Drawing.Point(30, 130))
$spotifyPanel = Create-AppPanel "Spotify" "spotify" "Music streaming" "https://cdn-icons-png.flaticon.com/512/3004/3004887.png" (New-Object System.Drawing.Point(30, 200))
$itunesPanel = Create-AppPanel "iTunes" "itunes" "Apple music player" "https://cdn-icons-png.flaticon.com/512/3004/3004888.png" (New-Object System.Drawing.Point(30, 270))

$playerTab.Controls.Add($playerHeader)
$playerTab.Controls.AddRange(@($vlcPanel, $potplayerPanel, $spotifyPanel, $itunesPanel))

# Add tabs to tab control
$tabControl.Controls.Add($browserTab)
$tabControl.Controls.Add($keyboardTab)
$tabControl.Controls.Add($socialTab)
$tabControl.Controls.Add($playerTab)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Checking for Chocolatey..."
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$statusLabel.Size = New-Object System.Drawing.Size(600, 25)
$statusLabel.Location = New-Object System.Drawing.Point(150, 695)
$statusLabel.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$statusLabel.ForeColor = [System.Drawing.Color]::LightGreen

# Add controls to form
$form.Controls.Add($menuStrip)
$form.Controls.Add($headerPanel)
$form.Controls.Add($selectionPanel)
$form.Controls.Add($tabControl)
$form.Controls.Add($statusLabel)

# Check Chocolatey on startup
$form.Add_Shown({
    $form.Activate()
    Update-UIForChocolatey
    if (Check-Chocolatey) {
        Optimize-Chocolatey
    }
})

# Show form
[void]$form.ShowDialog()
