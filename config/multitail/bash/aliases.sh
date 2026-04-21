alias logprojects='multitail \
  -F /opt/davit/lib/multitail/davit-multitail.conf \
  -cS davit-projects -wh 12 -i /opt/davit/logs/davit-projects.log'



alias logallc='multitail \
  -F /opt/davit/lib/multitail/davit-multitail.conf \
  -cS davit-admin   -wh 10 -i /opt/davit/logs/davit-admin.log \
  -cS davit-system  -wh 10 -i /opt/davit/logs/davit-system.log \
  -cS davit-audit   -wh 8  -i /opt/davit/logs/davit-audit.log \
  -cS davit-projects -wh 12 -i /opt/davit/logs/davit-projects.log'
