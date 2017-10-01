$item = "GalaxyS8"
$email = "calumochkas@gmail.com"
$url = "https://www.ebay.co.uk/sch/Mobile-Smart-Phones/9355/i.html?Brand=Samsung&_nkw=&_dcat=9355&Model=Samsung%2520Galaxy%2520S8&LH_ItemCondition=1000%7C1500%7C3000&_sop=10"
$highestprice = "450"
$logpath = "C:\Temp\Logs\EbayScraper"
$wget = Invoke-WebRequest -uri $url

$datetime = Get-Date -Format ddMMyy-HH.mm
$results = $wget.ParsedHtml.getElementsByClassName("sresult")

$coll = @()

foreach ($resultitem in $results){
            $sobj = "" | select Name,Cost,Format,URL,New
            
            $title = $resultitem.getElementsByClassName("lvtitle")[0].getAttribute("outerText")
            $prices = $resultitem.getElementsByClassName("lvprice")[0].getAttribute("outerText")
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
            $sobj.Format = [regex]::match($formathtml,'\"([^\)]+)\"').Groups[1].Value
            $sobj.URL = $link
            $latestlog = Get-Content (Get-Item "$logpath\$item*" | Sort-Object -Property "LastWriteTime" -Descending)[0] | ConvertFrom-Csv
            if ($latestlog | ?{$_.URL -eq $sobj.URL}){
                $sobj.new = $false
            }
            else {
                $sobj.new = $true
            }
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