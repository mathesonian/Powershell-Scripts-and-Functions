#####################################################################################
#Script Created by Phillip Marshall													#
#Creation Date 6/5/14																#
#Revision 2																			#
#Revisions Changes - Added Commenting.												#
#																					#
#Description - This Script will Pull information from the LabTech Database, and     #
#From the local machine and output it to a table and corresponding graph in an		#
#HTML report.																		#
#																					#
#####################################################################################

#The Write HTML Function is responsible for pulling in the content from the other functions and generating the HTML report.
function Write-HTML{
      [CmdletBinding(SupportsShouldProcess=$True)]
param([Parameter(Mandatory=$false,
      ValueFromPipeline=$true)]
      [string]$FilePath = "$env:Windir\temp\Write-HTML.html",
      [string[]]$Computername = $env:COMPUTERNAME,
$Css='<style>table{margin:auto; width:98%}
              Body{background-color:Red; Text-align:Center;}
                th{background-color:Black; color:white;}
                td{background-color:Grey; color:Black; Text-align:Center;}
     </style>' )

Begin{ Write-Verbose "HTML report will be saved $FilePath" }

Process{ 
$Computers = run-MySQLQuery -ConnectionString "Server=localhost;Uid=root;Pwd=imulehidepocepoh;database=LabTech;Allow Zero Datetime=true;" "SELECT computers.`computerid` AS 'Computer ID',computers.`name` AS 'Computer Name', clients.`name` AS 'Client Name', SUBSTRING(`windows server roles`, LOCATE("MSSQL",`windows server roles`), LOCATE(",",SUBSTRING(`windows server roles`,LOCATE("MSSQL",`windows server roles`)))-1) AS 'SQL Version'
FROM computers
JOIN clients ON computers.clientid = clients.clientid
JOIN `v_extradatacomputers` ON `v_extradatacomputers`.computerid = computers.computerid
WHERE `windows server roles` LIKE '%MSSQL 2000%'
" |
            Select 'Computer ID','Computer Name','Client Name','SQL Version'|
            ConvertTo-Html -PreContent "<h2>Top Processes By Memory Usage</h2>" |
            Out-String

$graph = "<html><body><br><img src=`"C:\windows\temp\test.png`"></body></html>"

$Report = ConvertTo-Html -Title "Hey Rick this is a test" `
                         -Head "<h1>Report Brought to you by Phillip Marshall<br><br>Largest Tables in the database</h1><br>This report was ran: $(Get-Date)" `
                         -Body "$Computers $Graph $Css" }

End{ $Report | Out-File $Filepath ; Invoke-Expression $FilePath }

}
#The Run-MySQLQuery function is reponsible for setting up the database connection. In its current form it is assumed this is running directly on the DB server.
Function Run-MySQLQuery {
    Param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName = '',
            ValueFromPipeline = $true)]
            [string]$query,   
        [Parameter(
            Mandatory = $true,
            ParameterSetName = '',
            ValueFromPipeline = $true)]
            [string]$connectionString
        )
    Begin {
        Write-Verbose "Starting Begin Section"        
    }
    Process {
        Write-Verbose "Starting Process Section"
        try {
            # load MySQL driver and create connection
            Write-Verbose "Create Database Connection"
            # You could also could use a direct Link to the DLL File
            # $mySQLDataDLL = "C:\scripts\mysql\MySQL.Data.dll"
            # [void][system.reflection.Assembly]::LoadFrom($mySQLDataDLL)
            [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
            $connection = New-Object MySql.Data.MySqlClient.MySqlConnection
            $connection.ConnectionString = $ConnectionString
            Write-Verbose "Open Database Connection"
            $connection.Open()
            
            # Run MySQL Querys
            Write-Verbose "Run MySQL Querys"
            $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $connection)
            $dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
            $dataSet = New-Object System.Data.DataSet
            $recordCount = $dataAdapter.Fill($dataSet, "data")
            $dataSet.Tables["data"]
        }        
        catch {
            Write-Host "Could not run MySQL Query" $Error[0]    
        }    
        Finally {
            Write-Verbose "Close Connection"
            $connection.Close()
        }
    }
    End {
        Write-Verbose "Starting End Section"
    }
}
#The CreateGraph function is responsible for turning the data into a chart and then saving it as a PNG.
Function CreateGraph{
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
# chart object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 600
   $chart1.Height = 600
   $chart1.BackColor = [System.Drawing.Color]::White
# title 
   [void]$chart1.Titles.Add("Top 5 - Memory Usage (as: Column)")
   $chart1.Titles[0].Font = "Arial,13pt"
   $chart1.Titles[0].Alignment = "topLeft"
# chart area 
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Memory (MB)"
   $chartarea.AxisX.Title = "Process Name"
   $chartarea.AxisY.Interval = 100
   $chartarea.AxisX.Interval = 1
   $chart1.ChartAreas.Add($chartarea)
# legend 
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)
# data source
   $datasource = $computers
# data series
   [void]$chart1.Series.Add("VirtualMem")
   $chart1.Series["VirtualMem"].ChartType = "Column"
   $chart1.Series["VirtualMem"].BorderWidth  = 3
   $chart1.Series["VirtualMem"].IsVisibleInLegend = $true
   $chart1.Series["VirtualMem"].chartarea = "ChartArea1"
   $chart1.Series["VirtualMem"].Legend = "Legend1"
   $chart1.Series["VirtualMem"].color = "#62B5CC"
   $datasource | ForEach-Object {$chart1.Series["VirtualMem"].Points.addxy( $_.Name , ($_.VirtualMemorySize / 1000000)) }
# data series
   [void]$chart1.Series.Add("PrivateMem")
   $chart1.Series["PrivateMem"].ChartType = "Column"
   $chart1.Series["PrivateMem"].IsVisibleInLegend = $true
   $chart1.Series["PrivateMem"].BorderWidth  = 3
   $chart1.Series["PrivateMem"].chartarea = "ChartArea1"
   $chart1.Series["PrivateMem"].Legend = "Legend1"
   $chart1.Series["PrivateMem"].color = "#E3B64C"
   $datasource | ForEach-Object {$chart1.Series["PrivateMem"].Points.addxy( $_.Name , ($_.PrivateMemorySize / 1000000)) }
# save chart
   $chart1.SaveImage("C:\windows\temp\test.png","png")}
Write-HTML