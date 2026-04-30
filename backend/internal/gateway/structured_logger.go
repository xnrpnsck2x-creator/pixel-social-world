package gateway

import (
	"encoding/json"
	"time"

	"github.com/gin-gonic/gin"
)

func structuredLoggerMiddleware() gin.HandlerFunc {
	return func(ctx *gin.Context) {
		start := time.Now()
		ctx.Next()
		level := "info"
		if ctx.Writer.Status() >= 500 {
			level = "error"
		}
		entry := map[string]any{
			"ts":         time.Now().UTC().Format(time.RFC3339Nano),
			"level":      level,
			"event":      "http_request",
			"request_id": requestID(ctx),
			"method":     ctx.Request.Method,
			"path":       ctx.Request.URL.Path,
			"status":     ctx.Writer.Status(),
			"latency_ms": time.Since(start).Milliseconds(),
			"client_ip":  ctx.ClientIP(),
			"user_agent": ctx.Request.UserAgent(),
			"bytes":      ctx.Writer.Size(),
		}
		if raw := ctx.Request.URL.RawQuery; raw != "" {
			entry["query"] = raw
		}
		_ = json.NewEncoder(gin.DefaultWriter).Encode(entry)
	}
}
