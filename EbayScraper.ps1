[cmdletbinding()]
param(
    [string]$item = "",
    [string]$url = "",
    [int]$highestprice = "",
    [string]$email = "",
    [string]$logpath = "C:\Temp\Logs\EbayScraper"
)

$datetime = Get-Date -Format ddMMyy-HH.mm

# Get Search Result Data
$wget = Invoke-WebRequest -uri $url
$results = $wget.ParsedHtml.getElementsByClassName("sresult")
function ClearLogData ($sitem,$slogpath,$age){
    $objects = Get-ChildItem -Path $slogpath | ?{$_.Fullname -match "$sitem*\.log" -and $_.LastWriteTime -gt (Get-Date).AddDays(-$age)}
    $objectcount = $objects.Count
    Write-Verbose "Deleting ($objectcount).Count Log Files from $slogpath"
    Remove-Item $objects -Force

}
# Build Object Collection
$coll = @()

# Loop through each result
foreach ($resultitem in $results){
            $sobj = "" | select Name,Cost,Format,URL,New
            
            $title = $resultitem.getElementsByClassName("lvtitle")[0].getAttribute("outerText")
            $prices = $resultitem.getElementsByClassName("lvprice")[0].getAttribute("outerText")
            # If there are two prices returned, write the second price to the variable
            if ($prices.count -eq "1"){
                $price = $resultitem.getElementsByClassName("lvprice")[0].getAttribute("outerText")
            }
            else {
                $price = $resultitem.getElementsByClassName("lvprice")[1].getAttribute("outerText")
            }
            $formathtml = $resultitem.getElementsByClassName("lvformat")[0].getAttribute("innerHTML")
            $link = $resultitem.getElementsByClassName("vip")[0].getAttribute("href")
            $price = $price.Trim("£")
            $sobj.Name = $title
            $sobj.Cost = $price
            # Capture data inside quote marks by regex for buying format
            $sobj.Format = [regex]::match($formathtml,'\"([^\)]+)\"').Groups[1].Value
            $sobj.URL = $link
            $latestlog = Get-Content (Get-Item "$logpath\$item*" | Sort-Object -Property "LastWriteTime" -Descending)[0] | ConvertFrom-Csv
            if ($latestlog | ?{$_.URL -eq $sobj.URL}){
                $sobj.new = $false
            }
            else {
                $sobj.new = $true
            }
            # Add item to object collection
            $coll += $sobj
}

$coll | export-csv "$logpath\$item-$datetime.csv" -NoTypeInformation
$newphones = $coll | ?{$_.Cost -le $highestprice -and $_.New -eq $true -and $_.Format -match "Now"}
$htmlbody = $newphones | Select Cost,Name,URL | ConvertTo-Html | Out-String

if ($newphones){
    $encpassword = gc C:\Scripts\EbayScraper\SecureString.txt | ConvertTo-SecureString
    $emailcreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $email, $encpassword
    Send-MailMessage -UseSsl -BodyAsHTML -Port 587 -Body $htmlbody `
        -From $email `
        -To $email `
        -Credential $emailcreds `
        -SmtpServer smtp.gmail.com `
        -Subject "New $item found on Ebay"
}