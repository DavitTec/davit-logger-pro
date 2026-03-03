# Davit Logging Specification v1.0

## 1. Log Levels

| Level    | Priority | Description           |
| -------- | -------- | --------------------- |
| debug    | 10       | Developer diagnostics |
| info     | 20       | Normal operation      |
| warn     | 30       | Recoverable issue     |
| error    | 40       | Operational failure   |
| critical | 50       | System-level failure  |

------

## 2. Log Message Structure

```
{
  "timestamp": "ISO-8601",
  "level": "warn",
  "code": "VAL002",
  "message": "Slide exceeds word limit",
  "status": "warn",
  "action": "Trim content in MD file",
  "meta": {}
}
```

------

## 3. Theme Structure (v1.0)

Based on your improved format:

```
{
  "meta": {
    "name": "default-dark",
    "version": "1.0.0"
  },
  "ansi": {
    "reset": "\u001b[0m",
    "colors": {
      "red": "\u001b[31m",
      "green": "\u001b[32m",
      "yellow": "\u001b[33m",
      "cyan": "\u001b[36m",
      "magenta": "\u001b[35m"
    }
  },
  "levels": {
    "debug": { "color": "cyan", "priority": 10 },
    "info": { "color": "green", "priority": 20 },
    "warn": { "color": "yellow", "priority": 30 },
    "error": { "color": "red", "priority": 40 },
    "critical": { "color": "magenta", "priority": 50 }
  },
  "format": {
    "timestamp": true,
    "showCode": true,
    "maxMessageLength": 500
  }
}
```

------

## 4. Errors Structure (v1.0)

Using your original example:

```
{
  "errors": {
    "GEN001": {
      "code": "GEN001",
      "status": "error",
      "message": "General validation error",
      "action": "Check input and try again"
    },
    "VAL001": {
      "code": "VAL001",
      "status": "error",
      "message": "Exceeded maximum number of slides",
      "action": "Reduce slides or update rules.json maxSlides"
    }
  }
}
```

