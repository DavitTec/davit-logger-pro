# Bash Aliases

```bash
############################################################################################################################

## Davit-logger - Clean logs, colors on display only

alias logadm='    mate-terminal --zoom=0.70 --geometry=280x5+10+010 -t "DAVIT-ADMIN-LOGS"   -e "tail -f /opt/davit/logs/davit-admin.log"'
#alias logadm2='    mate-terminal --zoom=0.70 --geometry=280x5+10+010 -t "DAVIT-ADMIN-LOGS"   -e "tail -f /opt/davit/logs/davit-admin.log    | ccze -A"'
alias logd='       mate-terminal --zoom=0.70 --geometry=280x5+10+140 -t "DAVIT-MAIN-LOGS"    -e "tail -f /opt/davit/logs/davit.log"'           
alias logs='       mate-terminal --zoom=0.70 --geometry=280x5+10+270 -t "DAVIT-SYSTEM-LOGS"  -e "tail -f /opt/davit/logs/davit-system.log "'
alias loga='       mate-terminal --zoom=0.70 --geometry=280x5+10+400 -t "DAVIT-AUDIT-LOGS"   -e "tail -f /opt/davit/logs/davit-audit.log "'
alias logp='       mate-terminal --zoom=0.70 --geometry=280x5+10+530 -t "DAVIT-PROJECT-LOGS" -e "tail -f /opt/davit/logs/davit-projects.log "'
alias logtest='    mate-terminal --zoom=0.70 --geometry=280x5+10+660 -t "DAVIT-TEST-LOGS"    -e "tail -f /opt/davit/development/davit-logger-test/logs/davit-logger-test.log A"'

alias logadmc='multitail -cS davit-admin -wh 24 -D  -F /opt/davit/lib/multitail/davit-admin-log.config -i /opt/davit/logs/davit-admin.log'
alias logsc='multitail -cS davit-system -wh 24 -D  -F /opt/davit/lib/multitail/davit-system-log.config -i /opt/davit/logs/davit-system.log'

alias logallc='multitail -cS davit-admin  -wh 12  -F /opt/davit/lib/multitail/davit-admin-log.config -i /opt/davit/logs/davit-admin.log\
                         -cS davit-system -wh 12 -F /opt/davit/lib/multitail/davit-admin-log.config -i /opt/davit/logs/davit-system.log'

alias logall='logtest; logp; loga; logs; logd; logadm'

## For tabs in one window (note: --tab must come before -e in most cases)

#alias logsys='loga; logs --tab; logd --tab; logadm --tab'
alias logsys='mate-terminal --zoom=0.70 \
  --tab -t "AUDIT"  -e "bash -c \"tail -f /opt/davit/logs/davit-audit.log | ccze -A\"" \
  --tab -t "SYSTEM" -e "bash -c \"tail -f /opt/davit/logs/davit-system.log | ccze -A\"" \
  --tab -t "MAIN"   -e "bash -c \"tail -f /opt/davit/logs/davit.log | ccze -A\"" \
  --tab -t "ADMIN"  -e "bash -c \"tail -f /opt/davit/logs/davit-admin.log | ccze -A\""'

alias logduel='multitail -cT ansi \
  /opt/davit/logs/davit-admin.log \
  /opt/davit/logs/davit.log \
  /opt/davit/logs/davit-system.log'

alias logclose='xdotool search --onlyvisible --name "DAVIT-.*-LOGS" windowkill %@'

## Davit-logger END######################################################################################################################### 
```

