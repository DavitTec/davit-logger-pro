# Pseudocode 

## Bash Adapter  

```pseudocode
## Bash Adapter Logic (Pseudo)

function load_env():
    if .env exists:
        export variables
    else:
        use defaults

function load_theme():
    if theme.json exists:
        parse via jq
    else:
        use internal defaults

function log(level, code, message):
    if level_priority < ENV_LOG_LEVEL:
        return

    color = theme.levels[level].color
    print formatted message

function system_check(type):
    case type:
        cpu -> read /sys/class/thermal
        mem -> read /proc/meminfo
        ping -> ping -c 1 host
```

------

## Node CommonJS Adapter 

```pseudocode
## Node Logger Pseudocode

loadEnv()
loadTheme()
loadErrors()

function log(level, code, message, meta = {}):

    if levelPriority(level) < currentLevel:
        return

    const errorObj = errors[code] || {}
    const formatted = format({
        timestamp: new Date().toISOString(),
        level,
        code,
        message: message || errorObj.message,
        action: errorObj.action,
        meta
    })

    console.log(applyTheme(formatted))
```