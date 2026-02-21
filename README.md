# TR SS Auto Downloader

TR SS Auto Downloader, TR SS Community'deki Toolları hızlıca indirmeye yarayan SS süresini kısaltmak ve toolları indirirken pratiklik sağlamak amacıyla yapılmıştır.

### discord:discord.gg/6pFnJVUMjm

Önerileriniz ve şikayetleriniz için discord sunucumuza katılabilirsiniz.

### Gereksinimler
* Windows İşletim Sistemi.
* PowerShell 5.1 veya üzeri versiyon.

### Çalıştırma
PowerShell'i yönetici açıp şu komutu girerek çalıştırabilirsiniz:
```powershell
$script = Invoke-RestMethod "https://raw.githubusercontent.com/korkusuzadX/TR-SS-AutoDownloader/main/TR_SS_Auto_Downloader.ps1"
$script = $script.TrimStart([char]0xFEFF)
Invoke-Expression $script
```
böyle olmasının sebebi UTF-8 ile UTF-8 BOM arası fark Türkçe karakter desteği olması

### indirerek
PowerShell'i yönetici açıp şu komutu girerek çalıştırabilirsiniz:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ./TR_SS_Auto_Downloader.ps1
   ```
