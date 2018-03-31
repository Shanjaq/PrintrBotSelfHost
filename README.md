# PrintrBotSelfHost
PowerShell script to convert Cura-generated gcode to PrintrBot format and host project files for local push over wifi

currently missing the project_part_* file fragments until the binary format is discovered.

example request to transfer a project to the printer:
http://192.168.254.4/fetch?id=LM3J7YVW&url=http://192.168.254.63:8000/projects/LM3J7YVW&type=project
