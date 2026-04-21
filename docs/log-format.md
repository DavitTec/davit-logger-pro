# Log Formats



## AUDIT

**Destination**: [/opt/davit/logs/davit-audit.log](/opt/davit/logs/davit-audit.log) 

### Format:

TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT  |  EXTRA | MODE=env | pid=1234 | script:<name><version><ext> | MESSAGE

Example:

```bash
2026-04-19 11:56:12.898 | david | INFO | AUDIT | generic | - | MODE:dev | pid:9707 | script:test-01-log.sh | AUDIT category test (also to davit-audit.log)
```



## ADMIN

**Destination**: [/opt/davit/logs/davit-admin.log](/opt/davit/logs/davit-admin.log) 

### Format:

TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT  |  EXTRA | MODE=env | pid=1234 | script:<name><version><ext> | MESSAGE

Example:

```bash
2026-04-19 11:56:12.887 | david | CRITICAL | ADMIN | generic | MODE:dev | [pid:9707] | [script:test-01-log.sh] | ADMIN category test
```



## MAIN

**Destination**: [/opt/davit/logs/davit.log](/opt/davit/logs/davit.log) 

### Format:

TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT  |  EXTRA | MODE=env | pid=1234 | script:<name><version><ext> | MESSAGE

Example:

```bash
2026-04-19 11:56:12.847 |david |ERROR | PROJECT | generic | - | MODE:dev | pid:9707 | script:test-01-log.sh | This is an ERROR – will go to master davit.log

```



## PROJECTS

**Destination**: [/opt/davit/logs/davit-projects.log](/opt/davit/logs/davit-projects.log) and location in `<projects>/logs/` 

### Format:

TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT  |  EXTRA | MODE=env | pid=1234 | script:<name><version><ext> | MESSAGE

Example:

```bash
2026-04-20 11:33:34.171 | david | HEADER | PROJECT | generic | - | MODE:prod | pid:33856 | script:test-02-log.sh | === DAVIT-LOGGER TEST SUITE START ===
2026-04-20 11:33:34.183 | david | INFO | PROJECT | generic | - | MODE:prod | pid:33856 | script:test-02-log.sh | scripts/test-02-log.sh  found /opt/davit/development/davit-logger-test/.env
2026-04-20 11:33:34.171 | david | HEADER | PROJECT | generic | - | MODE:prod | pid:33856 | script:test-02-log.sh | === DAVIT-LOGGER TEST SUITE START ===
2026-04-20 11:33:34.183 | david | INFO | PROJECT | generic | - | MODE:prod | pid:33856 | script:test-02-log.sh | scripts/test-02-log.sh  found /opt/davit/development/davit-logger-test/.env2026-04-19 11:56:12.879 | david M | INFO | SYSTEM | generic | - | MODE:dev | pid:9707 | script:test-01-log.sh | This is a SYSTEM category message (goes to davit-system.log)
```



## SYSTEM

## PROJECTS

**Destination**: [/opt/davit/logs/davit-system.log](/opt/davit/logs/davit-system.log)  

### Format:

TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT  |  EXTRA | MODE=env | pid=1234 | script:<name><version><ext> | MESSAGE

Example:

```bash
2026-04-19 11:56:12.879 | david M | INFO | SYSTEM | generic | - | MODE:dev | pid:9707 | script:test-01-log.sh | This is a SYSTEM category message (goes to davit-system.log)
```



## TESTS

**Destination**: [/opt/davit/logs/davit-tests.log](/opt/davit/logs/davit-tests.log)

### Format:

To be decided

Example:

```bash
==> /opt/davit/development/davit-logger-test/logs/davit-logger-test.log <==
tail: cannot open 'A' for reading: No such file or directory


```





