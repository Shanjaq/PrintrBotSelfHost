# PrintrBotSelfHost
PowerShell script to convert Cura-generated gcode to PrintrBot format and host project files for local push over wifi

currently using the project_part_* file fragments until the binary format is discovered and can be generated in code.  will only generate single-part projects.

Steps:

0. Backup your SD Card (any mistake in the steps to follow will corrupt the index!)
1. Start a PowerShell prompt
2. Copy your Cura-generated gcode file into the same folder as the import_gcode.ps1 script
3. Execute:
    .\import_gcode.ps1 -projectName "some_project_name" -gcodeFileName "some_project_name.gcode"
-hostAddress "local_ip_address:8000" -printerAddress "printer_ip_address"
4. Wait for processing to complete
5. Execute:
    .\websrv.ps1
6. Open a browser, paste the HTTP request printed to the console into the address bar and hit enter
7. Wait for project file to transfer
8. Open project and download the full gcode using the printer LCD UI

Notes:

*PROJECT_ID will display in the console when import_gcode.ps1 processing completes

***Be sure to download the full gcode to your printer before your host computer IP changes (in the case of DHCP) because the IP is stored in the project file itself.**

*The bundled Web Server script listens on port 8000, be sure to run this elevated before starting it for the first time:

    netsh http add urlacl url=http://+:8000/ user=DOMAIN\user
