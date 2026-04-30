package gateway

import (
	"fmt"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

const requestIDContextKey = "request_id"

var requestIDSequence uint64

func requestIDMiddleware() gin.HandlerFunc {
	return func(ctx *gin.Context) {
		id := normalizeRequestID(ctx.GetHeader("X-Request-ID"))
		if id == "" {
			id = nextRequestID()
		}
		ctx.Set(requestIDContextKey, id)
		ctx.Header("X-Request-ID", id)
		ctx.Next()
	}
}

func requestID(ctx *gin.Context) string {
	value, ok := ctx.Get(requestIDContextKey)
	if !ok {
		return ""
	}
	id, _ := value.(string)
	return id
}

func normalizeRequestID(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > 80 {
		return ""
	}
	for _, char := range value {
		if char == '-' || char == '_' || char == '.' || char == ':' {
			continue
		}
		if char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' || char >= '0' && char <= '9' {
			continue
		}
		return ""
	}
	return value
}

func nextRequestID() string {
	index := atomic.AddUint64(&requestIDSequence, 1)
	return fmt.Sprintf("psw-%d-%s", time.Now().UnixNano(), strconv.FormatUint(index, 36))
}

func queryInt(ctx *gin.Context, key string, fallback int) int {
	value := strings.TrimSpace(ctx.Query(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}
