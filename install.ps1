if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
#if not it will run the command on admin
    Write-Warning "Running this script as Administrator!"
        Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "iwr -useb "https://raw.githubusercontent.com/himadrickit/pencil/refs/heads/main/install.ps1" | iex "' -Verb RunAs
        exit
}

$path = "C:/farm/wheats/"

$docs = @(
        @{url = "https://raw.githubusercontent.com/himadrickit/pencil/refs/heads/main/pencil.ps1" ; outfile = "$env:TEMP/pencil.ps1"; file = "C:/farm/wheats/pencil.ps1"}
        )

if (-not (test-path $path)){
    mkdir $path | out-null
}


foreach ($doc in $docs){
    iwr -uri $doc.url -OutFile $doc.outfile 
        copy-item $doc.outfile $doc.file -force
}

try{
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$path*"){
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$path", "User")
                Write-Host "Pencil added to user PATH." -ForegroundColor cyan
        } else {
            Write-Host "Pencil already in user PATH." -ForegroundColor green
        }
} catch {
    Write-Error "Error adding Pencil to path: $($_.Exception.Message)"
}

if (get-command gsudo -ErrorAction SilentlyContinue){
    write-host "Already have gsudo" -ForegroundColor green
} else {
    PowerShell -Command "Set-ExecutionPolicy RemoteSigned -scope Process; [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; iwr -useb https://raw.githubusercontent.com/gerardog/gsudo/master/installgsudo.ps1 | iex"
}

