package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

var defaultCORSAllowedOrigins = []string{
	"http://127.0.0.1:18888",
	"http://localhost:18888",
	"http://127.0.0.1:8787",
	"http://localhost:8787",
}

func DefaultCORSAllowedOrigins() []string {
	return append([]string{}, defaultCORSAllowedOrigins...)
}

func corsMiddleware(allowedOrigins []string) gin.HandlerFunc {
	allowed := make(map[string]bool)
	if allowedOrigins == nil {
		allowedOrigins = defaultCORSAllowedOrigins
	}
	for _, origin := range allowedOrigins {
		if origin != "" {
			allowed[origin] = true
		}
	}

	return func(ctx *gin.Context) {
		origin := ctx.Request.Header.Get("Origin")
		originAllowed := allowed[origin]
		if originAllowed {
			headers := ctx.Writer.Header()
			headers.Set("Access-Control-Allow-Origin", origin)
			headers.Set("Access-Control-Allow-Credentials", "true")
			headers.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Admin-Token, X-Admin-Client")
			headers.Set("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
			headers.Set("Access-Control-Max-Age", "600")
			headers.Add("Vary", "Origin")
		}

		if ctx.Request.Method == http.MethodOptions {
			if !originAllowed {
				ctx.AbortWithStatus(http.StatusForbidden)
				return
			}
			ctx.AbortWithStatus(http.StatusNoContent)
			return
		}

		ctx.Next()
	}
}
